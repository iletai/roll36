import Testing
@testable import ROLL36

struct FramingAidsTests {
    @Test func levelThresholdBoundaries() {
        #expect(HorizonLevel.compute(roll: 0, pitch: 0).isLevel)
        #expect(HorizonLevel.compute(roll: 1.5, pitch: 0).isLevel)
        #expect(HorizonLevel.compute(roll: -1.5, pitch: 0).isLevel)
        #expect(!HorizonLevel.compute(roll: 1.51, pitch: 0).isLevel)
        #expect(!HorizonLevel.compute(roll: -1.51, pitch: 0).isLevel)
    }

    @Test func hiddenWhenPointingFlat() {
        #expect(HorizonLevel.compute(roll: 0, pitch: 60).isVisible)
        #expect(HorizonLevel.compute(roll: 0, pitch: -60).isVisible)
        #expect(!HorizonLevel.compute(roll: 0, pitch: 60.1).isVisible)
        #expect(!HorizonLevel.compute(roll: 0, pitch: -90).isVisible)
        // A flat phone is never reported as level, even at zero roll.
        #expect(!HorizonLevel.compute(roll: 0, pitch: 90).isLevel)
    }

    @Test func lineRotatesOppositeToRoll() {
        #expect(HorizonLevel.compute(roll: 10, pitch: 0).angle == -10)
        #expect(HorizonLevel.compute(roll: -25, pitch: 0).angle == 25)
    }
}
