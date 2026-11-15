import Foundation

/// Maps film stock ids to App Store product ids. Ids follow the running environment's bundle id (DECISIONS D2).
struct ProductCatalog: Sendable {
    /// The only stock available without a purchase; it has no product.
    static let freeStockID = "portra400"

    /// All 14 stock ids in PLAN 7.4 order (free stock first).
    static let allStockIDs: [String] = listPricesInCents.map(\.id)

    /// List prices in cents from PLAN 7.4. Cross-checked against FilmCatalog by a later integration test.
    private static let listPricesInCents: [(id: String, cents: Int)] = [
        ("portra400", 0), ("ektar100", 149), ("fuji400h", 149), ("gold200", 99), ("ultramax400", 99),
        ("trix400", 149), ("hp5", 149), ("acros100", 99), ("cinestill800t", 149), ("portra800", 149),
        ("expiredGold", 99), ("expiredFuji", 99), ("velvia50", 149), ("provia100", 149)
    ]

    /// Fallback label for the full unlock (PLAN 12.1); the UI prefers `Product.displayPrice`.
    static let fullUnlockListPrice = Decimal(499) / 100

    let prefix: String

    init(prefix: String = Bundle.main.bundleIdentifier ?? "") {
        self.prefix = prefix
    }

    var fullUnlockID: String { "\(prefix).full" }

    /// Stocks sold individually (everything except the free one).
    var paidStockIDs: [String] { Self.allStockIDs.filter { $0 != Self.freeStockID } }

    /// Full unlock plus one product per paid stock (14 ids).
    var allProductIDs: [String] { [fullUnlockID] + paidStockIDs.map { "\(prefix).film.\($0)" } }

    /// nil for the free stock and for unknown ids.
    func productID(forStock stockID: String) -> String? {
        paidStockIDs.contains(stockID) ? "\(prefix).film.\(stockID)" : nil
    }

    /// nil for the full unlock id, foreign ids and unknown stocks.
    func stockID(forProductID productID: String) -> String? {
        let filmPrefix = "\(prefix).film."
        guard productID.hasPrefix(filmPrefix) else { return nil }
        let stockID = String(productID.dropFirst(filmPrefix.count))
        return paidStockIDs.contains(stockID) ? stockID : nil
    }

    /// Catalog price in the store's base currency; 0 for the free stock and for unknown ids.
    /// Only a fallback label: the UI shows `Product.displayPrice` (DECISIONS D5).
    func listPrice(forStock stockID: String) -> Decimal {
        let cents = Self.listPricesInCents.first { $0.id == stockID }?.cents ?? 0
        return Decimal(cents) / 100
    }
}
