import Foundation
@testable import ROLL36
import Testing

@MainActor
struct ViewfinderViewModelTests {
    private let env = AppEnvironment.preview()

    private func makeModel(status: CameraAuthorizationStatus = .authorized) async -> ViewfinderViewModel {
        let model = ViewfinderViewModel(env: env, authorize: { status })
        _ = await model.start()
        return model
    }

    @Test func noRollStartsInNoActiveRollThenLoadingARollMakesItReady() async throws {
        let model = await makeModel()
        #expect(model.state == .noActiveRoll)
        #expect(!model.canShoot)

        model.loadSelectedStock()
        #expect(model.state == .ready)
        #expect(model.taken == 0)
        #expect(model.capacity == 36)
        #expect(try env.repository.currentRoll()?.stockID == FilmCatalog.free.id)
    }

    @Test func lockedStockCannotBeLoaded() async throws {
        let locked = try #require(FilmCatalog.all.first { !env.entitlements.isUnlocked(stockID: $0.id) })
        env.selectedStockID = locked.id
        let model = await makeModel()

        model.loadSelectedStock()
        #expect(model.state == .noActiveRoll)
        #expect(model.paywall?.stockID == locked.id)
        #expect(try env.repository.currentRoll() == nil)
    }

    @Test func pickerOpensPaywallForLockedAndSelectsUnlocked() async throws {
        let locked = try #require(FilmCatalog.all.first { !env.entitlements.isUnlocked(stockID: $0.id) })
        let model = await makeModel()

        model.choose(locked)
        #expect(model.paywall?.stockID == locked.id)
        #expect(env.selectedStockID != locked.id)

        model.choose(FilmCatalog.free)
        #expect(env.selectedStockID == FilmCatalog.free.id)
    }

    @Test func stockCannotChangeWhileRollIsActive() async {
        let model = await makeModel()
        #expect(model.canChangeStock)
        model.loadSelectedStock()
        #expect(!model.canChangeStock)
    }

    @Test func deniedPermissionShowsNoPermissionAndDoesNotStartCamera() async {
        let model = await makeModel(status: .denied)
        #expect(model.state == .noPermission)
        #expect(!model.canShoot)
    }

    @Test func finishEarlyNeedsAShotThenExposesTheRoll() async throws {
        let model = await makeModel()
        model.loadSelectedStock()
        #expect(!model.canFinishEarly)

        await model.shutter()
        await model.awaitPending()
        #expect(model.taken == 1)
        #expect(model.canFinishEarly)

        model.finishEarly()
        #expect(model.state == .rollFull)
        #expect(model.roll?.state() == .exposed)
    }

    @Test(.timeLimit(.minutes(5)))
    func thirtySixShuttersFillTheRoll() async throws {
        let model = await makeModel()
        model.loadSelectedStock()
        let roll = try #require(model.roll)

        for expected in 1 ... 36 {
            #expect(model.canShoot)
            await model.shutter()
            await model.awaitPending()
            #expect(model.taken == expected)
        }

        #expect(roll.state() == .exposed)
        #expect(model.state == .rollFull)
        #expect(!model.canShoot)

        await model.shutter() // ignored: roll is full
        await model.awaitPending()
        #expect(roll.shots.count == 36)

        model.developNow()
        #expect(roll.state() != .exposed)
        #expect(model.state == .noActiveRoll)
    }

    @Test func shutterReleasesBeforeTheFrameIsSavedAndFinishEarlyWaits() async throws {
        let model = await makeModel()
        model.loadSelectedStock()
        let roll = try #require(model.roll)

        await model.shutter()
        // Back to ready with the frame still in the queue: counted, but not on the roll yet.
        #expect(model.state == .ready)
        #expect(model.pending == 1)
        #expect(model.taken == 0)
        #expect(model.exposedCount == 1)
        #expect(!model.canFinishEarly)
        model.finishEarly() // refused while a frame is being written
        #expect(roll.state() != .exposed)

        await model.awaitPending()
        #expect(model.pending == 0)
        #expect(roll.shots.count == 1)
        #expect(model.canFinishEarly)
    }

    @Test(.timeLimit(.minutes(5)))
    func rapidFireNeverExceedsCapacityAndKeepsIndicesContiguous() async throws {
        let model = await makeModel()
        _ = try env.repository.startRoll(stockID: FilmCatalog.free.id, capacity: 5)
        model.refresh()
        #expect(model.capacity == 5)

        for _ in 0 ..< 12 {
            await model.shutter()
            #expect(model.exposedCount <= 5)
            #expect(model.pending <= 3)
        }
        await model.awaitPending()
        while model.canShoot {
            await model.shutter()
            await model.awaitPending()
        }

        let active = try #require(model.roll)
        #expect(model.pending == 0)
        #expect(active.shots.map(\.index).sorted() == Array(0 ..< 5))
        #expect(model.state == .rollFull)
    }

    @Test func failedFrameIsReportedAndReleasesItsPendingSlot() async throws {
        let failing = AppEnvironment(
            modelContainer: try AppSchema.container(inMemory: true),
            imageStore: ImageStore(directory: FileManager.default.temporaryDirectory.appending(path: "roll36-\(UUID().uuidString)")),
            entitlements: EntitlementStore(defaults: UserDefaults(suiteName: "test-\(UUID().uuidString)") ?? .standard),
            camera: GarbageCamera()
        )
        let model = ViewfinderViewModel(env: failing, authorize: { .authorized })
        _ = await model.start()
        model.loadSelectedStock()

        await model.shutter()
        #expect(model.pending == 1)
        await model.awaitPending()

        #expect(model.pending == 0)
        #expect(model.exposedCount == 0)
        #expect(model.state == .captureError)
        model.dismissError()
        #expect(model.canShoot)
    }

    @Test func closedRollShowsTheWaitAndDoesNotBlockLoadingAnotherRoll() async throws {
        let earlier = try env.repository.startRoll(stockID: FilmCatalog.free.id)
        try env.repository.finishEarly(earlier)
        try env.repository.startDeveloping(earlier, canDevelopInParallel: false)

        let model = await makeModel()
        model.loadSelectedStock()
        await model.shutter()
        await model.awaitPending()
        model.finishEarly()
        #expect(model.state == .rollFull)
        #expect(model.waitingUntil != nil)
        #expect(model.canLoadWhileClosed)

        model.loadSelectedStock()
        #expect(model.state == .ready)
        #expect(model.taken == 0)
    }

    @Test func exposureReadoutFormatting() {
        #expect(ExposureReadout(shutterSeconds: 1.0 / 500, aperture: 2.8, iso: 400).displayText == "1/500s · f/2.8 · ISO 400")
    }
}

/// Returns bytes the film engine cannot decode, so the queued frame fails.
private actor GarbageCamera: CameraService {
    nonisolated let isAvailable = false
    func start() async throws {}
    func stop() async {}
    func capture() async throws -> Data { Data([0, 1, 2, 3]) }
    func setFlashMode(_: FlashMode) async {}
    func setZoom(_: Double) async {}
    func focus(atNormalizedPoint _: CGPoint?) async {}
    func setExposureBias(_: Double) async {}
    func exposureReadout() async -> ExposureReadout? { nil }
}
