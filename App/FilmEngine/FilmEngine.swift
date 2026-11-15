import CoreImage
import CoreImage.CIFilterBuiltins
import ImageIO
import Metal
import os
import UIKit

nonisolated enum FilmEngineError: Error {
    case decodeFailed, renderFailed, encodeFailed
}

/// Develops a JPEG with a film stock (PLAN §8.2). Owns the only CIContext; it never leaves the actor.
actor FilmEngine {
    nonisolated enum Quality: Sendable {
        case final, preview // preview = 17³ cube + downscaled
    }

    private static let previewMaxDimension: CGFloat = 1080
    private static let jpegQuality = 0.92

    private let lutCache: LUTCache
    private let context: CIContext
    private let sRGB = CGColorSpace(name: CGColorSpace.sRGB) ?? CGColorSpaceCreateDeviceRGB()

    init(lutCache: LUTCache = LUTCache()) {
        self.lutCache = lutCache
        if let device = MTLCreateSystemDefaultDevice() {
            context = CIContext(mtlDevice: device)
        } else {
            context = CIContext(options: [.useSoftwareRenderer: true])
        }
    }

    /// Returns an sRGB JPEG with the EXIF orientation baked in.
    func process(_ jpeg: Data, profile: FilmProfile, quality: Quality = .final) async throws -> Data {
        switch quality {
        case .final:
            try await develop(jpeg, profile: profile, cubeDimension: ColorCubeBuilder.dimension, maxDimension: nil)
        case .preview:
            try await develop(jpeg, profile: profile, cubeDimension: ColorCubeBuilder.previewDimension, maxDimension: Self.previewMaxDimension)
        }
    }

    func preview(_ jpeg: Data, profile: FilmProfile, maxDimension: CGFloat = 1080) async throws -> Data {
        try await develop(jpeg, profile: profile, cubeDimension: ColorCubeBuilder.previewDimension, maxDimension: maxDimension)
    }

    /// PLAN §12.3: "ROLL 36" monospaced, bottom-right, opacity 0.35, height 2% of image width.
    func watermarked(_ jpeg: Data) async throws -> Data {
        let image = try decode(jpeg, maxDimension: nil)
        let width = image.extent.width
        let targetHeight = width * 0.02

        let text = NSAttributedString(string: "ROLL 36", attributes: [
            .font: UIFont.monospacedSystemFont(ofSize: targetHeight, weight: .medium),
            .foregroundColor: UIColor(white: 1, alpha: 0.35)
        ])
        let generator = CIFilter.attributedTextImageGenerator()
        generator.text = text
        guard let mark = generator.outputImage, mark.extent.height > 0 else { throw FilmEngineError.renderFailed }

        let s = targetHeight / mark.extent.height
        let margin = targetHeight
        let placed = mark
            .transformed(by: CGAffineTransform(translationX: -mark.extent.minX, y: -mark.extent.minY))
            .transformed(by: CGAffineTransform(scaleX: s, y: s))
            .transformed(by: CGAffineTransform(translationX: width - mark.extent.width * s - margin, y: margin))
        return try encode(placed.composited(over: image).cropped(to: image.extent))
    }

    // MARK: - Pipeline

    private func develop(_ jpeg: Data, profile: FilmProfile, cubeDimension: Int, maxDimension: CGFloat?) async throws -> Data {
        let start = ContinuousClock.now
        let cubeData = await lutCache.cube(for: profile, dimension: cubeDimension)
        let source = try decode(jpeg, maxDimension: maxDimension)
        let extent = source.extent
        let scale = extent.width / 1000

        // 1. ColorCube, applied to sRGB-encoded values (profile parameters are tuned that way).
        let cube = CIFilter.colorCubeWithColorSpace()
        cube.inputImage = source
        cube.cubeDimension = Float(cubeDimension)
        cube.cubeData = cubeData
        cube.colorSpace = sRGB
        guard var image = cube.outputImage else { throw FilmEngineError.renderFailed }

        // 2-3. Halation + bloom
        image = HalationRenderer.apply(to: image, profile: profile, scale: scale)

        // 4. Grain
        image = GrainRenderer.apply(to: image, profile: profile, scale: scale)

        // 5. Vignette
        let vignette = CIFilter.vignetteEffect()
        vignette.inputImage = image
        vignette.center = CGPoint(x: extent.midX, y: extent.midY)
        vignette.radius = Float(hypot(extent.width, extent.height) / 2) // pixels; half-diagonal gives ~20% corner falloff at intensity 0.2
        vignette.intensity = Float(profile.vignetteIntensity)
        vignette.falloff = 0.5
        image = vignette.outputImage ?? image

        // 6. Light sharpen to offset blur softness
        let sharpen = CIFilter.sharpenLuminance()
        sharpen.inputImage = image
        sharpen.sharpness = 0.3
        image = (sharpen.outputImage ?? image).cropped(to: extent)

        let output = try encode(image)
        let elapsed = ContinuousClock.now - start
        Log.film.info("Developed \(profile.id, privacy: .public) \(Int(extent.width))x\(Int(extent.height)) d\(cubeDimension) in \(elapsed.formatted(.units(allowed: [.milliseconds])), privacy: .public)")
        return output
    }

    private func decode(_ jpeg: Data, maxDimension: CGFloat?) throws -> CIImage {
        guard var image = CIImage(data: jpeg, options: [.applyOrientationProperty: true]) else {
            throw FilmEngineError.decodeFailed
        }
        image = image.transformed(by: CGAffineTransform(translationX: -image.extent.minX, y: -image.extent.minY))
        if let maxDimension, max(image.extent.width, image.extent.height) > maxDimension {
            let filter = CIFilter.lanczosScaleTransform()
            filter.inputImage = image
            filter.scale = Float(maxDimension / max(image.extent.width, image.extent.height))
            filter.aspectRatio = 1
            guard let scaled = filter.outputImage else { throw FilmEngineError.renderFailed }
            let size = CGSize(width: scaled.extent.width.rounded(.down), height: scaled.extent.height.rounded(.down))
            image = scaled.cropped(to: CGRect(origin: .zero, size: size))
        }
        return image
    }

    private func encode(_ image: CIImage) throws -> Data {
        let options = [CIImageRepresentationOption(rawValue: kCGImageDestinationLossyCompressionQuality as String): Self.jpegQuality]
        guard let data = context.jpegRepresentation(of: image, colorSpace: sRGB, options: options) else {
            throw FilmEngineError.encodeFailed
        }
        return data
    }
}
