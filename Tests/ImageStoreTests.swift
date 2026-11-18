import Foundation
import SwiftData
import Testing
import UIKit
@testable import ROLL36

@MainActor
struct ImageStoreTests {
    private let directory = FileManager.default.temporaryDirectory
        .appending(path: "ROLL36ImageStoreTests-\(UUID().uuidString)", directoryHint: .isDirectory)
    private let store: ImageStore
    private let jpeg: Data

    init() throws {
        store = ImageStore(directory: directory)
        let size = CGSize(width: 1200, height: 800)
        jpeg = UIGraphicsImageRenderer(size: size).jpegData(withCompressionQuality: 0.8) { ctx in
            UIColor.orange.setFill()
            ctx.fill(CGRect(origin: .zero, size: size))
        }
    }

    /// After a successful save, both the original and thumbnail files exist on disk.
    @Test func atomicSaveWritesBothFiles() async throws {
        let id = UUID()
        let names = try await store.save(jpeg: jpeg, id: id)
        let originalData = try #require(await store.data(names.image))
        #expect(originalData == jpeg)
        let thumbData = try #require(await store.data(names.thumbnail))
        #expect(!thumbData.isEmpty)
        #expect(thumbData != jpeg)
    }

    /// After deleting a roll, its image files no longer exist on disk.
    @Test func deleteRollRemovesItsFiles() async throws {
        let container = try AppSchema.container(inMemory: true)
        let repo = RollRepository(context: ModelContext(container), imageStore: store)
        let roll = try repo.startRoll(stockID: "portra400")
        let shot = try await repo.appendShot(jpeg: jpeg, to: roll)

        // Both files exist
        #expect(await store.data(shot.imageFilename) != nil)
        #expect(await store.data(shot.thumbnailFilename) != nil)

        try await repo.delete(roll)

        // Neither file exists
        #expect(await store.data(shot.imageFilename) == nil)
        #expect(await store.data(shot.thumbnailFilename) == nil)
    }

    /// An unreferenced file in the directory is removed by orphan cleanup.
    @Test func orphanCleanupRemovesUnreferencedFiles() async throws {
        // Save a real shot
        let id = UUID()
        _ = try await store.save(jpeg: jpeg, id: id)

        // Write an orphan file that no Shot references
        let orphanURL = directory.appending(path: "orphan-\(UUID().uuidString).jpg", directoryHint: .notDirectory)
        try Data([0xFF, 0xD8, 0xFF]).write(to: orphanURL)

        // Confirm the orphan exists
        let filesBefore = await store.allFiles()
        #expect(filesBefore.contains(orphanURL.lastPathComponent))

        // Run cleanup with only the real shot's filenames referenced
        let referenced: Set<String> = ["\(id.uuidString).jpg", "\(id.uuidString)_thumb.jpg"]
        await store.cleanupOrphans(referenced: referenced)

        // Orphan is gone, referenced files remain
        let filesAfter = await store.allFiles()
        #expect(!filesAfter.contains(orphanURL.lastPathComponent))
        #expect(filesAfter.contains("\(id.uuidString).jpg"))
        #expect(filesAfter.contains("\(id.uuidString)_thumb.jpg"))
    }

    /// Orphan cleanup via RollRepository removes files not referenced by any Shot in the database.
    @Test func repositoryCleanupOrphansRemovesUnreferencedFiles() async throws {
        let container = try AppSchema.container(inMemory: true)
        let repo = RollRepository(context: ModelContext(container), imageStore: store)
        let roll = try repo.startRoll(stockID: "portra400")
        let shot = try await repo.appendShot(jpeg: jpeg, to: roll)

        // Write an orphan
        let orphanURL = directory.appending(path: "orphan-\(UUID().uuidString).jpg", directoryHint: .notDirectory)
        try Data([0xFF, 0xD8, 0xFF]).write(to: orphanURL)

        await repo.cleanupOrphans()

        let files = await store.allFiles()
        #expect(!files.contains(orphanURL.lastPathComponent))
        #expect(files.contains(shot.imageFilename))
        #expect(files.contains(shot.thumbnailFilename))
    }

    /// data() returns nil for a non-existent file instead of throwing.
    @Test func dataReturnsNilForMissingFile() async throws {
        #expect(await store.data("nonexistent-\(UUID().uuidString).jpg") == nil)
    }

    /// No temp (.tmp) files remain after a successful save.
    @Test func noTempFilesRemainAfterSave() async throws {
        _ = try await store.save(jpeg: jpeg, id: UUID())
        let files = await store.allFiles()
        #expect(!files.contains(where: { $0.hasSuffix(".tmp") }))
    }
}
