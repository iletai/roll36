import Foundation
@testable import ROLL36
import Testing

struct FilmCatalogTests {
    @Test func allFourteenStocksPresent() {
        #expect(FilmCatalog.all.map(\.id) == [
            "portra400", "ektar100", "fuji400h", "gold200", "ultramax400",
            "trix400", "hp5", "acros100",
            "cinestill800t", "portra800",
            "expiredGold", "expiredFuji",
            "velvia50", "provia100"
        ])
        #expect(FilmCatalog.profile(id: "velvia50")?.displayName == "Velvia 50")
        #expect(FilmCatalog.profile(id: "nope") == nil)
        #expect(FilmCatalog.profiles(in: .monochrome).map(\.id) == ["trix400", "hp5", "acros100"])
        #expect(FilmCatalog.profiles(in: .monochrome).allSatisfy { $0.isMonochrome && $0.process == .bw })
    }

    @Test func uniqueIDs() {
        #expect(Set(FilmCatalog.all.map(\.id)).count == FilmCatalog.all.count)
    }

    @Test func onlyPortraIsFree() {
        #expect(FilmCatalog.all.filter(\.isFree).map(\.id) == ["portra400"])
        #expect(FilmCatalog.free.id == "portra400")
    }

    /// PLAN §7.4 price table (ProductCatalog cross-check lives with the Monetization slice).
    @Test func pricesMatchPlanTable() {
        let cents: [String: Int] = [
            "portra400": 0, "ektar100": 149, "fuji400h": 149, "gold200": 99, "ultramax400": 99,
            "trix400": 149, "hp5": 149, "acros100": 99,
            "cinestill800t": 149, "portra800": 149,
            "expiredGold": 99, "expiredFuji": 99,
            "velvia50": 149, "provia100": 149
        ]
        for profile in FilmCatalog.all {
            #expect(profile.listPrice == Decimal(cents[profile.id] ?? -1) / 100, "\(profile.id)")
        }
    }

    @Test func framesPerRoll() {
        for profile in FilmCatalog.all {
            let expected = profile.group == .expired ? 24 : 36
            #expect(profile.frames == expected, "\(profile.id)")
        }
    }
}
