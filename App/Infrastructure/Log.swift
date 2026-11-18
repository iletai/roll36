import Foundation
import os

/// One logger per area: `Log.app.info("...")`. Shows in Console.app filtered by the bundle id.
enum Log {
    private static let subsystem = AppConfiguration.bundleIdentifier
    static let app = Logger(subsystem: subsystem, category: "app")
    static let network = Logger(subsystem: subsystem, category: "network")
    static let store = Logger(subsystem: subsystem, category: "store")
    /// Nonisolated: ImageStore is an actor and logs off the main actor.
    nonisolated static let storage = Logger(subsystem: Bundle.main.bundleIdentifier ?? "", category: "storage")
    /// Nonisolated because the camera actor logs off the main actor (`subsystem` is main-actor isolated).
    nonisolated static let camera = Logger(subsystem: Bundle.main.bundleIdentifier ?? "", category: "camera")
    nonisolated static let film = Logger(subsystem: Bundle.main.bundleIdentifier ?? "", category: "film")
}
