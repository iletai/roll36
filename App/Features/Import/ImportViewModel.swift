import ImageIO
import Observation
import SwiftUI
import UIKit

/// State machine of the Import screen (PLAN §11): photo -> stock -> preview -> develop.
/// `@MainActor` so all state mutations are isolated to the main actor (Swift 6 strict concurrency).
@MainActor
@Observable
final class ImportViewModel {
    enum Phase: Equatable {
        case empty, ready, developing, developed
    }

    struct PaywallRequest: Identifiable {
        let id = UUID()
        var stockID: String?
    }

    private(set) var phase = Phase.empty
    private(set) var stock: FilmProfile
    /// Original downscaled photo until the first developed preview arrives, then the preview.
    private(set) var image: UIImage?
    /// Retained downscaled copy of the original unedited photo for instant Before/After comparison.
    private(set) var originalThumbnail: UIImage?
    private(set) var isPreviewing = false
    private(set) var errorMessage: LocalizedStringKey?
    /// Free imports left; nil when unlimited.
    private(set) var remaining: Int?
    var paywall: PaywallRequest?

    private let env: AppEnvironment
    private var original: Data?

    /// Generation counter: each `load()` and `startPreview()` increments it.
    /// After every `await`, code checks whether the generation is still current before mutating state.
    @ObservationIgnored private var generation = 0
    @ObservationIgnored private(set) var previewTask: Task<Void, Never>?

    private static let previewDimension: CGFloat = 1080
    private static let debounce = Duration.milliseconds(150)

    init(env: AppEnvironment) {
        self.env = env
        stock = env.selectedStock
        remaining = env.importQuota.remaining(isUnlocked: env.entitlements.isImportUnlimited)
    }

    var isStockLocked: Bool { !env.entitlements.isUnlocked(stockID: stock.id) }
    var canDevelop: Bool { phase == .ready }

    func refreshQuota() {
        remaining = env.importQuota.remaining(isUnlocked: env.entitlements.isImportUnlimited)
    }

    func isLocked(_ profile: FilmProfile) -> Bool { !env.entitlements.isUnlocked(stockID: profile.id) }

    func loadFailed() {
        errorMessage = "Could not load that photo."
    }

    /// Loads a picked photo. Uses a generation counter so rapid picks or cancellation
    /// can never overwrite state from a stale task.
    func load(_ data: Data) async {
        generation &+= 1
        let gen = generation
        errorMessage = nil
        original = data
        guard let thumbnail = await Self.downscaled(data, maxDimension: Self.previewDimension) else {
            guard gen == generation else { return }
            original = nil
            originalThumbnail = nil
            image = nil
            phase = .empty
            loadFailed()
            return
        }
        guard gen == generation else { return }
        originalThumbnail = thumbnail
        image = thumbnail
        phase = .ready
        startPreview()
    }

    /// Locked stocks stay selectable for preview (DECISIONS D6); the paywall only gates developing.
    func select(_ profile: FilmProfile) {
        guard profile.id != stock.id else { return }
        stock = profile
        startPreview()
    }

    /// Returns to the selection state after developing, keeping the same source photo
    /// so the user can try another stock without re-importing.
    func tryAnotherStock() {
        guard original != nil else { return }
        phase = .ready
        startPreview()
    }

    /// Back to the empty state for the next photo.
    func reset() {
        generation &+= 1
        previewTask?.cancel()
        previewTask = nil
        original = nil
        originalThumbnail = nil
        image = nil
        isPreviewing = false
        errorMessage = nil
        phase = .empty
    }

    func develop() async {
        guard phase == .ready, let original else { return }
        let isUnlimited = env.entitlements.isImportUnlimited
        guard env.importQuota.canImport(isUnlocked: isUnlimited), !isStockLocked else {
            paywall = PaywallRequest(stockID: stock.id)
            return
        }
        generation &+= 1
        previewTask?.cancel()
        await previewTask?.value // the engine actor cannot cancel a running preview; wait so the final render is not queued behind it
        isPreviewing = false
        phase = .developing
        errorMessage = nil
        do {
            let jpeg = try await env.filmEngine.process(original, profile: stock)
            _ = try await env.repository.appendImport(jpeg: jpeg, stockID: stock.id)
            // Only a saved frame consumes the free quota.
            if !isUnlimited { env.importQuota.recordImport() }
            refreshQuota()
            phase = .developed
        } catch {
            errorMessage = "Development failed. Try again."
            phase = .ready
        }
    }

    // MARK: - Preview

    /// Cancels the previous preview so rapid stock changes only render the last one.
    /// Uses a generation counter: after every `await`, the task checks whether it is still current.
    private func startPreview() {
        previewTask?.cancel()
        generation &+= 1
        let gen = generation
        guard let original else { return }
        let profile = stock
        isPreviewing = true
        previewTask = Task { [weak self] in
            guard let self else { return }
            defer {
                if gen == self.generation { self.isPreviewing = false }
            }
            do {
                try Task.checkCancellation()
                try await Task.sleep(for: Self.debounce)
                guard gen == self.generation, !Task.isCancelled else { return }
                let data = try await self.env.filmEngine.preview(original, profile: profile, maxDimension: Self.previewDimension)
                guard gen == self.generation, !Task.isCancelled else { return }
                guard let developed = await Self.downscaled(data, maxDimension: Self.previewDimension) else { return }
                guard gen == self.generation else { return }
                self.image = developed
            } catch {
                // Cancelled or failed: keep whatever is on screen; developing reports its own errors.
            }
        }
    }

    /// Decodes off the main actor with ImageIO so a full-resolution photo is never decoded on it.
    nonisolated static func downscaled(_ data: Data, maxDimension: CGFloat) async -> UIImage? {
        let options: [CFString: Any] = [
            kCGImageSourceCreateThumbnailFromImageAlways: true,
            kCGImageSourceCreateThumbnailWithTransform: true,
            kCGImageSourceThumbnailMaxPixelSize: maxDimension
        ]
        guard let source = CGImageSourceCreateWithData(data as CFData, nil),
              let cgImage = CGImageSourceCreateThumbnailAtIndex(source, 0, options as CFDictionary) else { return nil }
        return UIImage(cgImage: cgImage)
    }
}
