import Foundation
import Observation
import os
import SwiftData

/// DI container: one instance per launch, injected with `.environment(env)`; read with `@Environment(AppEnvironment.self)`.
@Observable
final class AppEnvironment {
    let modelContainer: ModelContainer
    let imageStore: ImageStore
    let repository: RollRepository
    let filmEngine: FilmEngine
    let entitlements: EntitlementStore
    let purchases: PurchaseService
    let camera: any CameraService
    let importQuota: ImportQuota
    /// PLAN §9.3: real-time LUT preview, off until it is measured at >= 24 FPS on device.
    let liveLUTPreview = false

    /// Stock loaded into the next roll; changing it never touches a roll that is already shooting.
    var selectedStockID: String {
        didSet { defaults.set(selectedStockID, forKey: Self.selectedStockKey) }
    }

    private let defaults: UserDefaults
    private static let selectedStockKey = "selectedStockID"

    init(
        modelContainer: ModelContainer,
        imageStore: ImageStore,
        entitlements: EntitlementStore,
        camera: any CameraService,
        defaults: UserDefaults = .standard
    ) {
        self.modelContainer = modelContainer
        self.imageStore = imageStore
        self.repository = RollRepository(context: modelContainer.mainContext, imageStore: imageStore)
        self.filmEngine = FilmEngine()
        self.entitlements = entitlements
        self.purchases = PurchaseService(entitlements: entitlements)
        self.camera = camera
        self.importQuota = ImportQuota(defaults: defaults)
        self.defaults = defaults
        let saved = defaults.string(forKey: Self.selectedStockKey)
        self.selectedStockID = saved.flatMap(FilmCatalog.profile(id:))?.id ?? FilmCatalog.free.id
    }

    var selectedStock: FilmProfile {
        FilmCatalog.profile(id: selectedStockID) ?? FilmCatalog.free
    }

    /// Production wiring. Falls back to an in-memory store if the on-disk one cannot be opened, so the app still launches.
    static func live() -> AppEnvironment {
        let container: ModelContainer
        do {
            container = try AppSchema.container()
        } catch {
            Log.app.error("SwiftData store failed to open, using in-memory: \(error)")
            container = (try? AppSchema.container(inMemory: true)) ?? { preconditionFailure("SwiftData unavailable") }()
        }
        let env = AppEnvironment(
            modelContainer: container,
            imageStore: ImageStore(),
            entitlements: EntitlementStore(),
            camera: CameraServiceFactory.makeService()
        )
        env.entitlements.startListening()
        return env
    }

    /// In-memory wiring with the mock camera and an isolated image directory, for previews and tests.
    static func preview() -> AppEnvironment {
        let suite = "preview-\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suite) ?? .standard
        let directory = FileManager.default.temporaryDirectory.appending(path: "roll36-preview-\(UUID().uuidString)")
        return AppEnvironment(
            modelContainer: (try? AppSchema.container(inMemory: true)) ?? { preconditionFailure("SwiftData unavailable") }(),
            imageStore: ImageStore(directory: directory),
            entitlements: EntitlementStore(defaults: defaults),
            camera: MockCameraService(),
            defaults: defaults
        )
    }
}
