import Foundation

/// Lifetime free-import counter (PLAN 11.2).
struct ImportQuota {
    static let freeLimit = 5
    private static let key = "importsUsed"

    let defaults: UserDefaults

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }

    /// nil = unlimited.
    func remaining(isUnlocked: Bool) -> Int? {
        isUnlocked ? nil : max(Self.freeLimit - defaults.integer(forKey: Self.key), 0)
    }

    func canImport(isUnlocked: Bool) -> Bool {
        remaining(isUnlocked: isUnlocked).map { $0 > 0 } ?? true
    }

    func recordImport() {
        defaults.set(defaults.integer(forKey: Self.key) + 1, forKey: Self.key)
    }
}
