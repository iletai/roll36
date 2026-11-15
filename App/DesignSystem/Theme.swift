import SwiftUI

extension Color {
    /// Builds an sRGB colour from a 0xRRGGBB literal.
    init(hex: UInt32) {
        self.init(
            .sRGB,
            red: Double((hex >> 16) & 0xFF) / 255,
            green: Double((hex >> 8) & 0xFF) / 255,
            blue: Double(hex & 0xFF) / 255,
            opacity: 1
        )
    }
}

/// Design tokens from PLAN 6.1 / 6.3. Amber is the only accent colour.
enum Theme {
    static let bg = Color(hex: 0x0F0D0A)
    static let surface = Color(hex: 0x17140F)
    static let card = Color(hex: 0x221F1A)
    static let line = Color(hex: 0x332E25)
    static let text = Color(hex: 0xF4F1EA)
    static let muted = Color(hex: 0x9C948A)
    static let amber = Color(hex: 0xEF9F27)
    static let green = Color(hex: 0x7FB07A)
    static let red = Color(hex: 0xE0765F)

    static let cardRadius: CGFloat = 10
    static let buttonRadius: CGFloat = 9
    static let buttonHeight: CGFloat = 52
    static let boxRadius: CGFloat = 4
    static let lineWidth: CGFloat = 0.5

    static let spacingS: CGFloat = 8
    static let spacingM: CGFloat = 16
    static let spacingL: CGFloat = 24
}
