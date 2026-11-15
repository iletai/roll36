import AVFoundation

nonisolated enum CameraAuthorizationStatus {
    case notDetermined, authorized, denied, restricted
}

nonisolated enum CameraAuthorization {
    static func current() -> CameraAuthorizationStatus {
        switch AVCaptureDevice.authorizationStatus(for: .video) {
        case .authorized: .authorized
        case .denied: .denied
        case .restricted: .restricted
        case .notDetermined: .notDetermined
        @unknown default: .denied
        }
    }

    /// Shows the system prompt only when `.notDetermined`; otherwise returns the stored answer.
    static func request() async -> Bool {
        await AVCaptureDevice.requestAccess(for: .video)
    }
}
