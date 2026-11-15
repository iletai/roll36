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
            try await PHPhotoLibrary.shared().performChanges {
                PHAssetCreationRequest.forAsset().addResource(with: .photo, data: data, options: nil)
            }
            notice = "Saved to Photos."
        } catch {
            Log.app.error("save to Photos failed: \(error)")
            notice = "Couldn't save the frame."
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
        let data = try await imageStore.data(filename)
        return watermark ? try await filmEngine.watermarked(data) : data
    }
}

/// One page: loads the full-size JPEG and downsamples it for display.
private struct FullFrame: View {
    let shot: Shot
    let imageStore: ImageStore
    @State private var image: UIImage?

    var body: some View {
        Group {
            if let image {
                Image(uiImage: image).resizable().scaledToFit()
            } else {
                ProgressView().tint(Theme.muted)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .task(id: shot.id) {
            guard let data = try? await imageStore.data(shot.imageFilename) else { return }
            image = await Self.downsample(data)
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
