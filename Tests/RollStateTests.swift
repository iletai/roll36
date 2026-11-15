import Foundation
import Testing
@testable import ROLL36

struct RollStateTests {
    private func makeRoll(shots: Int = 0, capacity: Int = 36) -> Roll {
        let roll = Roll(stockID: "portra400", capacity: capacity)
        for index in 0 ..< shots {
            roll.shots.append(Shot(index: index, imageFilename: "\(index).jpg", thumbnailFilename: "\(index)_t.jpg"))
        }
        return roll
    }

    @Test func activeCountsRemaining() {
        #expect(makeRoll(shots: 10).state() == .active(remaining: 26))
    }

    @Test func exposedWhenFull() {
        #expect(makeRoll(shots: 36).state() == .exposed)
    }

    @Test func exposedWhenFinishedEarly() {
        let roll = makeRoll(shots: 3)
        roll.finishedAt = .now
        #expect(roll.state() == .exposed)
    }

    @Test func developingProgressClamps() {
        let now = Date()
        let roll = makeRoll(shots: 36)
        roll.developStartedAt = now.addingTimeInterval(-1800)
        guard case let .developing(progress, readyAt) = roll.state(now: now) else {
            Issue.record("expected .developing")
            return
        }
        #expect(abs(progress - 0.5) < 0.0001)
        #expect(readyAt == now.addingTimeInterval(1800))

        // Clock moved before the start: progress must not go negative.
        guard case let .developing(early, _) = roll.state(now: now.addingTimeInterval(-7200)) else {
            Issue.record("expected .developing")
            return
        }
        #expect(early == 0)
    }

    @Test func developedAfterElapsed() {
        let now = Date()
        let roll = makeRoll(shots: 36)
        roll.developStartedAt = now.addingTimeInterval(-3600)
        #expect(roll.state(now: now) == .developed)
    }

    @Test func killedAppResumesCorrectly() {
        let now = Date()
        let roll = makeRoll(shots: 36)
        roll.developStartedAt = now.addingTimeInterval(-90 * 60)
        roll.developDuration = 60 * 60
        #expect(roll.state(now: now) == .developed)
    }

    @Test func importRollIsAlwaysDeveloped() {
        let roll = Roll(stockID: "import", capacity: 0, isImportRoll: true)
        #expect(roll.state() == .developed)
    }
}
