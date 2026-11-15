import Foundation
import SwiftData
import Testing
import UIKit
@testable import ROLL36

@MainActor
struct RollRepositoryTests {
    private let directory = FileManager.default.temporaryDirectory
        .appending(path: "ROLL36Tests-\(UUID().uuidString)", directoryHint: .isDirectory)
    private let container: ModelContainer // must outlive the context
    private let store: ImageStore
    private let repo: RollRepository
    private let jpeg: Data

    init() throws {
        store = ImageStore(directory: directory)
        container = try AppSchema.container(inMemory: true)
        repo = RollRepository(context: ModelContext(container), imageStore: store)
        let size = CGSize(width: 1200, height: 800)
        jpeg = UIGraphicsImageRenderer(size: size).jpegData(withCompressionQuality: 0.8) { ctx in
            UIColor.orange.setFill()
            ctx.fill(CGRect(origin: .zero, size: size))
        }
    }

    private func fillRoll(_ roll: Roll) async throws {
        for _ in 0 ..< roll.capacity {
            _ = try await repo.appendShot(jpeg: jpeg, to: roll)
        }
    }

    private func fileCount() -> Int {
        (try? FileManager.default.contentsOfDirectory(atPath: directory.path).count) ?? 0
    }

    @Test func thirtySixShotsExposeAndThirtySeventhThrows() async throws {
        let roll = try repo.startRoll(stockID: "portra400")
        try await fillRoll(roll)
        #expect(roll.state() == .exposed)
        #expect(roll.finishedAt != nil)
        #expect(roll.shots.map(\.index).sorted() == Array(0 ..< 36))
        await #expect(throws: RollRepository.RollError.rollFull) {
            _ = try await repo.appendShot(jpeg: jpeg, to: roll)
        }
        #expect(try repo.currentRoll() == nil)
    }

    @Test func shotStoresFilenamesAndThumbnailIsDownsampled() async throws {
        let roll = try repo.startRoll(stockID: "portra400")
        let shot = try await repo.appendShot(jpeg: jpeg, to: roll)
        #expect(!shot.imageFilename.contains("/"))
        #expect(try await store.data(shot.imageFilename) == jpeg)
        let thumbData = try await store.data(shot.thumbnailFilename)
        let thumb = try #require(UIImage(data: thumbData))
        #expect(max(thumb.size.width, thumb.size.height) * thumb.scale <= 600)
    }

    @Test func currentRollAndFinishEarly() async throws {
        let roll = try repo.startRoll(stockID: "portra400")
        #expect(try repo.currentRoll() === roll)
        try repo.finishEarly(roll)
        #expect(roll.state() == .exposed)
        #expect(try repo.currentRoll() == nil)
    }

    @Test func freeLimitBlocksSecondDevelopingRoll() throws {
        let first = try repo.startRoll(stockID: "a", capacity: 1)
        let second = try repo.startRoll(stockID: "b", capacity: 1)
        try repo.finishEarly(first)
        try repo.finishEarly(second)
        try repo.startDeveloping(first, canDevelopInParallel: false)
        #expect(throws: RollRepository.RollError.developingLimitReached) {
            try repo.startDeveloping(second, canDevelopInParallel: false)
        }
        try repo.startDeveloping(second, canDevelopInParallel: true)
        #expect(try repo.developingCount() == 2)
    }

    @Test func startDevelopingRequiresExposed() throws {
        let roll = try repo.startRoll(stockID: "a")
        #expect(throws: RollRepository.RollError.notExposed) {
            try repo.startDeveloping(roll, canDevelopInParallel: true)
        }
    }

    @Test func rollsStampsDevelopedAtLazily() throws {
        let roll = try repo.startRoll(stockID: "a")
        try repo.finishEarly(roll)
        let start = Date()
        try repo.startDeveloping(roll, canDevelopInParallel: false, now: start)
        _ = try repo.rolls(now: start.addingTimeInterval(60))
        #expect(roll.developedAt == nil)
        _ = try repo.rolls(now: start.addingTimeInterval(3601))
        #expect(roll.developedAt == start.addingTimeInterval(3600))
    }

    @Test func deleteAllRemovesFiles() async throws {
        let roll = try repo.startRoll(stockID: "portra400")
        _ = try await repo.appendShot(jpeg: jpeg, to: roll)
        _ = try await repo.appendImport(jpeg: jpeg, stockID: "portra400")
        #expect(fileCount() == 4)
        try await repo.deleteAll()
        #expect(fileCount() == 0)
        #expect(try repo.rolls().isEmpty)
    }

    @Test func deleteRollRemovesItsFilesOnly() async throws {
        let doomed = try repo.startRoll(stockID: "a")
        let kept = try repo.startRoll(stockID: "b")
        _ = try await repo.appendShot(jpeg: jpeg, to: doomed)
        _ = try await repo.appendShot(jpeg: jpeg, to: kept)
        try await repo.delete(doomed)
        #expect(fileCount() == 2)
        #expect(try repo.rolls().count == 1)
    }

    @Test func importRollStaysDevelopedAndLeavesOtherRollsAlone() async throws {
        let roll = try repo.startRoll(stockID: "portra400")
        _ = try await repo.appendShot(jpeg: jpeg, to: roll)

        let shot = try await repo.appendImport(jpeg: jpeg, stockID: "trix400")
        let imports = try repo.importRoll()
        #expect(shot.isImported)
        #expect(imports.shots.count == 1)
        #expect(imports.state() == .developed)
        #expect(try repo.importRoll() === imports)
        #expect(roll.shots.count == 1)
        #expect(roll.state() == .active(remaining: 35))
        #expect(try repo.rolls().count == 1)
        #expect(try repo.currentRoll() === roll)
    }
}
