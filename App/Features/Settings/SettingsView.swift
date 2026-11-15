import SwiftUI
import UIKit

/// Presented as a sheet from the Viewfinder top bar (PLAN 13.7).
struct SettingsView: View {
    @Environment(AppEnvironment.self) private var env
    @Environment(\.dismiss) private var dismiss
    @Environment(\.openURL) private var openURL
    @State private var model = SettingsModel()
    @State private var restore = PurchaseFlow()
    @State private var confirmsDelete = false

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: Theme.spacingL) {
                    purchases
                    language
                    legal
                    about
                    data
                }
                .padding(Theme.spacingM)
            }
            .background(Theme.bg)
            .navigationTitle("Settings")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                        .accessibilityLabel("Done")
                }
            }
        }
        .preferredColorScheme(.dark)
        .tint(Theme.amber)
    }

    private var purchases: some View {
        section("Purchases") {
            row(SettingsModel.ownedText(for: env.entitlements), color: Theme.text)
            divider
            Button {
                Task { await restore.restore { try await env.purchases.restore() } }
            } label: {
                HStack {
                    Text("Restore purchases").monoLabel(size: 12, color: Theme.text)
                    Spacer()
                    if restore.isBusy { ProgressView() }
                }
                .padding(Theme.spacingM)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .disabled(restore.isBusy)
            .accessibilityLabel("Restore purchases")
            if let message = restore.message {
                divider
                row(message)
            }
        }
    }

    private var language: some View {
        section("Language") {
            Button {
                if let url = URL(string: UIApplication.openSettingsURLString) { openURL(url) }
            } label: {
                VStack(alignment: .leading, spacing: 6) {
                    HStack {
                        Text("Open iOS Settings").monoLabel(size: 12, color: Theme.text)
                        Spacer()
                        Image(systemName: "arrow.up.right").foregroundStyle(Theme.muted)
                    }
                    Text("The language is chosen per app in iOS Settings.")
                        .bodyText(color: Theme.muted).font(.footnote)
                }
                .padding(Theme.spacingM)
                .frame(maxWidth: .infinity, alignment: .leading)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Open iOS Settings")
            .accessibilityHint("The language is chosen per app in iOS Settings.")
        }
    }

    private var legal: some View {
        section("Legal") {
            if let terms = LegalLinks.terms { linkRow("Terms of Use", terms) }
            divider
            if let privacy = LegalLinks.privacy { linkRow("Privacy Policy", privacy) }
        }
    }

    private var about: some View {
        section("About") {
            row("Version \(SettingsModel.versionString())", color: Theme.text)
            // Prod builds hide the environment name.
            if AppConfiguration.environment != .prod {
                divider
                row("Environment \(AppConfiguration.environment.rawValue)")
            }
        }
    }

    private var data: some View {
        section("Data") {
            Button(role: .destructive) { confirmsDelete = true } label: {
                HStack {
                    Text("Delete all data").monoLabel(size: 12, color: Theme.red)
                    Spacer()
                    if model.isDeleting { ProgressView() }
                }
                .padding(Theme.spacingM)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .disabled(model.isDeleting)
            .accessibilityLabel("Delete all data")
            .confirmationDialog("Delete all data?", isPresented: $confirmsDelete, titleVisibility: .visible) {
                Button("Delete all data", role: .destructive) {
                    Task { await model.deleteAll(from: env.repository) }
                }
                Button("Cancel", role: .cancel) {}
            } message: {
                Text("Every roll and photo on this device is removed. This cannot be undone.")
            }
            if let message = model.deleteMessage {
                divider
                row(message)
            }
        }
    }

    // MARK: - Building blocks

    private func section(_ title: LocalizedStringKey, @ViewBuilder content: () -> some View) -> some View {
        VStack(alignment: .leading, spacing: Theme.spacingS) {
            Text(title).monoLabel(size: 10).accessibilityAddTraits(.isHeader)
            VStack(spacing: 0, content: content)
                .frame(maxWidth: .infinity, alignment: .leading)
                .monoBox(fill: Theme.card, radius: Theme.cardRadius)
        }
    }

    private func row(_ text: String, color: Color = Theme.muted) -> some View {
        Text(text).bodyText(color: color).font(.subheadline)
            .padding(Theme.spacingM)
            .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func linkRow(_ title: LocalizedStringKey, _ url: URL) -> some View {
        Link(destination: url) {
            HStack {
                Text(title).monoLabel(size: 12, color: Theme.text)
                Spacer()
                Image(systemName: "arrow.up.right").foregroundStyle(Theme.muted)
            }
            .padding(Theme.spacingM)
            .contentShape(Rectangle())
        }
    }

    private var divider: some View {
        Theme.line.frame(height: Theme.lineWidth)
    }
}

#Preview {
    SettingsView().environment(AppEnvironment.preview())
}
