import Foundation

/// Pure logic behind the Darkroom screen, kept free of SwiftUI so it can be unit tested.
/// There is deliberately no way to skip or speed up developing: it is a product decision (PLAN §10.4).
enum DevelopingTicker {
    enum DevelopAction: Equatable {
        case develop
        /// Free user with another roll in the tank: the card says "Waiting for previous roll" and the button opens the paywall.
        case waitForPrevious
    }

    static let stageCount = 3

    /// `mm:ss`, or `h:mm:ss` from one hour up. Rounds up so a running countdown never shows 00:00 early.
    static func remainingText(until readyAt: Date, now: Date) -> String {
        let total = max(0, Int(readyAt.timeIntervalSince(now).rounded(.up)))
        let (hours, minutes, seconds) = (total / 3600, total % 3600 / 60, total % 60)
        return hours > 0
            ? String(format: "%d:%02d:%02d", hours, minutes, seconds)
            : String(format: "%02d:%02d", minutes, seconds)
    }

    /// Decorative stage 1...3 derived from progress; no real chemistry is involved (DECISIONS D7).
    static func stage(progress: Double) -> Int {
        min(stageCount, Int(min(max(progress, 0), 1) * Double(stageCount)) + 1)
    }

    /// Decorative tank id such as "A-1", from the roll's position in the list.
    static func tankID(index: Int) -> String {
        let letters = ["A", "B", "C"]
        return "\(letters[index / 3 % letters.count])-\(index % 3 + 1)"
    }

    static func developAction(otherRollDeveloping: Bool, canDevelopInParallel: Bool) -> DevelopAction {
        otherRollDeveloping && !canDevelopInParallel ? .waitForPrevious : .develop
    }

    /// Newest developed frames across the given rolls. Frames of rolls that are not `.developed` never appear (PLAN §18.5).
    static func recentFrames(from rolls: [Roll], now: Date, limit: Int = 8) -> [Shot] {
        rolls
            .filter { $0.state(now: now) == .developed }
            .flatMap(\.shots)
            .sorted { $0.capturedAt > $1.capturedAt }
            .prefix(limit)
            .map { $0 }
    }
}
