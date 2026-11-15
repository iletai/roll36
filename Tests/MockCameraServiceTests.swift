import Foundation
import ImageIO
@testable import ROLL36
import Testing

struct MockCameraServiceTests {
    @Test func captureReturnsDecodableJPEGWithExpectedSize() async throws {
        let camera = MockCameraService()
        try await camera.start()
        let data = try await camera.capture()

        let source = try #require(CGImageSourceCreateWithData(data as CFData, nil))
        #expect(CGImageSourceGetType(source) as String? == "public.jpeg")
        let image = try #require(CGImageSourceCreateImageAtIndex(source, 0, nil))
        #expect(image.width == MockCameraService.width)
        #expect(image.height == MockCameraService.height)
    }

    @Test func consecutiveCapturesDiffer() async throws {
        let camera = MockCameraService()
        try await camera.start()
        let first = try await camera.capture()
        let second = try await camera.capture()
        #expect(first != second)
    }

    @Test func startAndStopAreIdempotent() async throws {
        let camera = MockCameraService()
        try await camera.start()
        try await camera.start()
        _ = try await camera.capture()

        await camera.stop()
        await camera.stop()
        await #expect(throws: CameraError.self) { try await camera.capture() }

        try await camera.start()
        _ = try await camera.capture()
    }

    @Test func exposureReadoutMatchesDesign() async {
        let readout = await MockCameraService().exposureReadout()
        #expect(readout == ExposureReadout(shutterSeconds: 1.0 / 500, aperture: 2.8, iso: 400))
    }
}
