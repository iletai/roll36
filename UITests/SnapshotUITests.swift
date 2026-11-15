import XCTest

/// App Store screenshots (`bundle exec fastlane screenshots`); devices/languages in fastlane/Snapfile.
@MainActor
final class SnapshotUITests: XCTestCase {
    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    func testCaptureScreenshots() throws {
        let app = XCUIApplication()
        setupSnapshot(app)
        app.launch()

        XCTAssertTrue(app.wait(for: .runningForeground, timeout: 10))
        snapshot("01-home")
        // Add one snapshot("NN-name") per store screenshot; drive tabs by index so every language works.
    }
}
