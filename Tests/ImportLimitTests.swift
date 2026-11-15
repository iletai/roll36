import Foundation
import Testing
@testable import ROLL36

struct ImportLimitTests {
    private func makeQuota() throws -> ImportQuota {
        let suite = "ImportLimitTests-\(UUID().uuidString)"
        let defaults = try #require(UserDefaults(suiteName: suite))
        defaults.removePersistentDomain(forName: suite)
        return ImportQuota(defaults: defaults)
    }

    @Test func freeLimitFive() throws {
        let quota = try makeQuota()
        #expect(quota.remaining(isUnlocked: false) == 5)
        for _ in 0 ..< ImportQuota.freeLimit {
            #expect(quota.canImport(isUnlocked: false))
            quota.recordImport()
        }
        #expect(quota.remaining(isUnlocked: false) == 0)
        #expect(!quota.canImport(isUnlocked: false))
    }

    @Test func paidUnlimited() throws {
        let quota = try makeQuota()
        for _ in 0 ..< 10 {
            quota.recordImport()
        }
        #expect(quota.remaining(isUnlocked: true) == nil)
        #expect(quota.canImport(isUnlocked: true))
    }
}
