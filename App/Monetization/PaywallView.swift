import SwiftUI

/// Sheet that sells the one-time full unlock (PLAN 13.6). `highlightStockID` names the stock that triggered it.
struct PaywallView: View {
    var highlightStockID: String?
    @Environment(AppEnvironment.self) private var env
    @Environment(\.dismiss) private var dismiss
    @State private var flow = PurchaseFlow()

    private static let termsURL = URL(string: "https://apps-site-six.vercel.app/apps/roll36/terms")
    private static let privacyURL = URL(string: "https://apps-site-six.vercel.app/apps/roll36/privacy")

    /// A stock worth offering on its own: known, paid and not yet owned.
    private var highlighted: FilmProfile? {
        guard let id = highlightStockID, let profile = FilmCatalog.profile(id: id),
              !env.entitlements.isUnlocked(stockID: id) else { return nil }
        return profile
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Theme.spacingL) {
                closeButton
                VStack(alignment: .leading, spacing: Theme.spacingS) {
                    Text("Every film stock. Clean frames.").monoDisplay(size: 24)
                    if let highlighted {
                        Text("Includes \(highlighted.displayName) and every other stock.")
                            .monoLabel(size: 11, color: Theme.amber)
                    }
                }
                VStack(alignment: .leading, spacing: Theme.spacingM) {
                    bullet("\(FilmCatalog.all.count) film stocks, from Portra to Velvia")
                    bullet("Unlimited imports and parallel developing")
                    bullet("Frames without the ROLL 36 watermark")
                }
                purchaseButtons
                if let message = flow.message {
                    Text(verbatim: message).monoLabel(size: 10)
                }
                Text("One-time purchase. No subscription.").monoLabel(size: 10)
                legalLinks
            }
            .padding(Theme.spacingM)
        }
        .disabled(flow.isBusy)
        .background(Theme.bg.ignoresSafeArea())
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("paywall")
        .task { await env.purchases.loadProducts() }
        .onChange(of: env.entitlements.hasFullUnlock) { _, unlocked in
            if unlocked { dismiss() }
        }
    }

    private var closeButton: some View {
        HStack {
            Spacer()
            Button { dismiss() } label: {
                Image(systemName: "xmark")
                    .foregroundStyle(Theme.text)
                    .frame(width: 44, height: 44)
                    .monoBox(fill: Theme.card)
            }
            .accessibilityLabel("Close")
            .accessibilityIdentifier("paywall.close")
        }
    }

    private func bullet(_ text: LocalizedStringKey) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: 12) {
            Circle().fill(Theme.amber).frame(width: 6, height: 6)
            Text(text).bodyText()
        }
    }

    @ViewBuilder private var purchaseButtons: some View {
        VStack(spacing: Theme.spacingS) {
            PrimaryButton(title: "Unlock all \(FilmCatalog.all.count) stocks — \(env.purchases.fullUnlockPrice)") {
                Task { _ = await flow.purchase { try await env.purchases.purchaseFullUnlock() } }
            }
            .accessibilityIdentifier("paywall.buy")
            if let highlighted {
                PrimaryButton(
                    title: "Buy \(highlighted.displayName) only — \(env.purchases.price(forStock: highlighted.id))",
                    style: .secondary
                ) {
                    Task {
                        if await flow.purchase({ try await env.purchases.purchase(stockID: highlighted.id) }) { dismiss() }
                    }
                }
                .accessibilityIdentifier("paywall.buyStock")
            }
            Button {
                Task { await flow.restore { try await env.purchases.restore() } }
            } label: {
                Text("Restore purchases").monoLabel(size: 11, color: Theme.text).frame(height: 44)
            }
        }
    }

    private var legalLinks: some View {
        HStack(spacing: Theme.spacingL) {
            if let url = Self.termsURL { Link(destination: url) { Text("Terms").monoLabel(size: 10) } }
            if let url = Self.privacyURL { Link(destination: url) { Text("Privacy").monoLabel(size: 10) } }
        }
    }
}

#Preview {
    PaywallView(highlightStockID: "trix400").environment(AppEnvironment.preview())
}
