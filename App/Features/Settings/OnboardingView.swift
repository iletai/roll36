import SwiftUI

/// Shown once, before the tabs; `onFinish` marks it as seen (PLAN 13.8). One screen, no carousel, no skip.
struct OnboardingView: View {
    let onFinish: () -> Void

    private let lines: [LocalizedStringKey] = [
        "Shoot 36 frames.",
        "Develop, then wait.",
        "Frames are lost if you delete the app."
    ]

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Theme.spacingL) {
                Text("ROLL 36")
                    .monoDisplay(size: 34, color: Theme.amber)
                    .accessibilityAddTraits(.isHeader)
                    .padding(.bottom, Theme.spacingS)
                ForEach(Array(lines.enumerated()), id: \.offset) { index, line in
                    row(index: index + 1, line: line)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, Theme.spacingL)
            .padding(.top, 72)
        }
        .scrollBounceBehavior(.basedOnSize)
        .background(Theme.bg)
        .safeAreaInset(edge: .bottom, spacing: 0) { footer }
    }

    private func row(index: Int, line: LocalizedStringKey) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: Theme.spacingM) {
            Text(String(format: "%02d", index))
                .monoLabel(size: 12, color: Theme.amber)
                .accessibilityHidden(true)
            Text(line).bodyText().font(.title3)
        }
        .padding(Theme.spacingM)
        .frame(maxWidth: .infinity, alignment: .leading)
        .monoBox()
        .accessibilityElement(children: .combine)
    }

    private var footer: some View {
        VStack(spacing: Theme.spacingM) {
            Text("Developing takes about an hour and cannot be skipped.")
                .monoLabel(size: 10)
                .multilineTextAlignment(.center)
            PrimaryButton(title: "Start", action: onFinish)
                .accessibilityLabel("Start")
        }
        .padding(.horizontal, Theme.spacingL)
        .padding(.vertical, Theme.spacingM)
        .background(Theme.bg)
    }
}

#Preview {
    OnboardingView {}
}
