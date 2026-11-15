import Foundation
@testable import ROLL36
import Testing

/// Scriptable `EntitlementSource`: `current` is what a refresh returns, `emit` pushes a stream update.
private final class FakeSource: EntitlementSource {
    var current: Set<String>
    let updates: AsyncStream<Set<String>>
    private let continuation: AsyncStream<Set<String>>.Continuation

    init(current: Set<String> = []) {
        self.current = current
        (updates, continuation) = AsyncStream.makeStream()
    }

    func currentProductIDs() async -> Set<String> { current }

    func emit(_ ids: Set<String>) {
        current = ids
        continuation.yield(ids)
    }
}

struct EntitlementStoreTests {
    private let catalog = ProductCatalog(prefix: "com.example.app")
    private let defaults: UserDefaults

    init() throws {
        let suite = "EntitlementStoreTests-\(UUID().uuidString)"
        defaults = try #require(UserDefaults(suiteName: suite))
    }

    private func makeStore(_ source: FakeSource) -> EntitlementStore {
        EntitlementStore(source: source, catalog: catalog, defaults: defaults)
    }

    private func film(_ stockID: String) -> String { catalog.productID(forStock: stockID) ?? "" }

    /// Lets the listener task run until `condition` holds (bounded, so a bug fails instead of hanging).
    private func settle(_ condition: () -> Bool) async {
        for _ in 0 ..< 1000 where !condition() {
            await Task.yield()
        }
    }

    @Test func freeUserOnlyHasFreeStock() async {
        let store = makeStore(FakeSource())
        await store.refresh()
        #expect(store.isUnlocked(stockID: "portra400"))
        #expect(!store.isUnlocked(stockID: "trix400"))
        #expect(!store.hasAnyPurchase)
        #expect(!store.canDevelopInParallel)
        #expect(!store.isImportUnlimited)
        #expect(!store.removesWatermark)
        #expect(!store.isLoading)
    }

    @Test func owningOneStockUnlocksOnlyThatStock() async {
        let store = makeStore(FakeSource(current: [film("trix400")]))
        await store.refresh()
        #expect(store.ownedStockIDs == ["trix400"])
        #expect(store.isUnlocked(stockID: "trix400"))
        #expect(!store.isUnlocked(stockID: "hp5"))
        #expect(!store.hasFullUnlock)
        #expect(store.canDevelopInParallel)
        #expect(store.isImportUnlimited)
        #expect(store.removesWatermark)
    }

    @Test func fullUnlockUnlocksEveryStock() async {
        let store = makeStore(FakeSource(current: [catalog.fullUnlockID]))
        await store.refresh()
        #expect(store.hasFullUnlock)
        #expect(ProductCatalog.allStockIDs.allSatisfy(store.isUnlocked(stockID:)))
        #expect(store.canDevelopInParallel && store.isImportUnlimited && store.removesWatermark)
    }

    @Test func foreignProductIDsAreIgnored() async {
        let store = makeStore(FakeSource(current: ["com.other.app.full", "com.other.app.film.hp5"]))
        await store.refresh()
        #expect(!store.hasAnyPurchase)
    }

    @Test func streamUpdateChangesState() async {
        let source = FakeSource(current: [film("trix400")])
        let store = makeStore(source)
        store.startListening()
        store.startListening() // idempotent
        await settle { store.ownedStockIDs == ["trix400"] }
        #expect(store.isUnlocked(stockID: "trix400"))

        source.emit([film("hp5"), catalog.fullUnlockID])
        await settle { store.hasFullUnlock }
        #expect(store.ownedStockIDs == ["hp5"])

        // Revocation: the entitlement disappears.
        source.emit([])
        await settle { !store.hasAnyPurchase }
        #expect(!store.hasAnyPurchase)
        #expect(!store.isUnlocked(stockID: "trix400"))
    }

    @Test func cacheServesFirstPaintThenLiveSetReplacesIt() async {
        defaults.set([film("hp5")], forKey: EntitlementStore.cacheKey)
        let source = FakeSource(current: [film("trix400")])
        let store = makeStore(source)

        // Before any refresh: cached value shown, still loading.
        #expect(store.isUnlocked(stockID: "hp5"))
        #expect(store.isLoading)

        await store.refresh()
        #expect(!store.isUnlocked(stockID: "hp5"))
        #expect(store.isUnlocked(stockID: "trix400"))
        #expect(!store.isLoading)
        #expect(defaults.stringArray(forKey: EntitlementStore.cacheKey) == [film("trix400")])
    }
}
