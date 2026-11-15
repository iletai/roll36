import CoreImage
import CoreImage.CIFilterBuiltins
import Foundation
@testable import ROLL36
import Testing

struct ColorCubeBuilderTests {
    /// Portra with every tone parameter at identity.
    private var neutral: FilmProfile {
        var p = FilmCatalog.portra400
        p.contrast = 1
        p.saturation = 1
        p.lift = .zero
        p.gain = .one
        p.fade = 0
        p.tintStrength = 0
        return p
    }

    @Test func cubeSize() {
        let data = ColorCubeBuilder.makeCube(for: FilmCatalog.portra400)
        #expect(data.count == 33 * 33 * 33 * 4 * MemoryLayout<Float>.size)
        #expect(ColorCubeBuilder.makeCube(for: FilmCatalog.portra400, dimension: 17).count == 17 * 17 * 17 * 4 * 4)
    }

    @Test func alphaIsOneAndRedVariesFastest() {
        let floats = ColorCubeBuilder.makeCube(for: neutral, dimension: 3).withUnsafeBytes { Array($0.bindMemory(to: Float.self)) }
        #expect(stride(from: 3, to: floats.count, by: 4).allSatisfy { floats[$0] == 1 })
        // Entry 1 = (r 0.5, g 0, b 0); entry 3 = (r 0, g 0.5, b 0).
        #expect(floats[4] == 0.5 && floats[5] == 0 && floats[6] == 0)
        #expect(floats[12] == 0 && floats[13] == 0.5 && floats[14] == 0)
    }

    @Test(arguments: ["neutral", "trix400", "cinestill800t"])
    func whiteStaysWhite(id: String) throws {
        let profile = try #require(id == "neutral" ? neutral : FilmCatalog.profile(id: id))
        let white = ColorCubeBuilder.transform(.one, profile)
        #expect(white.min() >= 0.98)
    }

    @Test func blackNotNegative() {
        for profile in FilmCatalog.all {
            #expect(ColorCubeBuilder.transform(.zero, profile).min() >= 0, "\(profile.id)")
        }
    }

    @Test func monochromeIsGray() {
        for rgb in [SIMD3(0.9, 0.2, 0.1), SIMD3(0.1, 0.8, 0.3), SIMD3(0.4, 0.4, 0.9), SIMD3(0.5, 0.5, 0.5)] {
            let out = ColorCubeBuilder.transform(rgb, FilmCatalog.trix400)
            #expect(out.x == out.y && out.y == out.z)
        }
    }

    @Test func contrastMonotonic() {
        var punchy = neutral
        punchy.contrast = 1.3
        let lo = SIMD3(repeating: 0.2), hi = SIMD3(repeating: 0.8)
        let flatRange = ColorCubeBuilder.transform(hi, neutral).x - ColorCubeBuilder.transform(lo, neutral).x
        let punchyRange = ColorCubeBuilder.transform(hi, punchy).x - ColorCubeBuilder.transform(lo, punchy).x
        #expect(punchyRange > flatRange)

        // Every stock keeps a gray ramp non-decreasing.
        for profile in FilmCatalog.all {
            let ramp = (0 ... 20).map { ColorCubeBuilder.transform(SIMD3(repeating: Double($0) / 20), profile) }
            let lumas = ramp.map { $0.x + $0.y + $0.z }
            #expect(zip(lumas, lumas.dropFirst()).allSatisfy { $0 <= $1 + 1e-9 }, "\(profile.id)")
        }
    }

    @Test func lutCacheKeyChangesWithParameters() throws {
        var tuned = FilmCatalog.portra400
        tuned.contrast += 0.01
        let original = LUTCache.fileName(for: FilmCatalog.portra400, dimension: 33)
        #expect(original == LUTCache.fileName(for: FilmCatalog.portra400, dimension: 33))
        #expect(original != LUTCache.fileName(for: tuned, dimension: 33))
        #expect(original.hasPrefix("portra400-d33-"))
    }

    @Test func lutCacheWritesToInjectedDirectory() async throws {
        let dir = FileManager.default.temporaryDirectory.appending(path: UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: dir) }
        let cache = LUTCache(directory: dir)
        let data = await cache.cube(for: FilmCatalog.trix400, dimension: 17)
        #expect(data == ColorCubeBuilder.makeCube(for: FilmCatalog.trix400, dimension: 17))
        let files = try FileManager.default.contentsOfDirectory(atPath: dir.path())
        #expect(files == [LUTCache.fileName(for: FilmCatalog.trix400, dimension: 17)])
    }
}

struct FilmEngineTests {
    private let context = CIContext()

    private func syntheticJPEG(width: Int, height: Int) throws -> Data {
        let gradient = CIFilter.linearGradient()
        gradient.point0 = CGPoint(x: 0, y: 0)
        gradient.point1 = CGPoint(x: width, y: height)
        gradient.color0 = CIColor(red: 0.95, green: 0.55, blue: 0.25)
        gradient.color1 = CIColor(red: 0.45, green: 0.20, blue: 0.05)
        let image = try #require(gradient.outputImage).cropped(to: CGRect(x: 0, y: 0, width: width, height: height))
        let sRGB = try #require(CGColorSpace(name: CGColorSpace.sRGB))
        return try #require(context.jpegRepresentation(of: image, colorSpace: sRGB))
    }

    private func meanRGB(_ image: CIImage) throws -> SIMD3<Float> {
        let average = CIFilter.areaAverage()
        average.inputImage = image
        average.extent = image.extent
        var pixel = [Float](repeating: 0, count: 4)
        try context.render(#require(average.outputImage), toBitmap: &pixel, rowBytes: 16,
                           bounds: CGRect(x: 0, y: 0, width: 1, height: 1), format: .RGBAf, colorSpace: nil)
        return SIMD3(pixel[0], pixel[1], pixel[2])
    }

    @Test func fixtureStocksProduceDistinctOutputs() async throws {
        let jpeg = try syntheticJPEG(width: 2000, height: 1500)
        let engine = FilmEngine(lutCache: LUTCache(directory: FileManager.default.temporaryDirectory.appending(path: UUID().uuidString)))
        let stocks = [FilmCatalog.portra400, FilmCatalog.trix400, FilmCatalog.cinestill800t, FilmCatalog.expiredGold]

        var means: [String: SIMD3<Float>] = [:]
        for stock in stocks {
            let output = try await engine.process(jpeg, profile: stock)
            let image = try #require(CIImage(data: output))
            #expect(image.extent.size == CGSize(width: 2000, height: 1500), "\(stock.id)")
            means[stock.id] = try meanRGB(image)
        }

        for (i, a) in stocks.enumerated() {
            for b in stocks.dropFirst(i + 1) {
                let d = try #require(means[a.id]) - #require(means[b.id])
                #expect((d * d).sum().squareRoot() > 0.01, "\(a.id) vs \(b.id)")
            }
        }

        let trix = try #require(means["trix400"])
        #expect(trix.max() - trix.min() < 0.01)
    }

    @Test func previewAndWatermark() async throws {
        let jpeg = try syntheticJPEG(width: 2000, height: 1500)
        let engine = FilmEngine(lutCache: LUTCache(directory: FileManager.default.temporaryDirectory.appending(path: UUID().uuidString)))

        let preview = try await engine.preview(jpeg, profile: FilmCatalog.portra400, maxDimension: 1000)
        #expect(try #require(CIImage(data: preview)).extent.size == CGSize(width: 1000, height: 750))

        let marked = try await engine.watermarked(jpeg)
        #expect(try #require(CIImage(data: marked)).extent.size == CGSize(width: 2000, height: 1500))
    }

    @Test func twelveMegapixelTiming() async throws {
        let jpeg = try syntheticJPEG(width: 4032, height: 3024)
        let engine = FilmEngine(lutCache: LUTCache(directory: FileManager.default.temporaryDirectory.appending(path: UUID().uuidString)))
        _ = try await engine.process(jpeg, profile: FilmCatalog.cinestill800t) // warm up LUT + pipeline
        let clock = ContinuousClock()
        let elapsed = try await clock.measure {
            let output = try await engine.process(jpeg, profile: FilmCatalog.portra400)
            #expect(try #require(CIImage(data: output)).extent.size == CGSize(width: 4032, height: 3024))
        }
        print("FilmEngine 12MP: \(elapsed)")
    }
}
