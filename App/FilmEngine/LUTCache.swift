import CryptoKit
import Foundation
import os

/// Disk + memory cache for generated cubes: `Caches/lut/<stockID>-d<dim>-<hash>.bin`.
/// The hash covers every profile parameter, so tuning a profile invalidates its file.
actor LUTCache {
    private let directory: URL
    private var memory: [String: Data] = [:]

    init(directory: URL = .cachesDirectory.appending(path: "lut", directoryHint: .isDirectory)) {
        self.directory = directory
    }

    func cube(for profile: FilmProfile, dimension: Int = ColorCubeBuilder.dimension) -> Data {
        let name = Self.fileName(for: profile, dimension: dimension)
        if let data = memory[name] { return data }

        let url = directory.appending(path: name)
        let expectedSize = dimension * dimension * dimension * 4 * MemoryLayout<Float>.size
        if let data = try? Data(contentsOf: url), data.count == expectedSize {
            memory[name] = data
            return data
        }

        let data = ColorCubeBuilder.makeCube(for: profile, dimension: dimension)
        memory[name] = data
        do {
            try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
            try data.write(to: url, options: .atomic)
        } catch {
            // Cache miss next launch is harmless; the cube is regenerated.
            Log.film.error("LUT cache write failed: \(error.localizedDescription, privacy: .public)")
        }
        return data
    }

    /// Stable across launches (unlike `hashValue`): SHA-256 of the sorted-keys JSON.
    nonisolated static func fileName(for profile: FilmProfile, dimension: Int) -> String {
        let encoder = JSONEncoder()
        encoder.outputFormatting = .sortedKeys
        let json = (try? encoder.encode(profile)) ?? Data(profile.id.utf8)
        let hash = SHA256.hash(data: json).prefix(8).map { String(format: "%02x", $0) }.joined()
        return "\(profile.id)-d\(dimension)-\(hash).bin"
    }
}
