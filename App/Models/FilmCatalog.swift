import Foundation

/// The 14 stocks of v1 (PLAN §7.4). The four PLAN fixtures are verbatim; the rest are starting points to tune against real film scans.
nonisolated enum FilmCatalog {
    static let all: [FilmProfile] = [
        portra400, ektar100, fuji400h, gold200, ultramax400,
        trix400, hp5, acros100,
        cinestill800t, portra800,
        expiredGold, expiredFuji,
        velvia50, provia100
    ]

    static let free: FilmProfile = portra400

    static func profile(id: String) -> FilmProfile? {
        all.first { $0.id == id }
    }

    static func profiles(in group: FilmProfile.Group) -> [FilmProfile] {
        all.filter { $0.group == group }
    }

    /// Exact decimal from cents (a Double literal would give 1.4900000000000002).
    private static func usd(_ cents: Int) -> Decimal {
        Decimal(cents) / 100
    }

    // MARK: - Portrait

    static let portra400 = FilmProfile(
        id: "portra400", displayName: "Portra 400", iso: 400,
        process: .c41, isMonochrome: false, isFree: true,
        contrast: 0.92, saturation: 0.94,
        lift: SIMD3(0.010, 0.004, -0.006),
        gain: SIMD3(1.020, 1.000, 0.975),
        fade: 0.02,
        shadowTint: SIMD3(0.96, 0.99, 1.04),
        highlightTint: SIMD3(1.04, 1.00, 0.95),
        tintStrength: 0.45,
        grainIntensity: 0.30, grainSize: 1.6,
        halationThreshold: 0.86, halationRadius: 9,
        halationTint: SIMD3(1.0, 0.55, 0.40), bloomIntensity: 0.10,
        vignetteIntensity: 0.16,
        group: .portrait, listPrice: 0, processCode: "C-41",
        tagline: "FINE GRAIN · NEUTRAL SKIN", swatchHex: 0xD9784A, frames: 36
    )

    static let ektar100 = FilmProfile(
        id: "ektar100", displayName: "Ektar 100", iso: 100,
        process: .c41, isMonochrome: false, isFree: false,
        contrast: 1.15, saturation: 1.25,
        lift: SIMD3(0.000, 0.000, 0.002),
        gain: SIMD3(1.020, 1.000, 0.980),
        fade: 0.0,
        shadowTint: SIMD3(0.98, 1.00, 1.04),
        highlightTint: SIMD3(1.04, 1.00, 0.96),
        tintStrength: 0.30,
        grainIntensity: 0.12, grainSize: 1.1,
        halationThreshold: 0.90, halationRadius: 7,
        halationTint: SIMD3(1.0, 0.50, 0.40), bloomIntensity: 0.06,
        vignetteIntensity: 0.14,
        group: .portrait, listPrice: usd(149), processCode: "C-41",
        tagline: "ULTRA VIVID · MICRO GRAIN", swatchHex: 0xB8361F, frames: 36
    )

    static let fuji400h = FilmProfile(
        id: "fuji400h", displayName: "Fuji Pro 400H", iso: 400,
        process: .c41, isMonochrome: false, isFree: false,
        contrast: 0.94, saturation: 0.88,
        lift: SIMD3(-0.004, 0.008, 0.012),
        gain: SIMD3(0.990, 1.010, 1.000),
        fade: 0.03,
        shadowTint: SIMD3(0.94, 1.03, 1.04),
        highlightTint: SIMD3(1.01, 1.01, 0.98),
        tintStrength: 0.50,
        grainIntensity: 0.32, grainSize: 1.7,
        halationThreshold: 0.87, halationRadius: 8,
        halationTint: SIMD3(1.0, 0.60, 0.45), bloomIntensity: 0.10,
        vignetteIntensity: 0.15,
        group: .portrait, listPrice: usd(149), processCode: "C-41",
        tagline: "SOFT HIGHLIGHT · COOL TEAL", swatchHex: 0x5C8F8A, frames: 36
    )

    static let gold200 = FilmProfile(
        id: "gold200", displayName: "Gold 200", iso: 200,
        process: .c41, isMonochrome: false, isFree: false,
        contrast: 1.04, saturation: 1.08,
        lift: SIMD3(0.012, 0.006, -0.008),
        gain: SIMD3(1.030, 1.010, 0.950),
        fade: 0.02,
        shadowTint: SIMD3(1.02, 1.00, 0.96),
        highlightTint: SIMD3(1.06, 1.02, 0.90),
        tintStrength: 0.50,
        grainIntensity: 0.36, grainSize: 1.8,
        halationThreshold: 0.86, halationRadius: 9,
        halationTint: SIMD3(1.0, 0.60, 0.40), bloomIntensity: 0.10,
        vignetteIntensity: 0.20,
        group: .portrait, listPrice: usd(99), processCode: "C-41",
        tagline: "WARM GOLD · SUNNY CAST", swatchHex: 0xEFA43A, frames: 36
    )

    static let ultramax400 = FilmProfile(
        id: "ultramax400", displayName: "UltraMax 400", iso: 400,
        process: .c41, isMonochrome: false, isFree: false,
        contrast: 1.10, saturation: 1.15,
        lift: SIMD3(0.008, 0.004, -0.004),
        gain: SIMD3(1.025, 1.000, 0.970),
        fade: 0.015,
        shadowTint: SIMD3(1.00, 0.99, 1.02),
        highlightTint: SIMD3(1.05, 1.01, 0.93),
        tintStrength: 0.45,
        grainIntensity: 0.40, grainSize: 1.9,
        halationThreshold: 0.85, halationRadius: 9,
        halationTint: SIMD3(1.0, 0.55, 0.40), bloomIntensity: 0.10,
        vignetteIntensity: 0.20,
        group: .portrait, listPrice: usd(99), processCode: "C-41",
        tagline: "WARM PUNCH · EVERYDAY", swatchHex: 0xE0C341, frames: 36
    )

    // MARK: - Monochrome

    static let trix400 = FilmProfile(
        id: "trix400", displayName: "Tri-X 400", iso: 400,
        process: .bw, isMonochrome: true, isFree: false,
        contrast: 1.18, saturation: 0.0,
        lift: SIMD3(0, 0, 0), gain: SIMD3(1.0, 1.0, 1.0),
        fade: 0.03,
        shadowTint: SIMD3(1, 1, 1), highlightTint: SIMD3(1, 1, 1), tintStrength: 0,
        grainIntensity: 0.62, grainSize: 2.4,
        halationThreshold: 0.92, halationRadius: 5,
        halationTint: SIMD3(1, 1, 1), bloomIntensity: 0.04,
        vignetteIntensity: 0.22,
        group: .monochrome, listPrice: usd(149), processCode: "D-76",
        tagline: "HEAVY SILVER · PUNCHY", swatchHex: 0x2B2B2E, frames: 36
    )

    static let hp5 = FilmProfile(
        id: "hp5", displayName: "HP5 Plus", iso: 400,
        process: .bw, isMonochrome: true, isFree: false,
        contrast: 1.06, saturation: 0.0,
        lift: SIMD3(0, 0, 0), gain: SIMD3(1.0, 1.0, 1.0),
        fade: 0.04,
        shadowTint: SIMD3(1, 1, 1), highlightTint: SIMD3(1, 1, 1), tintStrength: 0,
        grainIntensity: 0.50, grainSize: 2.2,
        halationThreshold: 0.92, halationRadius: 5,
        halationTint: SIMD3(1, 1, 1), bloomIntensity: 0.05,
        vignetteIntensity: 0.18,
        group: .monochrome, listPrice: usd(149), processCode: "D-76",
        tagline: "SOFT SILVER · WIDE LATITUDE", swatchHex: 0x5A5A5E, frames: 36
    )

    static let acros100 = FilmProfile(
        id: "acros100", displayName: "Acros 100", iso: 100,
        process: .bw, isMonochrome: true, isFree: false,
        contrast: 1.12, saturation: 0.0,
        lift: SIMD3(0, 0, 0), gain: SIMD3(1.0, 1.0, 1.0),
        fade: 0.01,
        shadowTint: SIMD3(1, 1, 1), highlightTint: SIMD3(1, 1, 1), tintStrength: 0,
        grainIntensity: 0.18, grainSize: 1.1,
        halationThreshold: 0.94, halationRadius: 4,
        halationTint: SIMD3(1, 1, 1), bloomIntensity: 0.03,
        vignetteIntensity: 0.14,
        group: .monochrome, listPrice: usd(99), processCode: "D-76",
        tagline: "FINE SILVER · DEEP BLACKS", swatchHex: 0x8E8E93, frames: 36
    )

    // MARK: - Night

    static let cinestill800t = FilmProfile(
        id: "cinestill800t", displayName: "Cinestill 800T", iso: 800,
        process: .c41, isMonochrome: false, isFree: false,
        contrast: 1.02, saturation: 0.90,
        lift: SIMD3(0.004, 0.000, 0.018),
        gain: SIMD3(0.985, 1.000, 1.035),
        fade: 0.01,
        shadowTint: SIMD3(0.94, 0.98, 1.10),
        highlightTint: SIMD3(1.06, 0.98, 0.94),
        tintStrength: 0.60,
        grainIntensity: 0.42, grainSize: 1.9,
        halationThreshold: 0.72, halationRadius: 14,
        halationTint: SIMD3(1.0, 0.35, 0.30), bloomIntensity: 0.22,
        vignetteIntensity: 0.18,
        group: .night, listPrice: usd(149), processCode: "ECN-2",
        tagline: "HALATION GLOW · TUNGSTEN", swatchHex: 0x1F4A7F, frames: 36
    )

    static let portra800 = FilmProfile(
        id: "portra800", displayName: "Portra 800", iso: 800,
        process: .c41, isMonochrome: false, isFree: false,
        contrast: 0.96, saturation: 1.00,
        lift: SIMD3(0.012, 0.004, -0.004),
        gain: SIMD3(1.025, 1.000, 0.970),
        fade: 0.025,
        shadowTint: SIMD3(0.97, 0.99, 1.03),
        highlightTint: SIMD3(1.05, 1.00, 0.94),
        tintStrength: 0.50,
        grainIntensity: 0.45, grainSize: 2.0,
        halationThreshold: 0.82, halationRadius: 11,
        halationTint: SIMD3(1.0, 0.50, 0.38), bloomIntensity: 0.16,
        vignetteIntensity: 0.20,
        group: .night, listPrice: usd(149), processCode: "C-41",
        tagline: "WARM NIGHT · VISIBLE GRAIN", swatchHex: 0x6E3B5C, frames: 36
    )

    // MARK: - Expired

    static let expiredGold = FilmProfile(
        id: "expiredGold", displayName: "Expired Gold", iso: 200,
        process: .c41, isMonochrome: false, isFree: false,
        contrast: 0.80, saturation: 0.78,
        lift: SIMD3(0.030, 0.022, 0.030),
        gain: SIMD3(0.96, 0.97, 0.92),
        fade: 0.10,
        shadowTint: SIMD3(1.02, 0.98, 1.06),
        highlightTint: SIMD3(1.05, 1.02, 0.88),
        tintStrength: 0.55,
        grainIntensity: 0.55, grainSize: 2.8,
        halationThreshold: 0.88, halationRadius: 8,
        halationTint: SIMD3(1.0, 0.70, 0.45), bloomIntensity: 0.08,
        vignetteIntensity: 0.26,
        group: .expired, listPrice: usd(99), processCode: "C-41",
        tagline: "WARM HAZE · SHIFTED RED", swatchHex: 0xC99A2E, frames: 24
    )

    static let expiredFuji = FilmProfile(
        id: "expiredFuji", displayName: "Expired Fuji", iso: 400,
        process: .c41, isMonochrome: false, isFree: false,
        contrast: 0.84, saturation: 0.74,
        lift: SIMD3(0.018, 0.030, 0.028),
        gain: SIMD3(0.95, 0.99, 0.97),
        fade: 0.09,
        shadowTint: SIMD3(0.96, 1.04, 1.04),
        highlightTint: SIMD3(0.98, 1.03, 0.96),
        tintStrength: 0.55,
        grainIntensity: 0.50, grainSize: 2.6,
        halationThreshold: 0.88, halationRadius: 8,
        halationTint: SIMD3(1.0, 0.70, 0.55), bloomIntensity: 0.08,
        vignetteIntensity: 0.24,
        group: .expired, listPrice: usd(99), processCode: "C-41",
        tagline: "FADED CYAN · GREEN CAST", swatchHex: 0x6FA58B, frames: 24
    )

    // MARK: - Slide

    static let velvia50 = FilmProfile(
        id: "velvia50", displayName: "Velvia 50", iso: 50,
        process: .e6, isMonochrome: false, isFree: false,
        contrast: 1.35, saturation: 1.40,
        lift: SIMD3(-0.010, -0.008, 0.000),
        gain: SIMD3(1.010, 1.000, 1.020),
        fade: 0.0,
        shadowTint: SIMD3(0.98, 0.98, 1.04),
        highlightTint: SIMD3(1.03, 1.00, 0.98),
        tintStrength: 0.30,
        grainIntensity: 0.08, grainSize: 0.9,
        halationThreshold: 0.93, halationRadius: 5,
        halationTint: SIMD3(1.0, 0.50, 0.40), bloomIntensity: 0.04,
        vignetteIntensity: 0.20,
        group: .slide, listPrice: usd(149), processCode: "E-6",
        tagline: "HYPER SATURATED · DEEP CONTRAST", swatchHex: 0x2E7D32, frames: 36
    )

    static let provia100 = FilmProfile(
        id: "provia100", displayName: "Provia 100F", iso: 100,
        process: .e6, isMonochrome: false, isFree: false,
        contrast: 1.15, saturation: 1.12,
        lift: SIMD3(0.000, 0.000, 0.004),
        gain: SIMD3(1.000, 1.000, 1.010),
        fade: 0.0,
        shadowTint: SIMD3(0.98, 1.00, 1.03),
        highlightTint: SIMD3(1.01, 1.00, 0.99),
        tintStrength: 0.20,
        grainIntensity: 0.10, grainSize: 0.9,
        halationThreshold: 0.92, halationRadius: 5,
        halationTint: SIMD3(1.0, 0.55, 0.45), bloomIntensity: 0.04,
        vignetteIntensity: 0.12,
        group: .slide, listPrice: usd(149), processCode: "E-6",
        tagline: "CLEAN SLIDE · TRUE COLOUR", swatchHex: 0x4FA3C7, frames: 36
    )
}
