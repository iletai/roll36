import SwiftUI

/// Top of the view tree. A `ZStack` keeps all three tab root views alive so their state survives tab
/// switches; only the selected tab is visible and interactive. The custom `AppTabBar` remains the
/// sole tab selector (no system `TabView` chrome).
struct RootView: View {
    @AppStorage("onboardingSeen") private var onboardingSeen = false
    @Environment(AppEnvironment.self) private var env

    private var selection: AppTab { env.selectedTab }

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

    // MARK: - Tabs

    private var tabs: some View {
        VStack(spacing: 0) {
            ZStack {
                ViewfinderView(isTabActive: selection == .camera)
                    .opacity(selection == .camera ? 1 : 0)
                    .allowsHitTesting(selection == .camera)
                DarkroomView(isTabActive: selection == .darkroom)
                    .opacity(selection == .darkroom ? 1 : 0)
                    .allowsHitTesting(selection == .darkroom)
                FilmLibraryView()
                    .opacity(selection == .library ? 1 : 0)
                    .allowsHitTesting(selection == .library)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            AppTabBar(selection: Bindable(env).selectedTab)
        }
    }
}

#Preview {
    RootView().environment(AppEnvironment.preview())
}
