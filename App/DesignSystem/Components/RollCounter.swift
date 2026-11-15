import SwiftUI

/// "EXP 12/36" box. The value changes instantly; nothing animates (PLAN 6.4).
struct RollCounter: View {
    let taken: Int
    let capacity: Int

    var body: some View {
        HStack(spacing: Theme.spacingS) {
            Text("Exp").monoLabel()
            Text(verbatim: "\(taken)/\(capacity)").monoDisplay(size: 28)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
        .monoBox(fill: Theme.surface)
        .transaction { $0.animation = nil }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(Text("Frame \(taken) of \(capacity)"))
    }
}

#Preview {
    RollCounter(taken: 12, capacity: 36)
        .padding()
        .background(Theme.bg)
}
