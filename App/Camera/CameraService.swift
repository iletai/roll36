import CoreGraphics
import Foundation

/// Camera abstraction (PLAN §9.2). Nonisolated so actor-based implementations can conform.
nonisolated protocol CameraService: AnyObject, Sendable {
    var isAvailable: Bool { get }
    func start() async throws
    func stop() async
    /// JPEG straight from the sensor, upright portrait.
    func capture() async throws -> Data
    func setFlashMode(_ mode: FlashMode) async
    /// Digital crop for the 28/35/50mm chips; clamped to device limits.
    func setZoom(_ factor: Double) async
    /// Focus and meter at a point normalized to the preview (0...1, origin top-left, portrait).
    /// nil resets to continuous auto focus/exposure at the centre.
    func focus(atNormalizedPoint point: CGPoint?) async
    /// Exposure compensation in EV; clamped to `ExposureBias.range` and the device limits.
    func setExposureBias(_ ev: Double) async
    /// nil if unknown.
    func exposureReadout() async -> ExposureReadout?
}

nonisolated enum ExposureBias {
    static let range: ClosedRange<Double> = -2 ... 2
    static let step = 1.0 / 3

    /// Rounds to the nearest 1/3 EV step and clamps to `range`.
    static func snapped(_ ev: Double) -> Double {
        min(max((ev / step).rounded() * step, range.lowerBound), range.upperBound)
    }

    /// Preview point (0...1, top-left origin, portrait) to AVCaptureDevice point-of-interest space.
    /// The sensor is landscape-right, so device x = view y and device y = 1 - view x.
    static func devicePoint(fromPreview point: CGPoint) -> CGPoint {
        CGPoint(x: min(max(point.y, 0), 1), y: min(max(1 - point.x, 0), 1))
    }
}

nonisolated enum FlashMode: String, Sendable, CaseIterable {
    case auto, on, off
}

nonisolated struct ExposureReadout: Sendable, Equatable {
    var shutterSeconds: Double
    var aperture: Double
    var iso: Double
}

nonisolated enum CameraError: Error {
    case notAuthorized, unavailable, captureFailed, interrupted
}

enum CameraServiceFactory {
    /// Mock on the simulator (no camera there), AVFoundation on device.
    static func makeService() -> any CameraService {
        #if targetEnvironment(simulator)
            MockCameraService()
        #else
            LiveCameraService()
        #endif
    }
}
