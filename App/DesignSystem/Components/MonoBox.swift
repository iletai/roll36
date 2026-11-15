import SwiftUI

extension View {
    /// Bordered box with a 0.5pt `line` stroke and a small squared radius.
    func monoBox(fill: Color = Theme.surface, radius: CGFloat = Theme.boxRadius) -> some View {
        background(fill, in: RoundedRectangle(cornerRadius: radius))
            .overlay(RoundedRectangle(cornerRadius: radius).strokeBorder(Theme.line, lineWidth: Theme.lineWidth))
    }
}
