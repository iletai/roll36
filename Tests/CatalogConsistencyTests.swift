import Foundation
import Testing
@testable import ROLL36

struct CatalogConsistencyTests {
    private let products = ProductCatalog(prefix: "com.lequangtrongtai.roll36.dev")

    @Test func allPricesMatchProductCatalog() {
        for profile in FilmCatalog.all {
            #expect(products.listPrice(forStock: profile.id) == profile.listPrice, "\(profile.id)")
        }
    }

    @Test func stockIDsMatchProductCatalog() {
        #expect(FilmCatalog.all.map(\.id) == ProductCatalog.allStockIDs)
        #expect(ProductCatalog.freeStockID == FilmCatalog.free.id)
    }

    @Test func paidStocksMatchProducts() {
        #expect(Set(FilmCatalog.all.filter { !$0.isFree }.map(\.id)) == Set(products.paidStockIDs))
    }
}
