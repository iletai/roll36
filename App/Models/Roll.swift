import Foundation
import SwiftData

@Model
final class Roll {
    @Attribute(.unique) var id: UUID
    var stockID: String // FilmProfile.id
    var capacity: Int
    var createdAt: Date
    var finishedAt: Date? // set when full or finished early
    var developStartedAt: Date? // nil = not developed yet
    var developDuration: TimeInterval // seconds
    var developedAt: Date? // stamped lazily once developing is over
    var isImportRoll: Bool = false // pseudo-roll "Darkroom imports", always developed

    @Relationship(deleteRule: .cascade, inverse: \Shot.roll)
    var shots: [Shot] = []

    init(
        id: UUID = UUID(),
        stockID: String,
        capacity: Int = 36,
        createdAt: Date = .now,
        developDuration: TimeInterval = 3600,
        isImportRoll: Bool = false
    ) {
        self.id = id
        self.stockID = stockID
        self.capacity = capacity
        self.createdAt = createdAt
        self.developDuration = developDuration
        self.isImportRoll = isImportRoll
    }
}
