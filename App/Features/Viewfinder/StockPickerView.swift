import SwiftUI

/// Sheet listing every stock; picking one sets the stock of the next roll, locked ones open the paywall.
struct StockPickerView: View {
    let model: ViewfinderViewModel
    let selectedID: String

    var body: some View {
        ScrollView {
            VStack(spacing: 0) {
                Text("Film stock").monoDisplay(size: 20)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(Theme.spacingM)
                ForEach(FilmCatalog.all) { profile in
                    row(profile)
                    Divider().overlay(Theme.line)
                }
            }
        }
        .background(Theme.bg)
        .presentationDetents([.medium, .large])
        .presentationBackground(Theme.bg)
    }

    private func row(_ profile: FilmProfile) -> some View {
        let unlocked = model.isUnlocked(profile)
        return Button { model.choose(profile) } label: {
            HStack(spacing: Theme.spacingM) {
                Text(verbatim: "\(profile.iso)")
                    .monoLabel(size: 12, color: Theme.bg)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 3)
                    .background(Theme.amber, in: RoundedRectangle(cornerRadius: Theme.boxRadius))
                VStack(alignment: .leading, spacing: 2) {
                    Text(verbatim: profile.displayName).monoLabel(size: 13, color: Theme.text)
                    Text(verbatim: "\(profile.frames) EXP · \(profile.processCode)").monoLabel(size: 10)
                }
                Spacer()
                if !unlocked {
                    Image(systemName: "lock.fill").foregroundStyle(Theme.muted)
                } else if profile.id == selectedID {
                    Image(systemName: "checkmark").foregroundStyle(Theme.amber)
                }
            }
            .padding(.horizontal, Theme.spacingM)
            .padding(.vertical, 12)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(Text(verbatim: profile.displayName))
        .accessibilityValue(unlocked ? Text(profile.id == selectedID ? "Selected" : "") : Text("Locked"))
    }
}
