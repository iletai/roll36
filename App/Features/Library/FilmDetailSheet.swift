import SwiftUI

/// One stock: specs and purchase options. Locked stocks are bought from here, never straight from the grid (PLAN 13.4).
struct FilmDetailSheet: View {
    let profile: FilmProfile
    @Environment(AppEnvironment.self) private var env
    @Environment(\.dismiss) private var dismiss
    @State private var flow = PurchaseFlow()

    private var isUnlocked: Bool { env.entitlements.isUnlocked(stockID: profile.id) }

    var body: some View {
        VStack(alignment: .leading, spacing: Theme.spacingM) {
            VStack(alignment: .leading, spacing: 6) {
                Text(verbatim: profile.displayName).monoDisplay(size: 24)
                Text(verbatim: "\(profile.processCode) · ISO \(profile.iso) · \(profile.frames) EXP")
                    .monoLabel(size: 11, color: Theme.amber)
                Text(verbatim: profile.tagline).monoLabel(size: 10)
            }
            VStack(spacing: 0) {
                row("Contrast", profile.contrast.formatted(.number.precision(.fractionLength(2))))
                row("Saturation", profile.saturation.formatted(.number.precision(.fractionLength(2))))
                row("Grain", profile.grainIntensity.formatted(.number.precision(.fractionLength(2))))
                row("Halation", "\(Int(profile.halationRadius)) px")
            }
            .monoBox(fill: Theme.card, radius: Theme.cardRadius)

            Spacer(minLength: 0)

            if let message = flow.message {
                Text(verbatim: message).monoLabel(size: 10, color: Theme.muted)
            }
            if !isUnlocked {
                PrimaryButton(title: "Buy \(profile.displayName) — \(env.purchases.price(forStock: profile.id))") {
                    Task { await run { try await env.purchases.purchase(stockID: profile.id) } }
                }
                .accessibilityIdentifier("film.detail.buy")
                if !env.entitlements.hasFullUnlock {
                    PrimaryButton(
                        title: "Unlock all \(FilmCatalog.all.count) stocks — \(env.purchases.fullUnlockPrice)",
                        style: .secondary
                    ) {
                        Task { await run { try await env.purchases.purchaseFullUnlock() } }
                    }
                    .accessibilityIdentifier("film.detail.unlockAll")
                }
            }
        }
        .disabled(flow.isBusy)
        .padding(Theme.spacingM)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .background(Theme.bg.ignoresSafeArea())
        .presentationDetents([.medium])
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("film.detail")
        .task { await env.purchases.loadProducts() }
    }

    private func row(_ label: LocalizedStringKey, _ value: String) -> some View {
        HStack {
            Text(label).monoLabel(size: 11)
            Spacer()
            Text(verbatim: value).monoLabel(size: 11, color: Theme.text)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
    }

    private func run(_ operation: () async throws -> PurchaseOutcome) async {
        if await flow.purchase(operation) { dismiss() }
    }
}

#Preview {
    FilmDetailSheet(profile: FilmCatalog.all[5]).environment(AppEnvironment.preview())
}
