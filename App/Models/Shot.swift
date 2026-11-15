import Foundation
import SwiftData

@Model
final class Shot {
    @Attribute(.unique) var id: UUID
    var index: Int // position in the roll
    var capturedAt: Date
    var imageFilename: String // filename only, resolved through ImageStore (PLAN 7.1)
    var thumbnailFilename: String
    var isImported: Bool
    var stockID: String? // film used for an imported frame; nil for roll shots (the roll's stock applies)
    var roll: Roll?

    init(
        id: UUID = UUID(),
        index: Int,
        capturedAt: Date = .now,
        imageFilename: String,
        thumbnailFilename: String,
        isImported: Bool = false,
        stockID: String? = nil
    ) {
        self.id = id
        self.index = index
        self.capturedAt = capturedAt
        self.imageFilename = imageFilename
        self.thumbnailFilename = thumbnailFilename
        self.isImported = isImported
        self.stockID = stockID
    }
}
