import CoreGraphics
@testable import ROLL36
import Testing

struct FocusExposureTests {
    @Test func mockRecordsFocusPointsAndReset() async {
        let camera = MockCameraService()
        await camera.focus(atNormalizedPoint: CGPoint(x: 0.25, y: 0.75))
        await camera.focus(atNormalizedPoint: nil)
        let points = await camera.focusPoints
        #expect(points == [CGPoint(x: 0.25, y: 0.75), nil])
    }

    @Test func mockRecordsClampedBias() async {
        let camera = MockCameraService()
        await camera.setExposureBias(0.5)
        await camera.setExposureBias(5)
        await camera.setExposureBias(-5)
        #expect(await camera.exposureBiases == [0.5, 2, -2])
    }

    @Test(arguments: [(0.0, 0.0), (0.1, 0.0), (0.2, 1.0 / 3), (0.5, 2.0 / 3), (-0.5, -2.0 / 3), (9.0, 2.0), (-9.0, -2.0)])
    func biasSnapsToThirdsAndClamps(input: Double, expected: Double) {
        #expect(abs(ExposureBias.snapped(input) - expected) < 1e-9)
    }

    @Test func previewPointMapsToPortraitSensorSpace() {
        // Top-left of the preview is the top-right corner of the landscape-right sensor.
        #expect(ExposureBias.devicePoint(fromPreview: CGPoint(x: 0, y: 0)) == CGPoint(x: 0, y: 1))
        #expect(ExposureBias.devicePoint(fromPreview: CGPoint(x: 1, y: 0)) == CGPoint(x: 0, y: 0))
        #expect(ExposureBias.devicePoint(fromPreview: CGPoint(x: 0.25, y: 0.75)) == CGPoint(x: 0.75, y: 0.75))
        #expect(ExposureBias.devicePoint(fromPreview: CGPoint(x: 2, y: -1)) == CGPoint(x: 0, y: 0))
    }
}
