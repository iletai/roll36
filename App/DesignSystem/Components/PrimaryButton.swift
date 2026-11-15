import SwiftUI

struct PrimaryButton: View {
    enum Style { case primary, secondary }

    let title: LocalizedStringKey
    var systemImage: String?
    var style: Style = .primary
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: Theme.spacingS) {
                if let systemImage { Image(systemName: systemImage) }
                Text(title).monoLabel(size: 14, color: foreground)
            }
            .foregroundStyle(foreground)
            .frame(maxWidth: .infinity)
            .frame(height: Theme.buttonHeight)
            .background(style == .primary ? Theme.amber : .clear, in: shape)
            .overlay { if style == .secondary { shape.strokeBorder(Theme.line, lineWidth: Theme.lineWidth) } }
            .contentShape(shape)
        }
        .buttonStyle(.plain)
    }

    private var shape: RoundedRectangle { RoundedRectangle(cornerRadius: Theme.buttonRadius) }
    private var foreground: Color { style == .primary ? Theme.bg : Theme.text }
}

#Preview {
    VStack(spacing: 12) {
        PrimaryButton(title: "Develop roll", systemImage: "flask") {}
        PrimaryButton(title: "Restore purchases", style: .secondary) {}
    }
    .padding()
    .background(Theme.bg)
}
