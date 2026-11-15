import SwiftUI

/// Top of the view tree. A plain `switch` (not TabView) so the camera tab never gets a system bar.
/// Feature agents replace the `cameraTab` / `darkroomTab` / `libraryTab` builders below.
struct RootView: View {
    @State private var selection: AppTab = .camera

    var body: some View {
        VStack(spacing: 0) {
            Group {
                switch selection {
                case .camera: cameraTab
                case .darkroom: darkroomTab
                case .library: libraryTab
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            AppTabBar(selection: $selection)
        }
        .background(Theme.bg.ignoresSafeArea())
        .preferredColorScheme(.dark)
    }

    // MARK: - Tabs (placeholders)

    @ViewBuilder private var cameraTab: some View {
        VStack {
            RollCounter(taken: 12, capacity: 36)
            Spacer()
            ShutterButton { Haptics.shutter() }
                .padding(.bottom, Theme.spacingL)
        }
        .padding(.top, Theme.spacingM)
    }

    @ViewBuilder private var darkroomTab: some View {
        VStack(alignment: .leading, spacing: Theme.spacingM) {
            Text("Darkroom").monoDisplay(size: 28)
            Text("1 roll in progress").monoLabel()
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Text(verbatim: "Portra 400").monoDisplay(size: 20)
                    Spacer()
                    Text("Developing · 42%").monoLabel(color: Theme.amber)
                }
                ProgressBar(progress: 0.42)
                HStack {
                    Text("Tank B-2").monoLabel()
                    Spacer()
                    Text("Remaining 04:12").monoLabel(color: Theme.amber)
                }
            }
            .padding(Theme.spacingM)
            .background(Theme.card, in: RoundedRectangle(cornerRadius: Theme.cardRadius))
            .overlay(RoundedRectangle(cornerRadius: Theme.cardRadius).strokeBorder(Theme.line, lineWidth: Theme.lineWidth))
            Spacer()
        }
        .padding(Theme.spacingM)
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    @ViewBuilder private var libraryTab: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Theme.spacingM) {
                Text("Film Library").monoDisplay(size: 22)
                LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
                    FilmCard(
                        title: "Portra 400", processCode: "C-41", iso: 400, frames: 36,
                        tagline: "Fine grain · neutral skin", swatch: Color(hex: 0xD97B4A), state: .loaded
                    )
                    FilmCard(
                        title: "Pro 400H", processCode: "C-41", iso: 400, frames: 36,
                        tagline: "Soft highlight · cool teal", swatch: Color(hex: 0x5B918A),
                        state: .locked(price: "$0.99")
                    )
                    FilmCard(
                        title: "Tri-X 400", processCode: "D-76", iso: 400, frames: 36,
                        tagline: "Heavy silver · punchy", swatch: Color(hex: 0x2E2E30), state: .owned,
                        onSwatch: Theme.text
                    )
                    FilmCard(
                        title: "Ektar 100", processCode: "C-41", iso: 100, frames: 36,
                        tagline: "Ultra vivid · micro grain", swatch: Color(hex: 0xB93A22),
                        state: .locked(price: "$0.99"), onSwatch: Theme.text
                    )
                }
            }
            .padding(Theme.spacingM)
        }
    }
}

#Preview {
    RootView()
}
