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
            #expect(model.taken == expected)
        }

        #expect(roll.state() == .exposed)
        #expect(model.state == .rollFull)
        #expect(!model.canShoot)

        await model.shutter() // ignored: roll is full
        #expect(roll.shots.count == 36)

        model.developNow()
        #expect(roll.state() != .exposed)
        #expect(model.state == .noActiveRoll)
    }

    @Test func exposureReadoutFormatting() {
        #expect(ExposureReadout(shutterSeconds: 1.0 / 500, aperture: 2.8, iso: 400).displayText == "1/500s · f/2.8 · ISO 400")
    }
}
