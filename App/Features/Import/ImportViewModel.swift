import ImageIO
import Observation
import SwiftUI
import UIKit

/// State machine of the Import screen (PLAN §11): photo -> stock -> low-res preview -> full-res develop.
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
    private(set) var isPreviewing = false
    private(set) var errorMessage: LocalizedStringKey?
    /// Free imports left; nil when unlimited.
    private(set) var remaining: Int?
    var paywall: PaywallRequest?

    private let env: AppEnvironment
    private var original: Data?
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

    func load(_ data: Data) async {
        errorMessage = nil
        original = data
        guard let thumbnail = await Self.downscaled(data, maxDimension: Self.previewDimension) else {
            original = nil
            image = nil
            phase = .empty
            loadFailed()
            return
        }
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

    /// Back to the empty state for the next photo.
    func reset() {
        previewTask?.cancel()
        original = nil
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
    private func startPreview() {
        previewTask?.cancel()
        guard let original else { return }
        let profile = stock
        isPreviewing = true
        previewTask = Task {
            defer { if !Task.isCancelled { isPreviewing = false } }
            do {
                try await Task.sleep(for: Self.debounce)
                let data = try await env.filmEngine.preview(original, profile: profile, maxDimension: Self.previewDimension)
                guard !Task.isCancelled, let developed = await Self.downscaled(data, maxDimension: Self.previewDimension) else { return }
                image = developed
            } catch {
                // Cancelled or failed: keep whatever is on screen; developing reports its own errors.
            }
        }
    }

    /// Decodes off the main actor with ImageIO so a full-resolution photo is never decoded on it.
    @concurrent private static func downscaled(_ data: Data, maxDimension: CGFloat) async -> UIImage? {
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
