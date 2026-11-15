import os

/// One logger per area: `Log.app.info("...")`. Shows in Console.app filtered by the bundle id.
enum Log {
    private static let subsystem = AppConfiguration.bundleIdentifier
    static let app = Logger(subsystem: subsystem, category: "app")
    static let network = Logger(subsystem: subsystem, category: "network")
    static let store = Logger(subsystem: subsystem, category: "store")
}
