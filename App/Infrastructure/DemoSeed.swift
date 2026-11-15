#if DEBUG
    import ImageIO
    import os
    import SwiftData
    import SwiftUI
    import UIKit
    import UniformTypeIdentifiers

    /// Debug-only demo data for the App Store screenshots (scripts/screenshots/capture.sh).
    /// Launch with `-demoSeed`; the sample photos are copied into `Documents/DemoPhotos/` by the script.
    /// Compiled out of Release builds, so shipping builds never look at launch arguments for this.
    enum DemoSeed {
        nonisolated static let isEnabled = CommandLine.arguments.contains("-demoSeed")

        private nonisolated static let maxPixel = 1600
        private static let hour: TimeInterval = 3600

        nonisolated static func photoURL(_ number: Int) -> URL {
            URL.documentsDirectory.appending(path: "DemoPhotos/photo-\(number).jpg")
        }

        nonisolated static func photoData(_ number: Int) -> Data? {
            try? Data(contentsOf: photoURL(number))
        }

        /// Full-bleed stand-in for the live sensor in the simulator viewfinder.
        static let previewImage = UIImage(contentsOfFile: photoURL(1).path)

        /// Seeds five rolls, one per state, when asked to and the store is empty (so relaunching is a no-op).
        static func seedIfNeeded(_ env: AppEnvironment) async {
            guard isEnabled, (try? env.repository.rolls().isEmpty) == true else { return }
            let variants = makeVariants()
            guard !variants.isEmpty else {
                Log.app.error("Demo seed: no photos in Documents/DemoPhotos")
                return
            }
            let now = Date.now
            do {
                // Order in the Darkroom list is createdAt descending.
                let developing = try await shoot(env, variants, RollSpec(stockID: "expiredGold", capacity: 24, frames: 24, created: now - 3 * hour))
                developing.developStartedAt = now - 0.4 * RollRepository.developDuration
                _ = try await shoot(env, variants, RollSpec(stockID: "cinestill800t", frames: 22, created: now - 4 * hour))
                let portra = try await shoot(env, variants, RollSpec(stockID: "portra400", frames: 15, processed: true, created: now - 26 * hour))
                portra.developStartedAt = now - 2 * hour
                let trix = try await shoot(env, variants, RollSpec(stockID: "trix400", frames: 12, processed: true, created: now - 50 * hour, offset: 7))
                trix.developStartedAt = now - 2 * hour
                _ = try await shoot(env, variants, RollSpec(stockID: "portra400", frames: 12, isInCamera: true, created: now - 70 * hour))
                try env.modelContainer.mainContext.save()
            } catch {
                Log.app.error("Demo seed failed: \(error)")
            }
        }

        private struct RollSpec {
            var stockID: String
            var capacity = 36
            var frames: Int
            /// Only developed rolls show their frames, so only those go through the film engine.
            var processed = false
            var isInCamera = false
            var created: Date
            /// First sample frame; also shifts the capture times so both developed rolls interleave in the "recent frames" strip.
            var offset = 0
        }

        private static func shoot(_ env: AppEnvironment, _ variants: [Data], _ spec: RollSpec) async throws -> Roll {
            let roll = try env.repository.startRoll(stockID: spec.stockID, capacity: spec.capacity)
            roll.createdAt = spec.created
            let profile = FilmCatalog.profile(id: spec.stockID) ?? FilmCatalog.free
            for index in 0 ..< spec.frames {
                let source = variants[(spec.offset + index) % variants.count]
                let jpeg = spec.processed ? try await env.filmEngine.process(source, profile: profile) : source
                let shot = try await env.repository.appendShot(jpeg: jpeg, to: roll)
                shot.capturedAt = spec.created.addingTimeInterval(TimeInterval(index) * 120 + (spec.offset == 0 ? 0 : 60))
            }
            // Short of the capacity means the roll was finished early, i.e. it is no longer in the camera.
            if spec.frames < spec.capacity, !spec.isInCamera { try env.repository.finishEarly(roll) }
            return roll
        }

        /// 15 distinct portrait frames: each sample photo as is, cropped top-left and cropped bottom-right.
        private static func makeVariants() -> [Data] {
            let crops: [(scale: CGFloat, anchor: CGPoint)] = [(1, .zero), (0.78, .zero), (0.78, CGPoint(x: 1, y: 1))]
            let images = (1 ... 5).compactMap { photoData($0).flatMap(downscaled) }
            return crops.flatMap { crop in
                images.compactMap { image -> Data? in
                    let width = CGFloat(image.width) * crop.scale, height = CGFloat(image.height) * crop.scale
                    let rect = CGRect(
                        x: (CGFloat(image.width) - width) * crop.anchor.x, y: (CGFloat(image.height) - height) * crop.anchor.y,
                        width: width, height: height
                    ).integral
                    return image.cropping(to: rect).flatMap(jpeg)
                }
            }
        }

        private static func downscaled(_ data: Data) -> CGImage? {
            let options: [CFString: Any] = [
                kCGImageSourceCreateThumbnailFromImageAlways: true,
                kCGImageSourceCreateThumbnailWithTransform: true,
                kCGImageSourceThumbnailMaxPixelSize: maxPixel
            ]
            return CGImageSourceCreateWithData(data as CFData, nil)
                .flatMap { CGImageSourceCreateThumbnailAtIndex($0, 0, options as CFDictionary) }
        }

        private static func jpeg(_ image: CGImage) -> Data? {
            let data = NSMutableData()
            guard let destination = CGImageDestinationCreateWithData(data, UTType.jpeg.identifier as CFString, 1, nil) else { return nil }
            CGImageDestinationAddImage(destination, image, [kCGImageDestinationLossyCompressionQuality: 0.92] as CFDictionary)
            return CGImageDestinationFinalize(destination) ? data as Data : nil
        }
    }

    /// Holds the UI back (plain black) until the demo store is seeded, so no screen ever reads half-seeded data.
    struct DemoSeedGate<Content: View>: View {
        let env: AppEnvironment
        @ViewBuilder let content: () -> Content
        @State private var isReady = !DemoSeed.isEnabled

        var body: some View {
            if isReady {
                content()
            } else {
                Color.black.ignoresSafeArea()
                    .task {
                        await DemoSeed.seedIfNeeded(env)
                        isReady = true
                    }
            }
        }
    }
#endif
