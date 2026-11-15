import Foundation
@testable import ROLL36
import Testing

struct ProductCatalogTests {
    private let catalog = ProductCatalog(prefix: "com.example.app")

    @Test func idsFollowInjectedPrefix() {
        #expect(catalog.fullUnlockID == "com.example.app.full")
        #expect(catalog.productID(forStock: "trix400") == "com.example.app.film.trix400")
        #expect(ProductCatalog(prefix: "other").fullUnlockID == "other.full")
    }

    @Test func freeStockHasNoProduct() {
        #expect(ProductCatalog.freeStockID == "portra400")
        #expect(catalog.productID(forStock: "portra400") == nil)
        #expect(catalog.listPrice(forStock: "portra400") == 0)
    }

    @Test func fourteenStocksThirteenFilmProductsPlusFull() {
        #expect(ProductCatalog.allStockIDs.count == 14)
        #expect(Set(ProductCatalog.allStockIDs).count == 14)
        #expect(catalog.paidStockIDs.count == 13)
        #expect(catalog.allProductIDs.count == 14)
        #expect(Set(catalog.allProductIDs).count == 14)
    }

    @Test func stockAndProductIDsRoundTrip() {
        for stockID in catalog.paidStockIDs {
            let productID = catalog.productID(forStock: stockID)
            #expect(productID != nil)
            #expect(catalog.stockID(forProductID: productID ?? "") == stockID)
        }
    }

    @Test func foreignAndUnknownIDsMapToNil() {
        #expect(catalog.stockID(forProductID: catalog.fullUnlockID) == nil)
        #expect(catalog.stockID(forProductID: "com.other.app.film.trix400") == nil)
        #expect(catalog.stockID(forProductID: "com.example.app.film.nope") == nil)
        #expect(catalog.stockID(forProductID: "com.example.app.film.portra400") == nil)
        #expect(catalog.productID(forStock: "nope") == nil)
    }

    @Test func listPricesMatchPlanTable() {
        #expect(catalog.listPrice(forStock: "ektar100") == Decimal(string: "1.49"))
        #expect(catalog.listPrice(forStock: "gold200") == Decimal(string: "0.99"))
        #expect(catalog.listPrice(forStock: "provia100") == Decimal(string: "1.49"))
        #expect(ProductCatalog.fullUnlockListPrice == Decimal(string: "4.99"))
    }

    @Test func storeKitConfigMatchesDevCatalog() throws {
        let url = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent().deletingLastPathComponent()
            .appendingPathComponent("App/Monetization/ROLL36.storekit")
        let json = try #require(JSONSerialization.jsonObject(with: Data(contentsOf: url)) as? [String: Any])
        let products = try #require(json["products"] as? [[String: Any]])
        let subscriptionGroups = try #require(json["subscriptionGroups"] as? [Any])

        let dev = ProductCatalog(prefix: "com.lequangtrongtai.roll36.dev")
        #expect(Set(products.compactMap { $0["productID"] as? String }) == Set(dev.allProductIDs))
        #expect(products.count == 14)
        #expect(products.allSatisfy { $0["type"] as? String == "NonConsumable" })
        #expect(subscriptionGroups.isEmpty)
        #expect((json["nonRenewingSubscriptions"] as? [Any])?.isEmpty == true)

        for product in products {
            let productID = try #require(product["productID"] as? String)
            let price = try #require((product["displayPrice"] as? String).flatMap { Decimal(string: $0) })
            let expected = dev.stockID(forProductID: productID).map(dev.listPrice(forStock:)) ?? ProductCatalog.fullUnlockListPrice
            #expect(price == expected, "price mismatch for \(productID)")
        }
    }
}
