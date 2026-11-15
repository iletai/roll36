import Foundation
import ImageIO
import UniformTypeIdentifiers

/// File IO for frames. The database only ever holds the returned filenames (PLAN 7.1).
actor ImageStore {
    enum StoreError: Error { case thumbnailFailed }

    static let thumbnailMaxPixelSize = 600

    nonisolated let directory: URL

    nonisolated static var defaultDirectory: URL {
        URL.applicationSupportDirectory.appending(path: "Frames", directoryHint: .isDirectory)
    }

    init(directory: URL = ImageStore.defaultDirectory) {
        self.directory = directory
    }

    func save(jpeg: Data, id: UUID) async throws -> (image: String, thumbnail: String) {
        let image = "\(id.uuidString).jpg"
        let thumbnail = "\(id.uuidString)_thumb.jpg"
        let thumbData = try Self.makeThumbnail(from: jpeg)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        try jpeg.write(to: imageURL(image), options: .atomic)
        try thumbData.write(to: thumbnailURL(thumbnail), options: .atomic)
        return (image, thumbnail)
    }

    nonisolated func imageURL(_ filename: String) -> URL {
        directory.appending(path: filename, directoryHint: .notDirectory)
    }

    nonisolated func thumbnailURL(_ filename: String) -> URL {
        imageURL(filename)
    }

    func data(_ filename: String) async throws -> Data {
        try Data(contentsOf: imageURL(filename))
    }

    func delete(_ filenames: [String]) async {
        for name in filenames {
            try? FileManager.default.removeItem(at: imageURL(name))
        }
    }

    func deleteAll() async {
        try? FileManager.default.removeItem(at: directory)
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
