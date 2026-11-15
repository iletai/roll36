import Foundation

/// One film stock as a set of numbers; the LUT is generated from these (PLAN §7.3, §8.1).
nonisolated struct FilmProfile: Identifiable, Codable, Hashable, Sendable {
    enum Process: String, Codable, Sendable {
        case c41, e6, bw
    }

    enum Group: String, CaseIterable, Codable, Sendable {
        case portrait, monochrome, night, expired, slide
    }

    let id: String
    let displayName: String
    let iso: Int
    let process: Process
    let isMonochrome: Bool
    let isFree: Bool

    // Tone
    var contrast: Double // 0.80...1.40, pivot 0.18
    var saturation: Double // 0.0...1.40
    var lift: SIMD3<Double> // added to shadows, ~ -0.02...0.03
    var gain: SIMD3<Double> // multiplies highlights, ~ 0.96...1.04
    var fade: Double // 0...0.12, raises the black point

    // Split tone
    var shadowTint: SIMD3<Double>
    var highlightTint: SIMD3<Double>
    var tintStrength: Double // 0...1

    // Texture
    var grainIntensity: Double // 0...1
    var grainSize: Double // px at 1000px width
    var halationThreshold: Double // 0.60...0.95
    var halationRadius: Double // px at 1000px width
    var halationTint: SIMD3<Double>
    var bloomIntensity: Double // 0...0.5
    var vignetteIntensity: Double // 0...1

    // UI
    let group: Group
    let listPrice: Decimal // fallback label only; StoreKit displayPrice wins (DECISIONS D5)
    let processCode: String
    let tagline: String
    let swatchHex: UInt32
    let frames: Int
}
