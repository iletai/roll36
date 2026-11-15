import Foundation
import Testing
@testable import ROLL36

@MainActor
struct DarkroomTests {
    private let now = Date(timeIntervalSince1970: 1_800_000_000)

    @Test func remainingTextUsesMinutesAndSecondsBelowAnHour() {
        #expect(DevelopingTicker.remainingText(until: now.addingTimeInterval(252), now: now) == "04:12")
        #expect(DevelopingTicker.remainingText(until: now.addingTimeInterval(3599), now: now) == "59:59")
    }

    @Test func remainingTextUsesHoursFromOneHour() {
        #expect(DevelopingTicker.remainingText(until: now.addingTimeInterval(3600), now: now) == "1:00:00")
        #expect(DevelopingTicker.remainingText(until: now.addingTimeInterval(3725), now: now) == "1:02:05")
    }

    @Test func remainingTextRoundsUpAndNeverGoesNegative() {
        #expect(DevelopingTicker.remainingText(until: now.addingTimeInterval(0.2), now: now) == "00:01")
        #expect(DevelopingTicker.remainingText(until: now.addingTimeInterval(-30), now: now) == "00:00")
    }

    @Test func stageFollowsProgress() {
        #expect(DevelopingTicker.stage(progress: 0) == 1)
        #expect(DevelopingTicker.stage(progress: 0.32) == 1)
        #expect(DevelopingTicker.stage(progress: 0.34) == 2)
        #expect(DevelopingTicker.stage(progress: 0.67) == 3)
        #expect(DevelopingTicker.stage(progress: 1) == 3)
        #expect(DevelopingTicker.stage(progress: 5) == 3)
        #expect(DevelopingTicker.stage(progress: -1) == 1)
    }

    @Test func tankIDIsDerivedFromIndex() {
        #expect(DevelopingTicker.tankID(index: 0) == "A-1")
        #expect(DevelopingTicker.tankID(index: 4) == "B-2")
        #expect(DevelopingTicker.tankID(index: 9) == "A-1")
    }

    @Test func freeUserWaitsOnlyWhileAnotherRollDevelops() {
        #expect(DevelopingTicker.developAction(otherRollDeveloping: false, canDevelopInParallel: false) == .develop)
        #expect(DevelopingTicker.developAction(otherRollDeveloping: true, canDevelopInParallel: false) == .waitForPrevious)
        #expect(DevelopingTicker.developAction(otherRollDeveloping: true, canDevelopInParallel: true) == .develop)
    }

    @Test func developingRollBecomesDevelopedAfterTheDuration() throws {
        let env = AppEnvironment.preview()
        let roll = try env.repository.startRoll(stockID: "portra400")
        try env.repository.finishEarly(roll)
        let start = now.addingTimeInterval(-7200)
        try env.repository.startDeveloping(roll, canDevelopInParallel: false, now: start)

        let halfway = start.addingTimeInterval(RollRepository.developDuration / 2)
        #expect(roll.state(now: halfway) == .developing(progress: 0.5, readyAt: start.addingTimeInterval(RollRepository.developDuration)))
        #expect(try env.repository.developingCount(now: halfway) == 1)

        // Ticker pass after the duration: the repository stamps developedAt lazily.
        let rolls = try env.repository.rolls(now: now)
        #expect(rolls.first?.state(now: now) == .developed)
        #expect(roll.developedAt != nil)
        #expect(try env.repository.developingCount(now: now) == 0)
    }

    @Test func recentFramesSkipRollsThatAreNotDeveloped() throws {
        let env = AppEnvironment.preview()
        let developed = try env.repository.startRoll(stockID: "portra400")
        let developing = try env.repository.startRoll(stockID: "trix400")
        for roll in [developed, developing] {
            for index in 0 ..< 6 {
                roll.shots.append(Shot(index: index, imageFilename: "\(index).jpg", thumbnailFilename: "\(index)_t.jpg"))
            }
            try env.repository.finishEarly(roll)
        }
        try env.repository.startDeveloping(developed, canDevelopInParallel: true, now: now.addingTimeInterval(-7200))
        try env.repository.startDeveloping(developing, canDevelopInParallel: true, now: now.addingTimeInterval(-60))

        let recent = DevelopingTicker.recentFrames(from: [developed, developing], now: now)
        #expect(recent.count == 6)
        #expect(recent.allSatisfy { $0.roll?.id == developed.id })
        #expect(DevelopingTicker.recentFrames(from: [developed], now: now, limit: 4).count == 4)
    }
}
