import ImageIO
import os
import Photos
import SwiftUI
import UniformTypeIdentifiers

/// Full-screen viewer: swipe between the frames of a developed roll; share or save the current one.
/// Share and save are watermarked unless the user bought something (DECISIONS D6).
struct ShotDetailView: View {
    let shots: [Shot]
    @State private var index: Int

    @Environment(AppEnvironment.self) private var env
    @Environment(\.dismiss) private var dismiss
    @State private var notice: LocalizedStringResource?

    init(shots: [Shot], startIndex: Int) {
        self.shots = shots
        _index = State(initialValue: startIndex)
    }

    private var current: Shot? { shots.indices.contains(index) ? shots[index] : nil }

    var body: some View {
        NavigationStack {
            TabView(selection: $index) {
                ForEach(Array(shots.enumerated()), id: \.element.id) { offset, shot in
                    FullFrame(shot: shot, imageStore: env.imageStore).tag(offset)
                }
            }
            .tabViewStyle(.page(indexDisplayMode: .never))
            .background(Theme.bg)
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(Theme.bg, for: .navigationBar)
            .toolbarBackground(.visible, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Done") { dismiss() }
                }
                ToolbarItem(placement: .principal) {
                    Text("\(index + 1) / \(shots.count)").monoLabel(size: 12, color: Theme.text)
                }
                ToolbarItemGroup(placement: .topBarTrailing) {
                    if let current {
                        ShareLink(item: exportable(current), preview: SharePreview("Frame \(current.index + 1)")) {
                            Image(systemName: "square.and.arrow.up")
                        }
                        Button { Task { await saveToPhotos(current) } } label: {
                            Image(systemName: "square.and.arrow.down")
                        }
                        .accessibilityLabel(Text("Save to Photos"))
                    }
                }
            }
            .alert("ROLL 36", isPresented: Binding(get: { notice != nil }, set: { if !$0 { notice = nil } })) {
                Button("OK") {}
            } message: {
                if let notice { Text(notice) }
            }
        }
        .tint(Theme.amber)
        .preferredColorScheme(.dark)
    }

    private func exportable(_ shot: Shot) -> ExportableFrame {
        ExportableFrame(
            filename: shot.imageFilename, imageStore: env.imageStore,
            filmEngine: env.filmEngine, watermark: !env.entitlements.removesWatermark
        )
    }

    /// Add-only authorization: the app never reads the user's library.
    private func saveToPhotos(_ shot: Shot) async {
        let status = await PHPhotoLibrary.requestAuthorization(for: .addOnly)
        guard status == .authorized || status == .limited else {
            notice = "Allow photo access in Settings to save frames."
            return
        }
        do {
            let data = try await exportable(shot).jpeg()
            let result = await Self.performPhotosSave(data: data)
            switch result {
            case .success:
                notice = "Saved to Photos."
            case let .failure(error):
                Log.app.error("save to Photos failed: \(error)")
                notice = "Couldn't save the frame."
            }
        } catch {
            Log.app.error("save to Photos failed: \(error)")
            notice = "Couldn't save the frame."
        }
    }

    /// Runs `PHPhotoLibrary.performChanges` on its own queue, isolated from MainActor.
    /// Returns a `Result` so the caller can update UI on MainActor.
    private nonisolated static func performPhotosSave(data: Data) async -> Result<Void, Error> {
        do {
            try await PHPhotoLibrary.shared().performChanges {
                PHAssetCreationRequest.forAsset().addResource(with: .photo, data: data, options: nil)
            }
            return .success(())
        } catch {
            return .failure(error)
        }
    }
}

/// JPEG handed to the share sheet; the watermark is applied lazily, only when the user actually shares.
private nonisolated struct ExportableFrame: Transferable {
    let filename: String
    let imageStore: ImageStore
    let filmEngine: FilmEngine
    let watermark: Bool

    static var transferRepresentation: some TransferRepresentation {
        DataRepresentation(exportedContentType: .jpeg) { try await $0.jpeg() }
    }

    func jpeg() async throws -> Data {
        guard let data = await imageStore.data(filename) else {
            throw ImageStore.StoreError.readFailed
        }
        return watermark ? try await filmEngine.watermarked(data) : data
    }
}

/// One page: loads the full-size JPEG, downsamples it for display, and supports pinch-to-zoom.
private struct FullFrame: View {
    let shot: Shot
    let imageStore: ImageStore

    @State private var image: UIImage?
    @State private var loadFailed = false
    @State private var loadToken = 0

    // Zoom state
    @State private var scale: CGFloat = 1
    @State private var lastScale: CGFloat = 1
    @State private var offset: CGSize = .zero
    @State private var lastOffset: CGSize = .zero

    fileprivate static let maxScale: CGFloat = 5

    var body: some View {
        Group {
            if let image {
                ZoomableImage(
                    image: image,
                    scale: $scale,
                    lastScale: $lastScale,
                    offset: $offset,
                    lastOffset: $lastOffset,
                    resetZoom: resetZoom
                )
            } else if loadFailed {
                LoadFailureView {
                    loadFailed = false
                    loadToken += 1
                }
            } else {
                ProgressView().tint(Theme.muted)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .task(id: "\(shot.id)-\(loadToken)") {
            guard let data = await imageStore.data(shot.imageFilename) else {
                Log.storage.error("FullFrame load failed for \(shot.imageFilename)")
                loadFailed = true
                return
            }
            image = await Self.downsample(data)
            if image == nil { loadFailed = true }
        }
    }

    private func resetZoom() {
        withAnimation(.easeInOut(duration: 0.25)) {
            scale = 1
            lastScale = 1
            offset = .zero
            lastOffset = .zero
        }
    }

    private nonisolated static let maxPixelSize = 2400

    @concurrent private static func downsample(_ data: Data) async -> UIImage? {
        let options: [CFString: Any] = [
            kCGImageSourceCreateThumbnailFromImageAlways: true,
            kCGImageSourceCreateThumbnailWithTransform: true,
            kCGImageSourceThumbnailMaxPixelSize: maxPixelSize
        ]
        guard let source = CGImageSourceCreateWithData(data as CFData, nil),
              let cgImage = CGImageSourceCreateThumbnailAtIndex(source, 0, options as CFDictionary)
        else { return nil }
        return UIImage(cgImage: cgImage)
    }
}

/// Pinch-to-zoom + drag + double-tap-to-reset, clamped so the image stays on-screen.
private struct ZoomableImage: View {
    let image: UIImage
    @Binding var scale: CGFloat
    @Binding var lastScale: CGFloat
    @Binding var offset: CGSize
    @Binding var lastOffset: CGSize
    let resetZoom: () -> Void

    var body: some View {
        GeometryReader { geo in
            let clamped = clampedOffset(in: geo.size)
            let base = Image(uiImage: image)
                .resizable()
                .scaledToFit()
                .scaleEffect(scale)
                .offset(clamped)
                .gesture(magnification)
                .onTapGesture(count: 2) { resetZoom() }

            if scale > 1.0 {
                base.gesture(drag(in: geo.size))
            } else {
                base
            }
        }
    }

    private var magnification: some Gesture {
        MagnificationGesture()
            .onChanged { value in
                let new = lastScale * value
                scale = min(max(1, new), FullFrame.maxScale)
            }
            .onEnded { _ in
                if scale < 1.1 {
                    resetZoom()
                } else {
                    lastScale = scale
                }
            }
    }

    private func drag(in _: CGSize) -> some Gesture {
        DragGesture()
            .onChanged { value in
                offset = CGSize(
                    width: lastOffset.width + value.translation.width,
                    height: lastOffset.height + value.translation.height
                )
            }
            .onEnded { _ in
                lastOffset = offset
            }
    }

    /// Keeps the image from being dragged more than half its scaled size beyond the viewport.
    private func clampedOffset(in size: CGSize) -> CGSize {
        guard scale > 1 else { return .zero }
        let maxX = size.width * (scale - 1) / 2
        let maxY = size.height * (scale - 1) / 2
        return CGSize(
            width: min(max(offset.width, -maxX), maxX),
            height: min(max(offset.height, -maxY), maxY)
        )
    }
}

/// Error placeholder shown when a full-frame JPEG cannot be loaded.
private struct LoadFailureView: View {
    let retry: () -> Void

    var body: some View {
        VStack(spacing: Theme.spacingS) {
            Image(systemName: "exclamationmark.triangle")
                .font(.title2)
                .foregroundStyle(Theme.red)
            Text("Could not load frame")
                .monoLabel(size: 12, color: Theme.red)
            Button("Retry", action: retry)
                .monoLabel(size: 12, color: Theme.amber)
        }
    }
}
