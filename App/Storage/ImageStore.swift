import Foundation
import ImageIO
import os
import UniformTypeIdentifiers

/// File IO for frames. The database only ever holds the returned filenames (PLAN 7.1).
actor ImageStore {
    enum StoreError: Error { case thumbnailFailed, readFailed }

    static let thumbnailMaxPixelSize = 600

    nonisolated let directory: URL

    nonisolated static var defaultDirectory: URL {
        URL.applicationSupportDirectory.appending(path: "Frames", directoryHint: .isDirectory)
    }

    init(directory: URL = ImageStore.defaultDirectory) {
        self.directory = directory
    }

    /// Atomically writes the original JPEG and its thumbnail. Both files are written to temp names first,
    /// then renamed into place so a crash between writes cannot leave a partial pair. If thumbnail generation
    /// fails the original is still saved — callers handle the missing thumbnail gracefully.
    func save(jpeg: Data, id: UUID) async throws -> (image: String, thumbnail: String) {
        let image = "\(id.uuidString).jpg"
        let thumbnail = "\(id.uuidString)_thumb.jpg"

        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        Self.ensureBackupFlag(on: directory)

        let imageTmp = imageURL(image).appendingPathExtension("tmp")
        let thumbTmp = imageURL(thumbnail).appendingPathExtension("tmp")

        do {
            try jpeg.write(to: imageTmp, options: .atomic)

            do {
                let thumbData = try Self.makeThumbnail(from: jpeg)
                try thumbData.write(to: thumbTmp, options: .atomic)
            } catch {
                // Original is already on disk; save it and return. The thumbnail file won't exist —
                // callers handle nil from `data()`. The original is not an orphan because the Shot references it.
                Log.storage.warning("thumbnail generation failed for \(id.uuidString), original saved without thumbnail: \(error)")
                try Self.rename(imageTmp, to: imageURL(image))
                return (image, thumbnail)
            }

            // Both written — rename into final positions.
            try Self.rename(imageTmp, to: imageURL(image))
            try Self.rename(thumbTmp, to: imageURL(thumbnail))
        } catch {
            try? FileManager.default.removeItem(at: imageTmp)
            try? FileManager.default.removeItem(at: thumbTmp)
            Log.storage.error("save failed for \(id.uuidString): \(error)")
            throw error
        }

        return (image, thumbnail)
    }

    nonisolated func imageURL(_ filename: String) -> URL {
        directory.appending(path: filename, directoryHint: .notDirectory)
    }

    nonisolated func thumbnailURL(_ filename: String) -> URL {
        imageURL(filename)
    }

    /// Returns nil on read failure instead of throwing, so callers can show a placeholder or retry.
    func data(_ filename: String) async -> Data? {
        do {
            return try Data(contentsOf: imageURL(filename))
        } catch {
            Log.storage.error("read failed for \(filename): \(error)")
            return nil
        }
    }

    /// Throwing variant for callers that need to propagate errors (e.g. share/save).
    func loadData(_ filename: String) async throws -> Data {
        do {
            return try Data(contentsOf: imageURL(filename))
        } catch {
            Log.storage.error("read failed for \(filename): \(error)")
            throw StoreError.readFailed
        }
    }

    func delete(_ filenames: [String]) async {
        for name in filenames {
            try? FileManager.default.removeItem(at: imageURL(name))
        }
    }

    func deleteAll() async {
        try? FileManager.default.removeItem(at: directory)
    }

    /// Removes every file in `directory` that is not in `referenced`. Called at launch (non-blocking) and
    /// after roll deletion to reclaim space from orphaned writes.
    func cleanupOrphans(referenced: Set<String>) async {
        guard let entries = try? FileManager.default.contentsOfDirectory(atPath: directory.path) else { return }
        var removed = 0
        for entry in entries where !referenced.contains(entry) {
            try? FileManager.default.removeItem(at: imageURL(entry))
            removed += 1
        }
        if removed > 0 {
            Log.storage.notice("orphan cleanup removed \(removed) file(s)")
        }
    }

    /// Returns the set of all filenames currently in the directory (for diagnostics/tests).
    func allFiles() -> Set<String> {
        guard let entries = try? FileManager.default.contentsOfDirectory(atPath: directory.path) else { return [] }
        return Set(entries)
    }

    // MARK: - Private

    private nonisolated static func rename(_ src: URL, to dst: URL) throws {
        if FileManager.default.fileExists(atPath: dst.path) {
            try FileManager.default.removeItem(at: dst)
        }
        try FileManager.default.moveItem(at: src, to: dst)
    }

    /// Ensures the Frames directory is included in iCloud backups (PLAN §7.1: photos are the user's own).
    private nonisolated static func ensureBackupFlag(on directory: URL) {
        var url = directory
        var values = URLResourceValues()
        values.isExcludedFromBackup = false
        try? url.setResourceValues(values)
    }

    /// Downsamples via ImageIO without decoding the full image.
    private nonisolated static func makeThumbnail(from jpeg: Data) throws -> Data {
        let options: [CFString: Any] = [
            kCGImageSourceCreateThumbnailFromImageAlways: true,
            kCGImageSourceCreateThumbnailWithTransform: true,
            kCGImageSourceThumbnailMaxPixelSize: thumbnailMaxPixelSize
        ]
        guard let source = CGImageSourceCreateWithData(jpeg as CFData, nil),
              let cgImage = CGImageSourceCreateThumbnailAtIndex(source, 0, options as CFDictionary)
        else { throw StoreError.thumbnailFailed }
        let output = NSMutableData()
        guard let destination = CGImageDestinationCreateWithData(output, UTType.jpeg.identifier as CFString, 1, nil)
        else { throw StoreError.thumbnailFailed }
        CGImageDestinationAddImage(destination, cgImage, [kCGImageDestinationLossyCompressionQuality: 0.8] as CFDictionary)
        guard CGImageDestinationFinalize(destination) else { throw StoreError.thumbnailFailed }
        return output as Data
    }
}
