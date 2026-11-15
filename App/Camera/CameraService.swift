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
    /// nil if unknown.
    func exposureReadout() async -> ExposureReadout?
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
