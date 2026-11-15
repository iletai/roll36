import Foundation

/// Generates CIColorCube data from a FilmProfile (PLAN §8.3). Values are sRGB-encoded (the engine applies the cube in sRGB space).
nonisolated enum ColorCubeBuilder {
    static let dimension = 33
    /// Smaller cube for live/preview renders (PLAN §8.6).
    static let previewDimension = 17

    /// RGBA float32, alpha = 1, red varies fastest (CIColorCube layout).
    static func makeCube(for profile: FilmProfile, dimension: Int = dimension) -> Data {
        let step = 1.0 / Double(dimension - 1)
        var values = [Float]()
        values.reserveCapacity(dimension * dimension * dimension * 4)
        for b in 0 ..< dimension {
            for g in 0 ..< dimension {
                for r in 0 ..< dimension {
                    let c = transform(SIMD3(Double(r) * step, Double(g) * step, Double(b) * step), profile)
                    values += [Float(c.x), Float(c.y), Float(c.z), 1]
                }
            }
        }
        return values.withUnsafeBufferPointer { Data(buffer: $0) }
    }

    static func transform(_ rgb: SIMD3<Double>, _ p: FilmProfile) -> SIMD3<Double> {
        var c = rgb

        // 1. Contrast around pivot 0.18 (keeps midtones stable)
        c = (c - 0.18) * p.contrast + 0.18

        // 2. Lift / Gain
        c = c * p.gain + p.lift

        // 3. Fade: raise black point, compress white point
        c = c * (1.0 - p.fade) + p.fade * 0.55

        // 4. Split tone by luminance
        let luma = luminance(c)
        let w = smoothstep(0.15, 0.85, luma) // 0 = shadows, 1 = highlights
        let tint = p.shadowTint * (1 - w) + p.highlightTint * w
        c *= 1 + (tint - 1) * p.tintStrength

        // 5. Saturation (or full desaturation for monochrome)
        let l = SIMD3(repeating: luminance(c))
        let sat = p.isMonochrome ? 0.0 : p.saturation
        c = l + (c - l) * sat

        // 6. Clamp
        return c.clamped(lowerBound: .zero, upperBound: .one)
    }

    private static func luminance(_ c: SIMD3<Double>) -> Double {
        0.2126 * c.x + 0.7152 * c.y + 0.0722 * c.z
    }

    private static func smoothstep(_ edge0: Double, _ edge1: Double, _ x: Double) -> Double {
        let t = min(max((x - edge0) / (edge1 - edge0), 0), 1)
        return t * t * (3 - 2 * t)
    }
}
