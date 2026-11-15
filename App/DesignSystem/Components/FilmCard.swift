import SwiftUI

enum FilmCardState {
    case owned
    case locked(price: String)
    case loaded
}

struct FilmCard: View {
    let title: String
    let processCode: String
    let iso: Int
    let frames: Int
    let tagline: String
    let swatch: Color
    let state: FilmCardState
    /// Text colour on the swatch panel; pass `Theme.text` for dark swatches.
    var onSwatch: Color = Theme.bg

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            swatchPanel
            VStack(alignment: .leading, spacing: 4) {
                Text(verbatim: title).monoLabel(size: 14, color: Theme.text)
                Text(verbatim: tagline).monoLabel(size: 10).lineLimit(2, reservesSpace: true)
            }
            Rectangle().fill(Theme.line).frame(height: Theme.lineWidth)
            footer
        }
        .padding(12)
        .background(Theme.card, in: RoundedRectangle(cornerRadius: Theme.cardRadius))
        .overlay(RoundedRectangle(cornerRadius: Theme.cardRadius).strokeBorder(Theme.line, lineWidth: Theme.lineWidth))
        .accessibilityElement(children: .combine)
    }

    private var swatchPanel: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                Text(verbatim: processCode)
                    .monoLabel(size: 10, color: Theme.bg)
                    .padding(.horizontal, 4)
                    .background(Theme.text, in: RoundedRectangle(cornerRadius: 2))
                Spacer()
                Text("ISO \(iso)").monoLabel(size: 11, color: onSwatch)
            }
            HStack(alignment: .lastTextBaseline) {
                Text(verbatim: title).monoDisplay(size: 15, color: onSwatch).lineLimit(1).minimumScaleFactor(0.6)
                Spacer(minLength: 4)
                Text("\(frames) EXP").monoLabel(size: 9, color: onSwatch)
            }
        }
        .padding(10)
        .background(swatch, in: RoundedRectangle(cornerRadius: Theme.boxRadius))
    }

    @ViewBuilder private var footer: some View {
        HStack {
            switch state {
            case .owned:
                ownedBadge
                Spacer()
            case .loaded:
                ownedBadge
                Spacer()
                Text("Loaded").monoLabel(size: 10, color: Theme.amber)
            case let .locked(price):
                Text("\(frames) EXP").monoLabel(size: 10)
                Spacer()
                Text(verbatim: price)
                    .monoDisplay(size: 14, color: Theme.amber)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(Theme.surface, in: RoundedRectangle(cornerRadius: Theme.boxRadius))
            }
        }
    }

    private var ownedBadge: some View {
        HStack(spacing: 4) {
            Circle().fill(Theme.green).frame(width: 5, height: 5)
            Text("Owned").monoLabel(size: 10, color: Theme.green)
        }
        .padding(.horizontal, 6)
        .padding(.vertical, 3)
        .overlay(RoundedRectangle(cornerRadius: Theme.boxRadius).strokeBorder(Theme.green, lineWidth: Theme.lineWidth))
    }
}

#Preview {
    LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
        FilmCard(
            title: "Portra 400", processCode: "C-41", iso: 400, frames: 36,
            tagline: "Fine grain · neutral skin", swatch: Color(hex: 0xD97B4A), state: .loaded
        )
        FilmCard(
            title: "Fuji Pro 400H", processCode: "C-41", iso: 400, frames: 36,
            tagline: "Soft highlight · cool teal", swatch: Color(hex: 0x5B918A), state: .locked(price: "$0.99")
        )
    }
    .padding()
    .background(Theme.bg)
}
