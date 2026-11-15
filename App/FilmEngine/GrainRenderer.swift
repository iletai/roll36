import CoreImage
import CoreImage.CIFilterBuiltins

/// Film grain (PLAN §8.2 step 4, §8.4).
/// shortcut: CIRandomGenerator is not seeded, so re-developing a shot gives different grain; v1 never re-develops (PLAN §8.4). Seed from shot.id if that changes.
nonisolated enum GrainRenderer {
    /// `scale` = image width / 1000, so grain looks the same at every resolution.
    static func apply(to image: CIImage, profile: FilmProfile, scale: Double) -> CIImage {
        guard profile.grainIntensity > 0, let noise = CIFilter.randomGenerator().outputImage else { return image }
        let extent = image.extent
        let size = max(0.6, profile.grainSize * scale)

        // Enlarge the per-pixel noise to grain size, then soften so grains are not digital squares.
        // The generator's alpha is random too; force it to 1 or later filters unpremultiply garbage.
        let noiseRect = CGRect(x: 0, y: 0, width: extent.width / size + 2, height: extent.height / size + 2)
        let grains = noise
            .cropped(to: noiseRect)
            .settingAlphaOne(in: noiseRect)
            .transformed(by: CGAffineTransform(scaleX: size, y: size))
            .applyingGaussianBlur(sigma: size * 0.5)
            .cropped(to: extent)

        // Monochrome, centered on 0.5 (neutral for soft light), deviation scaled by intensity.
        let k = CGFloat(profile.grainIntensity * 3) // blur flattens the noise; boost to stay visible
        let w = k / 3
        let matrix = CIFilter.colorMatrix()
        matrix.inputImage = grains
        let luma = CIVector(x: w, y: w, z: w, w: 0)
        matrix.rVector = luma
        matrix.gVector = luma
        matrix.bVector = luma
        matrix.aVector = CIVector(x: 0, y: 0, z: 0, w: 0)
        let offset = 0.5 * (1 - k)
        matrix.biasVector = CIVector(x: offset, y: offset, z: offset, w: 1)

        let blend = CIFilter.softLightBlendMode()
        blend.inputImage = matrix.outputImage
        blend.backgroundImage = image
        return blend.outputImage?.cropped(to: extent) ?? image
    }
}
