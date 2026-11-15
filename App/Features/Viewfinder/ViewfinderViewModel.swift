import Observation
import SwiftUI
import UIKit

/// Logic of the camera screen (PLAN §9.4, §13.1). The repository is the source of truth for the roll;
/// every mutation is followed by `refresh()`.
@MainActor
@Observable
final class ViewfinderViewModel {
    enum State: Equatable {
        case loading, noPermission, noActiveRoll, ready, saving, rollFull, captureError
    }

    enum Lens: CaseIterable {
        case mm28, mm35, mm50

        var zoom: Double {
            switch self {
            case .mm28: 1.0
            case .mm35: 1.25
            case .mm50: 1.8
            }
        }

        var title: LocalizedStringKey {
            switch self {
            case .mm28: "28MM"
            case .mm35: "35MM 1X"
            case .mm50: "50MM"
            }
        }
    }

    struct PaywallRequest: Identifiable {
        let id = UUID()
        var stockID: String?
    }

    private(set) var state = State.loading
    /// The active roll, or the newest exposed one while it waits to be developed.
    private(set) var roll: Roll?
    private(set) var exposure: ExposureReadout?
    private(set) var flashMode = FlashMode.auto
    private(set) var lens = Lens.mm35
    /// Bumped after every capture; the view turns it into the black shutter flash.
    private(set) var flashCount = 0
    private(set) var errorMessage: LocalizedStringKey = ""
    var paywall: PaywallRequest?
    var showStockPicker = false

    private let env: AppEnvironment
    private let authorize: () async -> CameraAuthorizationStatus
    private var cameraReady = false

    init(env: AppEnvironment, authorize: (() async -> CameraAuthorizationStatus)? = nil) {
        self.env = env
        self.authorize = authorize ?? { [camera = env.camera] in
            // No sensor (simulator mock): there is nothing to ask permission for.
            guard camera.isAvailable else { return .authorized }
            let status = CameraAuthorization.current()
            guard status == .notDetermined else { return status }
            return await CameraAuthorization.request() ? .authorized : .denied
        }
    }

    // MARK: - Derived values

    var taken: Int { roll?.shots.count ?? 0 }
    var capacity: Int { roll?.capacity ?? 36 }
    var canShoot: Bool { state == .ready }
    var hasActiveRoll: Bool { state == .ready || state == .saving }
    /// The stock can only be swapped while no roll is in the camera.
    var canChangeStock: Bool { !hasActiveRoll && state != .loading && state != .noPermission }
    var canFinishEarly: Bool { state == .ready && taken > 0 }

    /// Stock of the roll in the camera, else the one that will be loaded next.
    var stock: FilmProfile {
        if hasActiveRoll, let roll, let profile = FilmCatalog.profile(id: roll.stockID) { return profile }
        return env.selectedStock
    }

    func isUnlocked(_ profile: FilmProfile) -> Bool { env.entitlements.isUnlocked(stockID: profile.id) }

    // MARK: - Lifecycle

    /// Returns true once the camera is running; otherwise `state` explains why.
    func start() async -> Bool {
        guard await authorize() == .authorized else {
            state = .noPermission
            return false
        }
        do {
            try await env.camera.start()
        } catch {
            fail("Camera unavailable")
            return false
        }
        await env.camera.setZoom(lens.zoom)
        await env.camera.setFlashMode(flashMode)
        cameraReady = true
        refresh()
        return true
    }

    func stop() async {
        cameraReady = false
        await env.camera.stop()
    }

    /// Runs while the screen is visible: starts the camera, polls the readout ~1/s, stops on cancellation.
    func run() async {
        guard await start() else { return }
        while !Task.isCancelled {
            exposure = await env.camera.exposureReadout()
            try? await Task.sleep(for: .seconds(1))
        }
        await stop()
    }

    func refresh() {
        do {
            roll = try env.repository.currentRoll() ?? env.repository.rolls().first { $0.state() == .exposed }
        } catch {
            fail("Could not read the film roll")
            return
        }
        guard cameraReady, state != .captureError else { return }
        switch roll?.state() {
        case .active: state = .ready
        case .exposed: state = .rollFull
        default: state = .noActiveRoll
        }
    }

    func openSettings() {
        guard let url = URL(string: UIApplication.openSettingsURLString) else { return }
        UIApplication.shared.open(url)
    }

    // MARK: - Camera controls

    func cycleFlash() async {
        flashMode = switch flashMode {
        case .auto: .on
        case .on: .off
        case .off: .auto
        }
        await env.camera.setFlashMode(flashMode)
    }

    func select(_ newLens: Lens) async {
        lens = newLens
        await env.camera.setZoom(newLens.zoom)
    }

    // MARK: - Shutter flow (PLAN §9.4)

    func shutter() async {
        guard state == .ready, let roll, case let .active(remaining) = roll.state(), remaining > 0 else { return }
        state = .saving
        Haptics.shutter()
        do {
            let raw = try await env.camera.capture()
            flashCount += 1
            let profile = FilmCatalog.profile(id: roll.stockID) ?? FilmCatalog.free
            let out = try await env.filmEngine.process(raw, profile: profile)
            _ = try await env.repository.appendShot(jpeg: out, to: roll)
        } catch {
            fail("Could not save the frame")
            return
        }
        state = .ready
        refresh()
    }

    func finishEarly() {
        guard canFinishEarly, let roll else { return }
        mutate { try env.repository.finishEarly(roll) }
    }

    func developNow() {
        guard let roll else { return }
        do {
            try env.repository.startDeveloping(roll, canDevelopInParallel: env.entitlements.canDevelopInParallel)
            refresh()
        } catch RollRepository.RollError.developingLimitReached {
            paywall = PaywallRequest()
        } catch {
            fail("Could not start developing")
        }
    }

    /// Loads the selected stock into a new roll; a locked stock opens the paywall instead.
    func loadSelectedStock() {
        let profile = env.selectedStock
        guard isUnlocked(profile) else {
            paywall = PaywallRequest(stockID: profile.id)
            return
        }
        mutate { _ = try env.repository.startRoll(stockID: profile.id) }
    }

    /// Stock picker: unlocked stocks become the next roll's stock, locked ones open the paywall.
    func choose(_ profile: FilmProfile) {
        guard canChangeStock else { return }
        showStockPicker = false
        if isUnlocked(profile) {
            env.selectedStockID = profile.id
        } else {
            paywall = PaywallRequest(stockID: profile.id)
        }
    }

    func dismissError() {
        state = cameraReady ? .ready : .loading
        refresh()
    }

    // MARK: - Private

    private func mutate(_ change: () throws -> Void) {
        do {
            try change()
            refresh()
        } catch {
            fail("Could not update the film roll")
        }
    }

    private func fail(_ message: LocalizedStringKey) {
        errorMessage = message
        state = .captureError
    }
}

extension ExposureReadout {
    /// `1/500s · f/2.8 · ISO 400`
    var displayText: String {
        let shutter = shutterSeconds < 1 ? "1/\(Int((1 / shutterSeconds).rounded()))s" : "\(Int(shutterSeconds.rounded()))s"
        return "\(shutter) · f/\(String(format: "%.1f", aperture)) · ISO \(Int(iso.rounded()))"
    }
}
