// AVFoundation predates Sendable annotations; the session is shared with the preview layer
// the way Apple's AVCam sample does (see `connectPreview`).
@preconcurrency import AVFoundation
import os
import Synchronization

/// Real camera. Every AVFoundation call runs on the actor's own serial queue, so the
/// blocking `startRunning()` never touches the main thread or the cooperative pool.
actor LiveCameraService: CameraService {
    private nonisolated let queue = DispatchSerialQueue(label: "roll36.camera.session")
    nonisolated var unownedExecutor: UnownedSerialExecutor { queue.asUnownedSerialExecutor() }

    // Only touched on `queue`, except `connectPreview` which hands it to the preview layer.
    private nonisolated let session = AVCaptureSession()
    private let photoOutput = AVCapturePhotoOutput()
    private var device: AVCaptureDevice?
    private var isConfigured = false
    private var wantsRunning = false
    private var isInterrupted = false
    private var flashMode: AVCaptureDevice.FlashMode = .auto

    nonisolated let isAvailable: Bool

    init() {
        isAvailable = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .back) != nil
    }

    /// Main-actor path for the preview: AVCaptureVideoPreviewLayer is built to read the session
    /// from the main thread while the session runs on its own queue.
    @MainActor func connectPreview(_ layer: AVCaptureVideoPreviewLayer) {
        layer.session = session
    }

    func start() async throws {
        guard CameraAuthorization.current() == .authorized else { throw CameraError.notAuthorized }
        if !isConfigured { try configure() }
        wantsRunning = true
        if !session.isRunning { session.startRunning() }
    }

    func stop() async {
        wantsRunning = false
        if session.isRunning { session.stopRunning() }
    }

    func capture() async throws -> Data {
        guard session.isRunning else { throw CameraError.unavailable }
        guard !isInterrupted else { throw CameraError.interrupted }

        let settings = photoOutput.availablePhotoCodecTypes.contains(.jpeg)
            ? AVCapturePhotoSettings(format: [AVVideoCodecKey: AVVideoCodecType.jpeg])
            : AVCapturePhotoSettings()
        settings.maxPhotoDimensions = photoOutput.maxPhotoDimensions
        settings.flashMode = photoOutput.supportedFlashModes.contains(flashMode) ? flashMode : .off
        // Portrait-only app: rotate the back camera's landscape sensor to upright.
        if let connection = photoOutput.connection(with: .video), connection.isVideoRotationAngleSupported(90) {
            connection.videoRotationAngle = 90
        }

        // The photo output holds its delegate weakly; keep it alive until the capture resolves.
        let delegate = PhotoCaptureDelegate()
        defer { withExtendedLifetime(delegate) {} }
        return try await withCheckedThrowingContinuation { continuation in
            delegate.setContinuation(continuation)
            photoOutput.capturePhoto(with: settings, delegate: delegate)
        }
    }

    func setFlashMode(_ mode: FlashMode) async {
        flashMode = switch mode {
        case .auto: .auto
        case .on: .on
        case .off: .off
        }
    }

    func setZoom(_ factor: Double) async {
        guard let device else { return }
        let clamped = min(max(CGFloat(factor), device.minAvailableVideoZoomFactor), device.maxAvailableVideoZoomFactor)
        do {
            try device.lockForConfiguration()
            device.videoZoomFactor = clamped
            device.unlockForConfiguration()
        } catch {
            Log.camera.error("zoom lock failed: \(error.localizedDescription)")
        }
    }

    func exposureReadout() async -> ExposureReadout? {
        guard let device, device.exposureDuration.isNumeric else { return nil }
        return ExposureReadout(
            shutterSeconds: device.exposureDuration.seconds,
            aperture: Double(device.lensAperture),
            iso: Double(device.iso)
        )
    }

    // MARK: - Setup

    private func configure() throws {
        guard let device = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .back),
              let input = try? AVCaptureDeviceInput(device: device)
        else { throw CameraError.unavailable }

        session.beginConfiguration()
        defer { session.commitConfiguration() }
        session.sessionPreset = .photo
        guard session.canAddInput(input), session.canAddOutput(photoOutput) else { throw CameraError.unavailable }
        session.addInput(input)
        session.addOutput(photoOutput)
        if let largest = device.activeFormat.supportedMaxPhotoDimensions.max(by: { $0.width * $0.height < $1.width * $1.height }) {
            photoOutput.maxPhotoDimensions = largest
        }
        self.device = device
        isConfigured = true
        observeSession()
    }

    // shortcut: observers live as long as the service (one per app), so they are never removed.
    private func observeSession() {
        let center = NotificationCenter.default
        center.addObserver(forName: AVCaptureSession.wasInterruptedNotification, object: session, queue: nil) { [weak self] note in
            let reason = (note.userInfo?[AVCaptureSessionInterruptionReasonKey] as? Int) ?? -1
            Task { await self?.interruptionBegan(reason: reason) }
        }
        center.addObserver(forName: AVCaptureSession.interruptionEndedNotification, object: session, queue: nil) { [weak self] _ in
            Task { await self?.resumeIfNeeded() }
        }
        center.addObserver(forName: AVCaptureSession.runtimeErrorNotification, object: session, queue: nil) { [weak self] note in
            let message = (note.userInfo?[AVCaptureSessionErrorKey] as? NSError)?.localizedDescription ?? "unknown"
            Log.camera.error("session runtime error: \(message)")
            Task { await self?.resumeIfNeeded() }
        }
    }

    private func interruptionBegan(reason: Int) {
        Log.camera.info("session interrupted, reason \(reason)")
        isInterrupted = true
    }

    private func resumeIfNeeded() {
        isInterrupted = false
        if wantsRunning, !session.isRunning { session.startRunning() }
    }
}

/// Bridges one photo capture to async. Delegate callbacks arrive on an AVFoundation queue,
/// so the continuation sits behind a Mutex and is resumed exactly once.
private final nonisolated class PhotoCaptureDelegate: NSObject, AVCapturePhotoCaptureDelegate, Sendable {
    private let continuation = Mutex<CheckedContinuation<Data, any Error>?>(nil)

    func setContinuation(_ value: CheckedContinuation<Data, any Error>) {
        continuation.withLock { $0 = value }
    }

    func photoOutput(_: AVCapturePhotoOutput, didFinishProcessingPhoto photo: AVCapturePhoto, error: (any Error)?) {
        if let error {
            finish(.failure(error))
        } else if let data = photo.fileDataRepresentation() {
            finish(.success(data))
        } else {
            finish(.failure(CameraError.captureFailed))
        }
    }

    func photoOutput(_: AVCapturePhotoOutput, didFinishCaptureFor _: AVCaptureResolvedPhotoSettings, error: (any Error)?) {
        // No-op if the photo callback already resumed.
        finish(.failure(error ?? CameraError.captureFailed))
    }

    private func finish(_ result: Result<Data, any Error>) {
        let pending = continuation.withLock { value in
            defer { value = nil }
            return value
        }
        pending?.resume(with: result)
    }
}
