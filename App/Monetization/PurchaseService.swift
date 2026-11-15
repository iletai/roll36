import Foundation
import Observation
import os
import StoreKit

enum PurchaseOutcome {
    case purchased
    /// Ask to Buy or deferred approval; the unlock arrives later through `Transaction.updates`.
    case pending
    case cancelled
}

enum PurchaseError: Error {
    /// The stock has no product (free or unknown id).
    case noProduct
    /// StoreKit did not return this product (offline, not configured in App Store Connect).
    case productUnavailable
    /// The App Store signature check failed; nothing is unlocked.
    case unverified
}

/// Loads products, runs purchases and restores. Non-consumables only (PLAN 12.1).
@Observable
final class PurchaseService {
    private(set) var products: [String: Product] = [:]

    private let entitlements: EntitlementStore
    private let catalog: ProductCatalog

    init(entitlements: EntitlementStore, catalog: ProductCatalog = ProductCatalog()) {
        self.entitlements = entitlements
        self.catalog = catalog
    }

    /// StoreKit-localized price, nil until products are loaded.
    func displayPrice(forProductID productID: String) -> String? {
        products[productID]?.displayPrice
    }

    /// Failures are logged and leave `products` as is; the UI falls back to `ProductCatalog.listPrice`.
    func loadProducts() async {
        do {
            let loaded = try await Product.products(for: catalog.allProductIDs)
            products = Dictionary(uniqueKeysWithValues: loaded.map { ($0.id, $0) })
        } catch {
            Log.store.error("loading products failed: \(error)")
        }
    }

    func purchase(stockID: String) async throws -> PurchaseOutcome {
        guard let productID = catalog.productID(forStock: stockID) else { throw PurchaseError.noProduct }
        return try await purchase(productID: productID)
    }

    func purchaseFullUnlock() async throws -> PurchaseOutcome {
        try await purchase(productID: catalog.fullUnlockID)
    }

    /// Syncs with the App Store, then re-reads entitlements. Throws `StoreKitError.userCancelled` if the user dismisses sign-in.
    func restore() async throws {
        try await AppStore.sync()
        await entitlements.refresh()
    }

    private func purchase(productID: String) async throws -> PurchaseOutcome {
        if products[productID] == nil { await loadProducts() }
        guard let product = products[productID] else { throw PurchaseError.productUnavailable }

        switch try await product.purchase() {
        case let .success(verification):
            guard case let .verified(transaction) = verification else { throw PurchaseError.unverified }
            // Entitlements come from the transaction stream; refresh first so the UI unlocks before finish().
            await entitlements.refresh()
            await transaction.finish()
            return .purchased
        case .pending:
            return .pending
        case .userCancelled:
            return .cancelled
        @unknown default:
            return .cancelled
        }
    }
}
