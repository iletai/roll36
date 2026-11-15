import SwiftUI

enum AppTab: CaseIterable {
    case camera, darkroom, library

    var title: LocalizedStringKey {
        switch self {
        case .camera: "Camera"
        case .darkroom: "Darkroom"
        case .library: "Library"
        }
    }

    var systemImage: String {
        switch self {
        case .camera: "camera"
        case .darkroom: "flask"
        case .library: "photo.stack"
        }
    }
}

struct AppTabBar: View {
    @Binding var selection: AppTab

    var body: some View {
        HStack(spacing: 0) {
            ForEach(AppTab.allCases, id: \.self) { tab in
                let isSelected = tab == selection
                Button {
                    guard !isSelected else { return }
                    Haptics.selection()
                    selection = tab
                } label: {
                    VStack(spacing: 6) {
                        Image(systemName: tab.systemImage).font(.system(size: 20)).frame(height: 24)
                        Text(tab.title).monoLabel(size: 10, color: isSelected ? Theme.amber : Theme.muted)
                    }
                    .foregroundStyle(isSelected ? Theme.amber : Theme.muted)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 10)
                    .overlay(alignment: .top) {
                        if isSelected { Rectangle().fill(Theme.amber).frame(height: 2) }
                    }
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityLabel(Text(tab.title))
                .accessibilityAddTraits(isSelected ? .isSelected : [])
            }
        }
        .background(Theme.bg)
        .overlay(alignment: .top) { Rectangle().fill(Theme.line).frame(height: Theme.lineWidth) }
    }
}

#Preview {
    @Previewable @State var tab = AppTab.darkroom
    AppTabBar(selection: $tab)
}
