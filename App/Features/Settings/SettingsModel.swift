import Foundation
import Observation

/// Single place for the legal URLs. Base is `fastlane/metadata/en-US/privacy_url.txt`; terms is its sibling path.
enum LegalLinks {
    static let privacy = URL(string: "https://apps-site-six.vercel.app/apps/roll36/privacy")
    static let terms = URL(string: "https://apps-site-six.vercel.app/apps/roll36/terms")
}

/// Camera preference options persisted via `@AppStorage`.
enum CameraDefaultZoom: String, CaseIterable, Identifiable {
    case mm28 = "28mm"
    case mm35 = "35mm"
    case mm50 = "50mm"

    var id: String { rawValue }
    var title: String {
        switch self {
        case .mm28: "28mm (1.0x)"
        case .mm35: "35mm (1.25x)"
        case .mm50: "50mm (1.8x)"
        }
    }
}

enum CameraTargetFPS: Int, CaseIterable, Identifiable {
    case fps30 = 30
    case fps60 = 60

    var id: Int { rawValue }
    var title: String {
        switch self {
        case .fps30: "30 FPS (Tiết kiệm pin)"
        case .fps60: "60 FPS (Mượt mà)"
        }
    }
}

enum CameraFrameAspect: String, CaseIterable, Identifiable {
    case ratio4_3 = "4:3"
    case ratio3_2 = "3:2"
    case ratio1_1 = "1:1"

    var id: String { rawValue }
    var title: String {
        switch self {
        case .ratio4_3: "4:3 (Cảm biến chuẩn)"
        case .ratio3_2: "3:2 (Film 35mm cổ điển)"
        case .ratio1_1: "1:1 (Vuông)"
        }
    }
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
