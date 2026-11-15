import SwiftData
import SwiftUI

@main
struct ROLL36App: App {
    @State private var environment = AppEnvironment.live()

    var body: some Scene {
        WindowGroup {
            RootView()
                .environment(environment)
                .modelContainer(environment.modelContainer)
        }
    }
}
