import Foundation
@testable import ROLL36
import Testing

private struct FakeSource: EntitlementSource {
    var current: Set<String> = []
    var updates: AsyncStream<Set<String>> { AsyncStream { $0.finish() } }

    func currentProductIDs() async -> Set<String> { current }
}

struct SettingsTests {
    private let catalog = ProductCatalog(prefix: "com.example.app")

    private func ownedText(_ ids: Set<String>) async throws -> String {
        let defaults = try #require(UserDefaults(suiteName: "SettingsTests-\(UUID().uuidString)"))
        let store = EntitlementStore(source: FakeSource(current: ids), catalog: catalog, defaults: defaults)
        await store.refresh()
        return SettingsModel.ownedText(for: store)
    }

    private func productID(_ stockID: String) throws -> String {
        try #require(catalog.productID(forStock: stockID))
    }

    @Test func deleteAllEmptiesRepositoryAndKeepsImportQuota() async throws {
        let env = AppEnvironment.preview()
        _ = try env.repository.startRoll(stockID: "portra400")
        _ = try env.repository.importRoll()
        env.importQuota.recordImport()
        env.importQuota.recordImport()
        let remaining = env.importQuota.remaining(isUnlocked: false)
        #expect(remaining == ImportQuota.freeLimit - 2)

        let model = SettingsModel()
        await model.deleteAll(from: env.repository)

        #expect(try env.repository.rolls().isEmpty)
        #expect(try env.repository.importRoll().shots.isEmpty)
        #expect(env.importQuota.remaining(isUnlocked: false) == remaining)
        #expect(model.deleteMessage != nil)
        #expect(!model.isDeleting)
    }

    @Test func versionFormatting() {
        #expect(SettingsModel.versionString(short: "1.2", build: "34") == "1.2 (34)")
        #expect(SettingsModel.versionString(short: nil, build: nil) == "? (?)")
    }

    @Test func ownedTextForNoneOneAndFullUnlock() async throws {
        #expect(try await ownedText([]) == "No stocks owned")
        #expect(try await ownedText([productID("trix400")]) == "1 stock owned")
        #expect(try await ownedText([productID("trix400"), productID("hp5")]) == "2 stocks owned")
        #expect(try await ownedText([catalog.fullUnlockID]) == "Full unlock active")
    }

    @Test func legalLinksShareTheSiteBase() throws {
        let privacy = try #require(LegalLinks.privacy)
        let terms = try #require(LegalLinks.terms)
        #expect(privacy.deletingLastPathComponent() == terms.deletingLastPathComponent())
        #expect(terms.lastPathComponent == "terms")
    }
}
