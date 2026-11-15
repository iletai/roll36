import SwiftUI

struct ShutterButton: View {
    var isEnabled = true
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            ZStack {
                Circle().strokeBorder(Theme.text, lineWidth: 3)
                Circle().strokeBorder(Theme.card, lineWidth: 5).padding(6)
                Circle().fill(Theme.muted).frame(width: 14, height: 14)
            }
            .frame(width: 76, height: 76)
            .opacity(isEnabled ? 1 : 0.35)
            .contentShape(Circle())
        }
        .buttonStyle(.plain)
        .disabled(!isEnabled)
        .accessibilityLabel(Text("Take photo"))
    }
}

#Preview {
    HStack(spacing: 24) {
        ShutterButton {}
        ShutterButton(isEnabled: false) {}
    }
    .padding()
    .background(Theme.bg)
}
