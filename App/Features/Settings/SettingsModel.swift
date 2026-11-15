import Foundation
import Observation

/// Single place for the legal URLs. Base is `fastlane/metadata/en-US/privacy_url.txt`; terms is its sibling path.
enum LegalLinks {
    static let privacy = URL(string: "https://apps-site-six.vercel.app/apps/roll36/privacy")
    static let terms = URL(string: "https://apps-site-six.vercel.app/apps/roll36/terms")
}

/// Testable logic behind `SettingsView`: display strings and the delete-all flow.
@Observable
final class SettingsModel {
    private(set) var isDeleting = false
    private(set) var deleteMessage: String?

    /// "1.0 (12)"; a missing value shows as "?".
    static func versionString(short: String?, build: String?) -> String {
        "\(short ?? "?") (\(build ?? "?"))"
    }

    static func versionString(bundle: Bundle = .main) -> String {
        versionString(
            short: bundle.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String,
            build: bundle.object(forInfoDictionaryKey: "CFBundleVersion") as? String
        )
    }

    static func ownedText(for entitlements: EntitlementStore) -> String {
        if entitlements.hasFullUnlock { return String(localized: "Full unlock active") }
        switch entitlements.ownedStockIDs.count {
        case 0: return String(localized: "No stocks owned")
        case 1: return String(localized: "1 stock owned")
        case let count: return String(localized: "\(count) stocks owned")
        }
    }

    /// Removes every roll and image file. The free-import counter (`importsUsed`) is deliberately left alone:
    /// resetting it would let a free user get unlimited imports by deleting their data.
    func deleteAll(from repository: RollRepository) async {
        isDeleting = true
        defer { isDeleting = false }
        do {
            try await repository.deleteAll()
            deleteMessage = String(localized: "All rolls and photos were deleted.")
        } catch {
            deleteMessage = String(localized: "Something went wrong. Try again.")
        }
    }
}
