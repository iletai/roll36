import SwiftUI

/// One roll in the Darkroom list (design/02-darkroom.png). The layout follows the roll state.
/// Chemistry labels (temperature, tank, stage) are decorative (DECISIONS D7).
struct RollCard: View {
    let roll: Roll
    let index: Int
    let now: Date
    let developAction: DevelopingTicker.DevelopAction
    let onDevelop: () -> Void
    let onOpen: () -> Void

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private var state: RollState { roll.state(now: now) }
    private var isDeveloped: Bool { state == .developed }
    private var profile: FilmProfile? { FilmCatalog.profile(id: roll.stockID) }

    var body: some View {
        HStack(spacing: 0) {
            Rectangle().fill(accent).frame(width: 3)
            VStack(alignment: .leading, spacing: 12) {
                header
                ProgressBar(progress: progress, tint: accent)
                Rectangle().fill(Theme.line).frame(height: Theme.lineWidth)
                footer
            }
            .padding(14)
        }
        .background(Theme.card)
        .clipShape(RoundedRectangle(cornerRadius: Theme.cardRadius))
        .overlay(RoundedRectangle(cornerRadius: Theme.cardRadius).strokeBorder(Theme.line, lineWidth: Theme.lineWidth))
        // Cross-fade when the roll flips to developed (PLAN §6.4); skipped with Reduce Motion.
        .animation(reduceMotion ? nil : .easeInOut(duration: 0.4), value: isDeveloped)
        .onChange(of: isDeveloped) { wasDeveloped, nowDeveloped in
            if nowDeveloped, !wasDeveloped { Haptics.developed() }
        }
    }

    // MARK: - Pieces

    private var accent: Color {
        switch state {
        case .developing: Theme.amber
        case .developed: Theme.green
        case .active, .exposed: Theme.muted
        }
    }

    private var progress: Double {
        switch state {
        case let .developing(progress, _): progress
        case .developed: 1
        case .exposed: 0
        case .active: Double(roll.shots.count) / Double(max(roll.capacity, 1))
        }
    }

    private var header: some View {
        HStack(alignment: .top, spacing: 8) {
            VStack(alignment: .leading, spacing: 6) {
                HStack(spacing: 8) {
                    Text(verbatim: title).monoDisplay(size: 20).lineLimit(1).minimumScaleFactor(0.5)
                    if let profile {
                        Text("ISO \(profile.iso)").monoLabel(size: 10, color: Theme.text)
                            .padding(.horizontal, 6).padding(.vertical, 3)
                            .monoBox(fill: Theme.bg)
                    }
                }
                subtitle
            }
            Spacer(minLength: 4)
            status
        }
    }

    private var title: String {
        roll.isImportRoll ? String(localized: "Darkroom imports") : (profile?.displayName ?? roll.stockID)
    }

    @ViewBuilder private var subtitle: some View {
        if roll.isImportRoll {
            Text("\(roll.shots.count) frames").monoLabel(size: 11)
        } else {
            Text("\(roll.capacity) EXP · \(profile?.processCode ?? "")").monoLabel(size: 11)
        }
    }

    @ViewBuilder private var status: some View {
        switch state {
        case let .developing(progress, _):
            VStack(alignment: .trailing, spacing: 6) {
                Text("Developing · \(Int(progress * 100))%").monoLabel(size: 12, color: Theme.amber)
                Text("Stage \(DevelopingTicker.stage(progress: progress)) of \(DevelopingTicker.stageCount)")
                    .monoLabel(size: 11)
            }
        case .developed:
            VStack(alignment: .trailing, spacing: 6) {
                HStack(spacing: 4) {
                    Image(systemName: "checkmark.circle")
                    Text("Ready")
                }
                .monoLabel(size: 12, color: Theme.green)
                .padding(.horizontal, 8).padding(.vertical, 4)
                .monoBox(fill: Theme.bg)
                .overlay(RoundedRectangle(cornerRadius: Theme.boxRadius).strokeBorder(Theme.green, lineWidth: Theme.lineWidth))
                Text("100% complete").monoLabel(size: 11)
            }
        case .exposed:
            Text("Exposed").monoLabel(size: 12, color: Theme.text)
        case .active:
            Text("Shooting").monoLabel(size: 12, color: Theme.text)
        }
    }

    @ViewBuilder private var footer: some View {
        HStack {
            switch state {
            case let .developing(_, readyAt):
                Text("Temp 38.0°C · Tank \(DevelopingTicker.tankID(index: index))").monoLabel(size: 11)
                Spacer(minLength: 4)
                Text("Remaining \(DevelopingTicker.remainingText(until: readyAt, now: now))")
                    .monoLabel(size: 12, color: Theme.amber)
            case .developed:
                Text("\(roll.shots.count) contacts").monoLabel(size: 11)
                Spacer(minLength: 4)
                cardButton("View contact sheet", systemImage: "arrow.right", action: onOpen)
            case .exposed:
                switch developAction {
                case .develop: Text("\(roll.shots.count) frames exposed").monoLabel(size: 11)
                case .waitForPrevious: Text("Waiting for previous roll").monoLabel(size: 11, color: Theme.amber)
                }
                Spacer(minLength: 4)
                cardButton("Develop", systemImage: "flask", action: onDevelop)
            case let .active(remaining):
                Text("Shooting · \(remaining) left").monoLabel(size: 11)
                Spacer(minLength: 0)
            }
        }
    }

    private func cardButton(_ title: LocalizedStringKey, systemImage: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 6) {
                Text(title)
                Image(systemName: systemImage)
            }
            .monoLabel(size: 12, color: Theme.text)
            .padding(.horizontal, 12).padding(.vertical, 8)
            .overlay(RoundedRectangle(cornerRadius: Theme.boxRadius).strokeBorder(Theme.muted, lineWidth: Theme.lineWidth))
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}
