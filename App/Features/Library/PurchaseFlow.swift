import Observation
import StoreKit

/// Shared UI state for a purchase or restore in flight: busy flag plus a short inline message.
@Observable
final class PurchaseFlow {
    private(set) var isBusy = false
    private(set) var message: String?

    /// True only when the purchase completed (entitlements are already refreshed).
    func purchase(_ operation: () async throws -> PurchaseOutcome) async -> Bool {
        isBusy = true
        message = nil
        defer { isBusy = false }
        do {
            switch try await operation() {
            case .purchased: return true
            case .pending: message = String(localized: "Waiting for approval. The unlock appears once it is approved.")
            case .cancelled: message = String(localized: "Purchase cancelled.")
            }
        } catch {
            message = Self.describe(error)
        }
        return false
    }

    func restore(_ operation: () async throws -> Void) async {
        isBusy = true
        message = nil
        defer { isBusy = false }
        do {
            try await operation()
            message = String(localized: "Purchases restored.")
        } catch StoreKitError.userCancelled {
            message = nil
        } catch {
            message = Self.describe(error)
        }
    }

    private static func describe(_ error: Error) -> String {
        switch error as? PurchaseError {
        case .productUnavailable: String(localized: "The App Store is not available right now. Try again later.")
        case .unverified: String(localized: "The purchase could not be verified.")
        default: String(localized: "Something went wrong. Try again.")
        }
    }
}

extension PurchaseService {
    /// StoreKit price when loaded, otherwise the catalog list price (DECISIONS D5).
    func price(forStock stockID: String) -> String {
        let catalog = ProductCatalog()
        return catalog.productID(forStock: stockID).flatMap(displayPrice(forProductID:))
            ?? catalog.listPrice(forStock: stockID).formatted(.currency(code: "USD"))
    }

    var fullUnlockPrice: String {
        displayPrice(forProductID: ProductCatalog().fullUnlockID)
            ?? ProductCatalog.fullUnlockListPrice.formatted(.currency(code: "USD"))
    }
}
