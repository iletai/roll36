import Foundation
@testable import ROLL36
import Testing

@MainActor
struct ImportViewModelTests {
    private let env = AppEnvironment.preview()

    private func makeModel(stock: FilmProfile = FilmCatalog.free) async throws -> ImportViewModel {
        let camera = MockCameraService()
        try await camera.start()
        let model = ImportViewModel(env: env)
        try await model.load(await camera.capture())
        model.select(stock)
        return model
    }

    private func importedCount() throws -> Int {
        try env.repository.importRoll().shots.count
    }

    @Test func developAddsShotAndConsumesQuota() async throws {
        let model = try await makeModel()
        #expect(model.phase == .ready)
        #expect(model.remaining == ImportQuota.freeLimit)

        await model.develop()
        #expect(model.phase == .developed)
        #expect(model.paywall == nil)
        #expect(try importedCount() == 1)
        #expect(model.remaining == ImportQuota.freeLimit - 1)
        #expect(env.importQuota.remaining(isUnlocked: false) == ImportQuota.freeLimit - 1)
    }

    @Test func sixthFreeImportRoutesToPaywall() async throws {
        for _ in 0 ..< ImportQuota.freeLimit {
            env.importQuota.recordImport()
        }
        let model = try await makeModel()
        #expect(model.remaining == 0)

        await model.develop()
        #expect(model.paywall != nil)
        #expect(model.phase == .ready)
        #expect(try importedCount() == 0)
    }

    @Test func lockedStockRoutesToPaywallButPreviews() async throws {
        let locked = try #require(FilmCatalog.all.first { !env.entitlements.isUnlocked(stockID: $0.id) })
        let model = try await makeModel(stock: locked)
        #expect(model.stock.id == locked.id)

        await model.develop()
        #expect(model.paywall?.stockID == locked.id)
        #expect(model.phase == .ready)
        #expect(try importedCount() == 0)
        #expect(env.importQuota.remaining(isUnlocked: false) == ImportQuota.freeLimit)
    }

    @Test func failedDevelopDoesNotConsumeQuota() async throws {
        let model = ImportViewModel(env: env)
        await model.load(Data("not an image".utf8))
        #expect(model.phase == .empty)
        #expect(model.errorMessage != nil)

        await model.develop()
        #expect(env.importQuota.remaining(isUnlocked: false) == ImportQuota.freeLimit)
        #expect(try importedCount() == 0)
    }

    @Test func saveFailureDoesNotConsumeQuota() async throws {
        // The image directory sits under a regular file, so storing the developed frame throws.
        let blocker = FileManager.default.temporaryDirectory.appending(path: "roll36-blocker-\(UUID().uuidString)")
        try Data().write(to: blocker)
        let suite = "import-fail-\(UUID().uuidString)"
        let defaults = try #require(UserDefaults(suiteName: suite))
        let failing = try AppEnvironment(
            modelContainer: AppSchema.container(inMemory: true),
            imageStore: ImageStore(directory: blocker.appending(path: "frames")),
            entitlements: EntitlementStore(defaults: defaults),
            camera: MockCameraService(),
            defaults: defaults
        )
        let camera = MockCameraService()
        try await camera.start()
        let model = ImportViewModel(env: failing)
        try await model.load(await camera.capture())

        await model.develop()
        #expect(model.phase == .ready)
        #expect(model.errorMessage != nil)
        #expect(failing.importQuota.remaining(isUnlocked: false) == ImportQuota.freeLimit)
    }

    @Test func previewReplacesOriginalAndLatestStockWins() async throws {
        let model = try await makeModel()
        let original = model.image
        model.select(FilmCatalog.trix400)
        model.select(FilmCatalog.portra400)
        await model.previewTask?.value
        #expect(model.stock.id == FilmCatalog.portra400.id)
        #expect(!model.isPreviewing)
        #expect(model.image !== original)
    }
}
