import SwiftUI

/// Stub: replaced by the Settings slice. Shown once, before the tabs; `onFinish` marks it as seen.
struct OnboardingView: View {
    let onFinish: () -> Void
    var body: some View { Button("Start", action: onFinish) }
}
