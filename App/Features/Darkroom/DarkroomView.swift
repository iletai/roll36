import os
import SwiftUI

/// Darkroom tab (PLAN §13.2, design/02-darkroom.png). A `TimelineView` ticks once a second while the screen is visible
/// and re-reads the rolls, which also lets the repository stamp `developedAt` lazily (PLAN §10.2). No `Timer`.
/// There is no way to skip or speed up developing: it is a product decision (PLAN §10.4).
struct DarkroomView: View {
    @Environment(AppEnvironment.self) private var env
    @State private var openedRoll: Roll?
    @State private var showImport = false
    @State private var showPaywall = false

    var body: some View {
        NavigationStack {
            TimelineView(.periodic(from: .now, by: 1)) { context in
                content(now: context.date)
            }
            .background(Theme.bg)
            .toolbar(.hidden, for: .navigationBar)
            .navigationDestination(item: $openedRoll) { ContactSheetView(roll: $0) }
        }
        .fullScreenCover(isPresented: $showImport) { ImportView() }
        .sheet(isPresented: $showPaywall) { PaywallView() }
    }

    private func content(now: Date) -> some View {
        let rolls = (try? env.repository.rolls(now: now)) ?? []
        let imports = importRollWithFrames()
        let developingCount = rolls.count { if case .developing = $0.state(now: now) { true } else { false } }
        let recent = DevelopingTicker.recentFrames(from: rolls, now: now)
        let action = DevelopingTicker.developAction(
            otherRollDeveloping: developingCount > 0,
            canDevelopInParallel: env.entitlements.canDevelopInParallel
        )
        return ScrollView {
            VStack(alignment: .leading, spacing: Theme.spacingM) {
                header(developingCount: developingCount)
                if rolls.isEmpty, imports == nil {
                    emptyState
                }
                ForEach(Array(rolls.enumerated()), id: \.element.id) { index, roll in
                    RollCard(
                        roll: roll, index: index, now: now, developAction: action,
                        onDevelop: { develop(roll) }, onOpen: { openedRoll = roll }
                    )
                }
                if let imports {
                    RollCard(
                        roll: imports, index: rolls.count, now: now, developAction: action,
                        onDevelop: {}, onOpen: { openedRoll = imports }
                    )
                }
                if !recent.isEmpty { recentStrip(recent) }
            }
            .padding(.horizontal, Theme.spacingM)
            .padding(.bottom, Theme.spacingL)
        }
    }

    private func header(developingCount: Int) -> some View {
        HStack(alignment: .top) {
            VStack(alignment: .leading, spacing: 6) {
                Text("Darkroom").monoDisplay(size: 30)
                if developingCount == 1 {
                    Text("1 roll in progress").monoLabel(size: 13)
                } else {
                    Text("\(developingCount) rolls in progress").monoLabel(size: 13)
                }
            }
            Spacer()
            Button { showImport = true } label: {
                Image(systemName: "flask")
                    .font(.system(size: 22))
                    .foregroundStyle(Theme.amber)
                    .frame(width: 48, height: 48)
                    .monoBox(fill: Theme.card)
            }
            .buttonStyle(.plain)
            .accessibilityLabel(Text("Import photos"))
        }
        .padding(.top, Theme.spacingM)
    }

    private var emptyState: some View {
        VStack(spacing: 8) {
            Text("No rolls yet").monoLabel(size: 14, color: Theme.text)
            Text("Shoot a roll, then develop it here.").bodyText(color: Theme.muted)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 48)
    }

    private func recentStrip(_ shots: [Shot]) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Recently developed").monoLabel(size: 12, color: Theme.text)
                Text("[\(shots.count) frames]").monoLabel(size: 11, color: Theme.amber)
            }
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(alignment: .top, spacing: 12) {
                    ForEach(shots) { shot in
                        Button { openedRoll = shot.roll } label: {
                            VStack(spacing: 6) {
                                FrameThumbnail(shot: shot, imageStore: env.imageStore)
                                    .frame(width: 150, height: 200)
                                HStack {
                                    Text("#\(shot.index + 1)").monoLabel(size: 11, color: Theme.text)
                                    Spacer()
                                    Text(verbatim: FilmCatalog.profile(id: shot.roll?.stockID ?? "")?.displayName ?? "")
                                        .monoLabel(size: 10).lineLimit(1)
                                }
                            }
                            .frame(width: 150)
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
        }
        .padding(.top, Theme.spacingS)
    }

    // MARK: - Actions

    /// The import pseudo-roll only counts once it holds frames (it is created on first access).
    private func importRollWithFrames() -> Roll? {
        guard let roll = try? env.repository.importRoll(), !roll.shots.isEmpty else { return nil }
        return roll
    }

    private func develop(_ roll: Roll) {
        do {
            try env.repository.startDeveloping(roll, canDevelopInParallel: env.entitlements.canDevelopInParallel)
        } catch RollRepository.RollError.developingLimitReached {
            showPaywall = true
        } catch {
            Log.app.error("startDeveloping failed: \(error)")
        }
    }
}

#Preview {
    DarkroomView().environment(AppEnvironment.preview())
}

