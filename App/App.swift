import SwiftData
import SwiftUI

@main
struct ROLL36App: App {
    @State private var environment = AppEnvironment.live()

    var body: some Scene {
        WindowGroup {
            root
                .environment(environment)
                .modelContainer(environment.modelContainer)
        }
    }

    @ViewBuilder private var root: some View {
        #if DEBUG
            DemoSeedGate(env: environment) { RootView() }
        #else
            RootView()
        #endif
    }
}
