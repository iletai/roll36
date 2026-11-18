import SwiftUI

/// Film Library tab (PLAN 13.4): filter chips, 2-column stock grid, unlock-all CTA.
struct FilmLibraryView: View {
    @Environment(AppEnvironment.self) private var env
    @State private var filter = LibraryFilter.all
    @State private var detail: FilmProfile?
    @State private var showsPaywall = false
    @State private var flow = PurchaseFlow()

    private var model: LibraryModel {
        LibraryModel(
            entitlements: env.entitlements,
            selectedStockID: env.selectedStockID,
            stockPrice: { env.purchases.price(forStock: $0) }
        )
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Theme.spacingM) {
                header
                chips
                HStack {
                    Text("Emulation box / spec").monoLabel(size: 10)
                    Spacer()
                    Text("Format: 135 film").monoLabel(size: 10)
                }
                grid
            }
            .padding(.horizontal, Theme.spacingM)
        }
        .background(Theme.bg)
        .safeAreaInset(edge: .bottom, spacing: 0) { footer }
        .task { await env.purchases.loadProducts() }
        .sheet(item: $detail) { FilmDetailSheet(profile: $0) }
        .sheet(isPresented: $showsPaywall) { PaywallView() }
    }

    private var header: some View {
        VStack(spacing: 6) {
            Text("Film library").monoDisplay(size: 22)
            HStack(spacing: 6) {
                Circle().fill(Theme.amber).frame(width: 6, height: 6)
                Text("\(model.ownedCount) of \(FilmCatalog.all.count) owned").monoLabel(size: 11, color: Theme.amber)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.top, Theme.spacingM)
    }

    private var chips: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: Theme.spacingS) {
                ForEach(LibraryFilter.allCases, id: \.self) { item in
                    let isSelected = item == filter
                    Button { filter = item } label: {
                        Text(item.title)
                            .monoLabel(size: 11, color: isSelected ? Theme.bg : Theme.muted)
                            .padding(.horizontal, 12)
                            .frame(height: 36)
                            .background(isSelected ? Theme.amber : Theme.card, in: RoundedRectangle(cornerRadius: Theme.boxRadius))
                            .overlay(RoundedRectangle(cornerRadius: Theme.boxRadius).strokeBorder(Theme.line, lineWidth: Theme.lineWidth))
                    }
                    .buttonStyle(.plain)
                    .accessibilityAddTraits(isSelected ? .isSelected : [])
                }
            }
        }
    }

    private var grid: some View {
        LazyVGrid(columns: [GridItem(.flexible(), spacing: 12), GridItem(.flexible(), spacing: 12)], spacing: 12) {
            ForEach(model.profiles(for: filter)) { profile in
                Button { tap(profile) } label: {
                    FilmCard(
                        title: profile.displayName,
                        processCode: profile.processCode,
                        iso: profile.iso,
                        frames: profile.frames,
                        tagline: profile.tagline,
                        swatch: Color(hex: profile.swatchHex),
                        state: model.cardState(for: profile),
                        onSwatch: model.usesLightText(on: profile) ? Theme.text : Theme.bg
                    )
                }
                .buttonStyle(.plain)
                .accessibilityIdentifier("library.card.\(profile.id)")
            }
        }
    }

    private var footer: some View {
        VStack(spacing: Theme.spacingS) {
            if model.showsUnlockAll {
                PrimaryButton(
                    title: "Unlock all \(FilmCatalog.all.count) stocks — \(env.purchases.fullUnlockPrice)",
                    systemImage: "lock.open"
                ) {
                    showsPaywall = true
                }
                .accessibilityIdentifier("library.unlockAll")
            }
            if let message = flow.message {
                Text(verbatim: message).monoLabel(size: 10, color: Theme.muted)
            }
            Button {
                Task { await flow.restore { try await env.purchases.restore() } }
            } label: {
                Text("Restore purchases").monoLabel(size: 10)
            }
            .disabled(flow.isBusy)
        }
        .padding(Theme.spacingM)
        .frame(maxWidth: .infinity)
        .background(Theme.bg)
        .overlay(alignment: .top) { Rectangle().fill(Theme.line).frame(height: Theme.lineWidth) }
    }

    private func tap(_ profile: FilmProfile) {
        if env.entitlements.isUnlocked(stockID: profile.id) {
            Haptics.selection()
            env.selectedStockID = profile.id
        } else {
            detail = profile
        }
    }
}

#Preview {
    FilmLibraryView().environment(AppEnvironment.preview())
}
