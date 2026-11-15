import CoreGraphics
import Foundation
import ImageIO
import UniformTypeIdentifiers

/// Simulator stand-in: returns a synthetic street scene so the film stocks have something to chew on.
actor MockCameraService: CameraService {
    /// Upright portrait, like the live camera.
    static let width = 3024
    static let height = 4032

    nonisolated let isAvailable = false
    private var isRunning = false
    private var frame = 0

    func start() async throws {
        isRunning = true
    }

    func stop() async {
        isRunning = false
    }

    func capture() async throws -> Data {
        guard isRunning else { throw CameraError.unavailable }
        #if DEBUG
            // Screenshot mode: a real-looking photo instead of the synthetic scene (e.g. for `-seedImport`).
            if DemoSeed.isEnabled, let data = DemoSeed.photoData(6) { return data }
        #endif
        frame += 1
        guard let data = Self.render(frame: frame) else { throw CameraError.captureFailed }
        return data
    }

    func setFlashMode(_: FlashMode) async {}

    func setZoom(_: Double) async {}

    func exposureReadout() async -> ExposureReadout? {
        ExposureReadout(shutterSeconds: 1.0 / 500, aperture: 2.8, iso: 400)
    }

    // MARK: - Synthetic frame

    private static func render(frame: Int) -> Data? {
        let width = Self.width, height = Self.height
        guard let context = CGContext(
            data: nil, width: width, height: height, bitsPerComponent: 8, bytesPerRow: 0,
            space: CGColorSpace(name: CGColorSpace.sRGB) ?? CGColorSpaceCreateDeviceRGB(),
            bitmapInfo: CGImageAlphaInfo.noneSkipLast.rawValue
        ) else { return nil }

        // CoreGraphics origin is bottom-left: y grows upward.
        let horizon = CGFloat(height) * 0.45
        let space = context.colorSpace ?? CGColorSpaceCreateDeviceRGB()
        let sky = CGGradient(colorsSpace: space, colors: [rgb(0.98, 0.78, 0.52), rgb(0.42, 0.62, 0.86)] as CFArray, locations: [0, 1])
        let street = CGGradient(colorsSpace: space, colors: [rgb(0.20, 0.16, 0.13), rgb(0.55, 0.45, 0.36)] as CFArray, locations: [0, 1])
        if let sky {
            context.drawLinearGradient(sky, start: CGPoint(x: 0, y: horizon), end: CGPoint(x: 0, y: CGFloat(height)), options: [])
        }
        if let street {
            context.drawLinearGradient(street, start: .zero, end: CGPoint(x: 0, y: horizon), options: [])
        }

        // Sun drifts a little every frame so consecutive captures differ.
        let sunX = 600 + CGFloat(frame % 20) * 90
        context.setFillColor(rgb(1.0, 0.92, 0.70))
        context.fillEllipse(in: CGRect(x: sunX, y: CGFloat(height) - 900, width: 420, height: 420))

        // Buildings: warm, neutral and cool blocks so stock colour shifts are visible.
        let buildings: [(CGRect, CGColor)] = [
            (CGRect(x: 0, y: horizon, width: 600, height: 1500), rgb(0.72, 0.36, 0.24)),
            (CGRect(x: 650, y: horizon, width: 600, height: 1900), rgb(0.86, 0.80, 0.68)),
            (CGRect(x: 1350, y: horizon, width: 600, height: 1200), rgb(0.30, 0.42, 0.40)),
            (CGRect(x: 1950, y: horizon, width: 600, height: 2200), rgb(0.62, 0.58, 0.54)),
            (CGRect(x: 2550, y: horizon, width: 600, height: 1600), rgb(0.20, 0.24, 0.36))
        ]
        for (rect, color) in buildings {
            context.setFillColor(color)
            context.fill(rect)
            // Windows.
            context.setFillColor(rgb(0.10, 0.09, 0.08))
            for row in stride(from: rect.minY + 150, to: rect.maxY - 150, by: 260) {
                for col in stride(from: rect.minX + 70, to: rect.maxX - 80, by: 170) {
                    context.fill(CGRect(x: col, y: row, width: 90, height: 140))
                }
            }
        }

        // Shop sign with text-like bars; the bar pattern depends on the frame number.
        context.setFillColor(rgb(0.80, 0.12, 0.10))
        context.fill(CGRect(x: 200, y: horizon + 300, width: 1300, height: 260))
        context.setFillColor(rgb(0.97, 0.95, 0.90))
        for index in 0 ..< 9 {
            let barWidth = CGFloat(40 + ((index + frame) % 4) * 25)
            context.fill(CGRect(x: 260 + CGFloat(index) * 135, y: horizon + 380, width: barWidth, height: 100))
        }

        // Foreground: green planter and a white table for highlight roll-off.
        context.setFillColor(rgb(0.22, 0.48, 0.20))
        context.fill(CGRect(x: 150, y: 500, width: 700, height: 600))
        context.setFillColor(rgb(0.96, 0.96, 0.94))
        context.fillEllipse(in: CGRect(x: 1400, y: 300, width: 1400, height: 500))
        context.setFillColor(rgb(0.05, 0.05, 0.05))
        context.fill(CGRect(x: 2050, y: 0, width: 100, height: 350))

        guard let image = context.makeImage() else { return nil }
        let data = NSMutableData()
        guard let destination = CGImageDestinationCreateWithData(data, UTType.jpeg.identifier as CFString, 1, nil) else { return nil }
        CGImageDestinationAddImage(destination, image, [kCGImageDestinationLossyCompressionQuality: 0.85] as CFDictionary)
        guard CGImageDestinationFinalize(destination) else { return nil }
        return data as Data
    }

    private static func rgb(_ red: CGFloat, _ green: CGFloat, _ blue: CGFloat) -> CGColor {
        CGColor(srgbRed: red, green: green, blue: blue, alpha: 1)
    }
}
