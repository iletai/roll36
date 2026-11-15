import CoreImage
import CoreImage.CIFilterBuiltins

/// Halation and bloom (PLAN §8.2 steps 2-3, §8.5). Both start from the same highlight mask.
nonisolated enum HalationRenderer {
    /// Screen-blend strength of the halation glow (PLAN §8.5: 0.5-0.7).
    private static let halationOpacity: Float = 0.6

    /// `scale` = image width / 1000, so radii match at every resolution.
    static func apply(to image: CIImage, profile: FilmProfile, scale: Double) -> CIImage {
        let extent = image.extent
        let highlights = highlightMask(image, threshold: profile.halationThreshold)

        let halo = tinted(
            blurred(highlights, radius: profile.halationRadius * scale, extent: extent),
            by: SIMD3(profile.halationTint) * halationOpacity
        )
        let screen = CIFilter.screenBlendMode()
        screen.inputImage = halo
        screen.backgroundImage = image
        guard let haloed = screen.outputImage else { return image }

        // Bloom: wider, untinted glow. Screen instead of CIAdditionCompositing, which also sums alpha (1 + 1)
        // and breaks the later soft-light grain; for a faint glow screen is near-additive.
        let bloom = tinted(
            blurred(highlights, radius: profile.halationRadius * 2 * scale, extent: extent),
            by: SIMD3(repeating: Float(profile.bloomIntensity))
        )
        let bloomScreen = CIFilter.screenBlendMode()
        bloomScreen.inputImage = bloom
        bloomScreen.backgroundImage = haloed
        return bloomScreen.outputImage?.cropped(to: extent) ?? haloed
    }

    /// Keeps only what is above `threshold`, rescaled to 0...1.
    private static func highlightMask(_ image: CIImage, threshold: Double) -> CIImage {
        // Thresholds are tuned on sRGB-encoded values; the CI working space is linear.
        let t = pow(threshold, 2.2)
        let k = CGFloat(1 / (1 - t))
        let bias = CGFloat(-t / (1 - t))
        let matrix = CIFilter.colorMatrix()
        matrix.inputImage = image
        matrix.rVector = CIVector(x: k, y: 0, z: 0, w: 0)
        matrix.gVector = CIVector(x: 0, y: k, z: 0, w: 0)
        matrix.bVector = CIVector(x: 0, y: 0, z: k, w: 0)
        matrix.biasVector = CIVector(x: bias, y: bias, z: bias, w: 0)
        let clamp = CIFilter.colorClamp()
        clamp.inputImage = matrix.outputImage
        clamp.minComponents = CIVector(x: 0, y: 0, z: 0, w: 1)
        clamp.maxComponents = CIVector(x: 1, y: 1, z: 1, w: 1)
        return clamp.outputImage ?? image
    }

    private static func blurred(_ image: CIImage, radius: Double, extent: CGRect) -> CIImage {
        image.clampedToExtent().applyingGaussianBlur(sigma: radius).cropped(to: extent)
    }

    private static func tinted(_ image: CIImage, by rgb: SIMD3<Float>) -> CIImage {
        let matrix = CIFilter.colorMatrix()
        matrix.inputImage = image
        matrix.rVector = CIVector(x: CGFloat(rgb.x), y: 0, z: 0, w: 0)
        matrix.gVector = CIVector(x: 0, y: CGFloat(rgb.y), z: 0, w: 0)
        matrix.bVector = CIVector(x: 0, y: 0, z: CGFloat(rgb.z), w: 0)
        return matrix.outputImage ?? image
    }
}
