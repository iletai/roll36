import SwiftUI

/// Top of the view tree. A plain `switch` (not TabView) so the camera tab never gets a system bar.
struct RootView: View {
    @AppStorage("onboardingSeen") private var onboardingSeen = false
    @State private var selection: AppTab = .camera

    var body: some View {
        Group {
            if onboardingSeen {
                tabs
            } else {
                OnboardingView { onboardingSeen = true }
            }
        }
        .background(Theme.bg.ignoresSafeArea())
        .preferredColorScheme(.dark)
    }

    private var tabs: some View {
        VStack(spacing: 0) {
            Group {
                switch selection {
                case .camera: ViewfinderView()
                case .darkroom: DarkroomView()
                case .library: FilmLibraryView()
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            AppTabBar(selection: $selection)
        }
    }
}

#Preview {
    RootView().environment(AppEnvironment.preview())
}
