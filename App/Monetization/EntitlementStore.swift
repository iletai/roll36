import Foundation
import Observation
import os
import StoreKit

/// Where the store learns which product ids the user owns. Injectable so tests run without StoreKit.
protocol EntitlementSource {
    /// Product ids currently entitled (verified, not revoked).
    func currentProductIDs() async -> Set<String>
    /// Emits the full current set after every change (purchase elsewhere, refund, Ask to Buy approval...).
    var updates: AsyncStream<Set<String>> { get }
}

/// Live source over `Transaction.currentEntitlements` / `Transaction.updates`; only verified, non-revoked transactions count.
struct StoreKitEntitlementSource: EntitlementSource {
    func currentProductIDs() async -> Set<String> {
        var ids = Set<String>()
        for await result in Transaction.currentEntitlements {
            if case let .verified(transaction) = result, transaction.revocationDate == nil {
                ids.insert(transaction.productID)
            }
        }
        return ids
    }

    var updates: AsyncStream<Set<String>> {
        AsyncStream { continuation in
            let task = Task {
                for await result in Transaction.updates {
                    if case let .verified(transaction) = result { await transaction.finish() }
                    continuation.yield(await currentProductIDs())
                }
                continuation.finish()
            }
            continuation.onTermination = { _ in task.cancel() }
        }
    }
}

/// What the user owns (PLAN 12.2). The transaction stream is the source of truth;
/// the `UserDefaults` cache only avoids a locked-looking UI on the first frame.
@Observable
final class EntitlementStore {
    static let cacheKey = "entitlements.cache"

    private(set) var ownedStockIDs: Set<String> = []
    private(set) var hasFullUnlock = false
    private(set) var isLoading = true

    private let source: EntitlementSource
    private let catalog: ProductCatalog
    private let defaults: UserDefaults
    private var listener: Task<Void, Never>?

    init(
        source: EntitlementSource = StoreKitEntitlementSource(),
        catalog: ProductCatalog = ProductCatalog(),
        defaults: UserDefaults = .standard
    ) {
        self.source = source
        self.catalog = catalog
        self.defaults = defaults
        apply(Set(defaults.stringArray(forKey: Self.cacheKey) ?? []), writeCache: false)
    }

    var hasAnyPurchase: Bool { hasFullUnlock || !ownedStockIDs.isEmpty }

    /// Parallel developing is unlimited once the user bought anything (PLAN 10.3).
    var canDevelopInParallel: Bool { hasAnyPurchase }

    /// Free users get 5 lifetime imports (PLAN 11.2).
    var isImportUnlimited: Bool { hasAnyPurchase }

    /// Exports are watermark-free once the user bought anything (PLAN 12.3).
    var removesWatermark: Bool { hasAnyPurchase }

    func isUnlocked(stockID: String) -> Bool {
        stockID == ProductCatalog.freeStockID || hasFullUnlock || ownedStockIDs.contains(stockID)
    }

    /// Starts the `Transaction.updates` loop for the life of the app. Safe to call repeatedly.
    func startListening() {
        guard listener == nil else { return }
        // Subscribe before the first refresh so no update is missed in between.
        let updates = source.updates
        listener = Task { [weak self] in
            await self?.refresh()
            for await productIDs in updates {
                guard let self else { return }
                apply(productIDs)
            }
        }
    }

    func refresh() async {
        apply(await source.currentProductIDs())
    }

    private func apply(_ productIDs: Set<String>, writeCache: Bool = true) {
        hasFullUnlock = productIDs.contains(catalog.fullUnlockID)
        ownedStockIDs = Set(productIDs.compactMap(catalog.stockID(forProductID:)))
        if writeCache {
            isLoading = false
            defaults.set(productIDs.sorted(), forKey: Self.cacheKey)
            Log.store.info("entitlements: full=\(self.hasFullUnlock) stocks=\(self.ownedStockIDs.count)")
        }
    }
}
