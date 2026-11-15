import SwiftUI

/// Chips on the Library screen (PLAN 13.4). Groups come from `FilmProfile.group`.
enum LibraryFilter: CaseIterable {
    case all, colorNegative, blackAndWhite, night, expired, slide

    func includes(_ profile: FilmProfile) -> Bool {
        switch self {
        case .all: true
        case .colorNegative: profile.group == .portrait
        case .blackAndWhite: profile.isMonochrome
        case .night: profile.group == .night
        case .expired: profile.group == .expired
        case .slide: profile.group == .slide
        }
    }

    var title: LocalizedStringKey {
        switch self {
        case .all: "All (\(FilmCatalog.all.count))"
        case .colorNegative: "Color negative"
        case .blackAndWhite: "B&W mono"
        case .night: "Night"
        case .expired: "Expired"
        case .slide: "Slide"
        }
    }
}

/// Pure presentation logic of the Library screen, kept out of the view so it can be unit tested.
struct LibraryModel {
    let entitlements: EntitlementStore
    let selectedStockID: String
    /// Store price label for a stock id; injected so tests do not need StoreKit.
    let stockPrice: (String) -> String

    var ownedCount: Int { FilmCatalog.all.count { entitlements.isUnlocked(stockID: $0.id) } }

    var showsUnlockAll: Bool { !entitlements.hasFullUnlock }

    func profiles(for filter: LibraryFilter) -> [FilmProfile] {
        FilmCatalog.all.filter(filter.includes)
    }

    func cardState(for profile: FilmProfile) -> FilmCardState {
        guard entitlements.isUnlocked(stockID: profile.id) else { return .locked(price: stockPrice(profile.id)) }
        return profile.id == selectedStockID ? .loaded : .owned
    }

    /// Dark swatches need light text on the card panel.
    func usesLightText(on profile: FilmProfile) -> Bool {
        let hex = profile.swatchHex
        let luma = 0.299 * Double((hex >> 16) & 0xFF) + 0.587 * Double((hex >> 8) & 0xFF) + 0.114 * Double(hex & 0xFF)
        return luma < 110
    }
}
