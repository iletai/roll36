import XCTest

/// Library to purchase surfaces. Asserts on identifiers only: StoreKit products may not load in a test run.
/// Not MainActor: default isolation would change the XCTestCase inits, which are nonisolated.
final nonisolated class PaywallUITests: XCTestCase {
    @MainActor
    override func setUp() async throws {
        continueAfterFailure = false
    }

    @MainActor
    private func launchToLibrary() -> XCUIApplication {
        let app = XCUIApplication()
        app.launch()
        let start = app.buttons["Start"]
        if start.waitForExistence(timeout: 5) { start.tap() }
        let libraryTab = app.buttons["Library"]
        XCTAssertTrue(libraryTab.waitForExistence(timeout: 10))
        libraryTab.tap()
        return app
    }

    @MainActor
    func testTappingLockedStockOpensDetailSheet() throws {
        let app = launchToLibrary()
        let card = app.buttons["library.card.ektar100"]
        XCTAssertTrue(card.waitForExistence(timeout: 10))
        card.tap()
        XCTAssertTrue(app.descendants(matching: .any)["film.detail"].waitForExistence(timeout: 5))
    }

    @MainActor
    func testUnlockAllButtonOpensPaywall() throws {
        let app = launchToLibrary()
        let cta = app.buttons["library.unlockAll"]
        XCTAssertTrue(cta.waitForExistence(timeout: 10))
        cta.tap()
        XCTAssertTrue(app.descendants(matching: .any)["paywall"].waitForExistence(timeout: 5))
    }
}
