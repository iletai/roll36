import Foundation
import SwiftData

enum AppSchema {
    static func container(inMemory: Bool = false) throws -> ModelContainer {
        try ModelContainer(
            for: Roll.self, Shot.self,
            configurations: ModelConfiguration(isStoredInMemoryOnly: inMemory)
        )
    }
}

@MainActor
final class RollRepository {
    enum RollError: Error { case rollFull, notExposed, developingLimitReached }

    static let developDuration: TimeInterval = 3600
    static let importStockID = "import"

    private let context: ModelContext
    private let imageStore: ImageStore

    init(context: ModelContext, imageStore: ImageStore) {
        self.context = context
        self.imageStore = imageStore
    }

    func currentRoll() throws -> Roll? {
        try fetchRolls().first { if case .active = $0.state() { true } else { false } }
    }

    func startRoll(stockID: String, capacity: Int = 36) throws -> Roll {
        let roll = Roll(stockID: stockID, capacity: capacity, developDuration: Self.developDuration)
        context.insert(roll)
        try context.save()
        return roll
    }

    func appendShot(jpeg: Data, to roll: Roll) async throws -> Shot {
        guard case .active = roll.state() else { throw RollError.rollFull }
        let shot = try await store(jpeg: jpeg, index: roll.shots.count, isImported: false, stockID: nil)
        shot.roll = roll
        if roll.isFull { roll.finishedAt = .now }
        try await save(removing: shot)
        return shot
    }

    func finishEarly(_ roll: Roll) throws {
        guard case .active = roll.state() else { return }
        roll.finishedAt = .now
        try context.save()
    }

    // No "skip the wait" / fast-develop path on purpose (PLAN 10.4): do not add one.
    func startDeveloping(_ roll: Roll, canDevelopInParallel: Bool, now: Date = .now) throws {
        guard roll.state(now: now) == .exposed else { throw RollError.notExposed }
        if !canDevelopInParallel, try developingCount(now: now) > 0 { throw RollError.developingLimitReached }
        roll.developStartedAt = now
        roll.developDuration = Self.developDuration
        try context.save()
    }

    /// Lazily stamps `developedAt` (PLAN 7.2): there is no background timer.
    func rolls(now: Date = .now) throws -> [Roll] {
        let all = try fetchRolls()
        var changed = false
        for roll in all where roll.developedAt == nil {
            if let ready = roll.readyAt(), now >= ready {
                roll.developedAt = ready
                changed = true
            }
        }
        if changed { try context.save() }
        return all
    }

    func developingCount(now: Date = .now) throws -> Int {
        try fetchRolls().count { if case .developing = $0.state(now: now) { true } else { false } }
    }

    func importRoll() throws -> Roll {
        let descriptor = FetchDescriptor<Roll>(predicate: #Predicate { $0.isImportRoll })
        if let existing = try context.fetch(descriptor).first { return existing }
        let roll = Roll(stockID: Self.importStockID, capacity: 0, isImportRoll: true)
        context.insert(roll)
        try context.save()
        return roll
    }

    func appendImport(jpeg: Data, stockID: String) async throws -> Shot {
        let roll = try importRoll()
        let shot = try await store(jpeg: jpeg, index: roll.shots.count, isImported: true, stockID: stockID)
        shot.roll = roll
        try await save(removing: shot)
        return shot
    }

    func delete(_ roll: Roll) async throws {
        let files = roll.shots.flatMap { [$0.imageFilename, $0.thumbnailFilename] }
        context.delete(roll)
        try context.save()
        await imageStore.delete(files)
    }

    func deleteAll() async throws {
        try context.delete(model: Roll.self)
        try context.delete(model: Shot.self)
        try context.save()
        await imageStore.deleteAll()
    }

    // MARK: - Private

    private func fetchRolls() throws -> [Roll] {
        let descriptor = FetchDescriptor<Roll>(
            predicate: #Predicate { !$0.isImportRoll },
            sortBy: [SortDescriptor(\.createdAt, order: .reverse)]
        )
        return try context.fetch(descriptor)
    }

    /// Writes the files and inserts the shot; the caller links it to a roll and saves.
    private func store(jpeg: Data, index: Int, isImported: Bool, stockID: String?) async throws -> Shot {
        let id = UUID()
        let names = try await imageStore.save(jpeg: jpeg, id: id)
        let shot = Shot(
            id: id, index: index, imageFilename: names.image, thumbnailFilename: names.thumbnail,
            isImported: isImported, stockID: stockID
        )
        context.insert(shot)
        return shot
    }

    /// Saves; on failure rolls the insert back and removes the just-written files.
    private func save(removing shot: Shot) async throws {
        do {
            try context.save()
        } catch {
            let files = [shot.imageFilename, shot.thumbnailFilename]
            context.delete(shot)
            await imageStore.delete(files)
            throw error
        }
    }
}
