import SwiftUI

extension View {
    /// Small technical label: monospaced, uppercase, 0.12em tracking, regular weight.
    func monoLabel(size: CGFloat = 11, color: Color = Theme.muted) -> some View {
        modifier(MonoStyle(textStyle: .caption, size: size, weight: .regular, color: color))
    }

    /// Big numbers and titles: monospaced, medium weight at most.
    func monoDisplay(size: CGFloat = 28, color: Color = Theme.text) -> some View {
        modifier(MonoStyle(textStyle: .title, size: size, weight: .medium, color: color))
    }

    /// Body copy: system font, regular weight.
    func bodyText(color: Color = Theme.text) -> some View {
        font(.body.weight(.regular)).foregroundStyle(color)
    }
}

/// `size` is the base point size; `@ScaledMetric` scales it with Dynamic Type relative to `textStyle`.
private struct MonoStyle: ViewModifier {
    let weight: Font.Weight
    let color: Color
    @ScaledMetric private var scaled: CGFloat

    init(textStyle: Font.TextStyle, size: CGFloat, weight: Font.Weight, color: Color) {
        self.weight = weight
        self.color = color
        _scaled = ScaledMetric(wrappedValue: size, relativeTo: textStyle)
    }

    func body(content: Content) -> some View {
        content
            .font(.system(size: scaled, weight: weight, design: .monospaced))
            .tracking(scaled * 0.12)
            .textCase(.uppercase)
            .foregroundStyle(color)
    }
}
