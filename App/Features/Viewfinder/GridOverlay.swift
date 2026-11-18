import SwiftUI

/// Rule-of-thirds lines over the preview; shown when the "Framing Grid" setting (`camera_show_grid`) is on. Decorative: no hit testing, hidden from VoiceOver.
struct GridOverlay: View {
    var body: some View {
        ThirdsLines()
            .stroke(Theme.text.opacity(0.35), lineWidth: Theme.lineWidth)
            .allowsHitTesting(false)
            .accessibilityHidden(true)
    }
}

private nonisolated struct ThirdsLines: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        for step in 1 ... 2 {
            let x = rect.minX + rect.width * CGFloat(step) / 3
            let y = rect.minY + rect.height * CGFloat(step) / 3
            path.move(to: CGPoint(x: x, y: rect.minY))
            path.addLine(to: CGPoint(x: x, y: rect.maxY))
            path.move(to: CGPoint(x: rect.minX, y: y))
            path.addLine(to: CGPoint(x: rect.maxX, y: y))
        }
        return path
    }
}
