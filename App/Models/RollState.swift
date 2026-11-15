import Foundation

/// Derived from `Roll` fields, never persisted (PLAN 7.2): avoids stale state after a kill and needs no migration.
nonisolated enum RollState: Equatable, Sendable {
    case active(remaining: Int)
    case exposed // full or finished early, waiting to be developed
    case developing(progress: Double, readyAt: Date)
    case developed
}

extension Roll {
    /// Order of checks matters. `developedAt` is stamped lazily, so a long-killed app still resolves
    /// correctly because `readyAt` is computed from `developStartedAt`.
    func state(now: Date = .now) -> RollState {
        if isImportRoll { return .developed }
        if let developedAt, now >= developedAt { return .developed }
        if let start = developStartedAt {
            let ready = start.addingTimeInterval(developDuration)
            if now >= ready { return .developed }
            let progress = now.timeIntervalSince(start) / developDuration
            return .developing(progress: min(max(progress, 0), 1), readyAt: ready)
        }
        if finishedAt != nil || isFull { return .exposed }
        return .active(remaining: capacity - shots.count)
    }

    var isFull: Bool { shots.count >= capacity }

    func readyAt() -> Date? {
        developStartedAt?.addingTimeInterval(developDuration)
    }
}
