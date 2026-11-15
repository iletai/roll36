import SwiftUI

/// Stub: replaced by the Library slice. Sheet for one stock; locked stocks lead to `PaywallView`.
struct FilmDetailSheet: View {
    let profile: FilmProfile
    var body: some View { Text(verbatim: profile.displayName).monoDisplay(size: 28) }
}
