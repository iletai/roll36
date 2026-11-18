import Foundation
@testable import ROLL36
import Testing

private struct FakeSource: EntitlementSource {
    var current: Set<String> = []
    var updates: AsyncStream<Set<String>> { AsyncStream { $0.finish() } }

    func currentProductIDs() async -> Set<String> { current }
}

struct LibraryTests {
    private let catalog = ProductCatalog(prefix: "com.example.app")

    private func makeModel(owned: Set<String> = [], selected: String = "portra400") async throws -> LibraryModel {
        let defaults = try #require(UserDefaults(suiteName: "LibraryTests-\(UUID().uuidString)"))
        let store = EntitlementStore(source: FakeSource(current: owned), catalog: catalog, defaults: defaults)
        await store.refresh()
        return LibraryModel(entitlements: store, selectedStockID: selected, stockPrice: { "$\($0)" })
    }

    @Test func allFilterListsFourteenStocks() async throws {
        let model = try await makeModel()
        #expect(model.profiles(for: .all).count == 14)
    }

    @Test func filtersPartitionTheCatalog() async throws {
        let model = try await makeModel()
        let counts = LibraryFilter.allCases.filter { $0 != .all }.map { model.profiles(for: $0).count }
        #expect(counts == [5, 3, 2, 2, 2])
        #expect(model.profiles(for: .blackAndWhite).allSatisfy { $0.isMonochrome })
    }

    @Test func freeUserOwnsOneStock() async throws {
        let model = try await makeModel()
        #expect(model.ownedCount == 1)
        #expect(model.showsUnlockAll)
    }

    @Test func singlePurchaseCountsOnce() async throws {
        let trixID = try #require(catalog.productID(forStock: "trix400"))
        let model = try await makeModel(owned: [trixID])
        #expect(model.ownedCount == 2)
        #expect(model.showsUnlockAll)
    }

    @Test func fullUnlockOwnsAllAndHidesCTA() async throws {
        let model = try await makeModel(owned: [catalog.fullUnlockID])
        #expect(model.ownedCount == 14)
        #expect(!model.showsUnlockAll)
    }

    @Test func cardStateMapping() async throws {
        let trixID = try #require(catalog.productID(forStock: "trix400"))
        let model = try await makeModel(owned: [trixID], selected: "trix400")
        guard case .owned = model.cardState(for: FilmCatalog.portra400) else {
            Issue.record("free stock that is not selected must be .owned")
            return
        }
        guard case .loaded = try model.cardState(for: #require(FilmCatalog.profile(id: "trix400"))) else {
            Issue.record("selected owned stock must be .loaded")
            return
        }
        guard case let .locked(price) = try model.cardState(for: #require(FilmCatalog.profile(id: "ektar100"))) else {
            Issue.record("unowned stock must be .locked")
            return
        }
        #expect(price == "$ektar100")
    }

    @Test func darkSwatchGetsLightText() async throws {
        let model = try await makeModel()
        let trix = try #require(FilmCatalog.profile(id: "trix400"))
        #expect(model.usesLightText(on: trix))
        #expect(!model.usesLightText(on: FilmCatalog.portra400))
    }
}
