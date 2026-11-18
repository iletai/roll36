import CoreMotion
import os
import SwiftUI

/// Horizon line in the preview centre. Rotates against the device roll, turns green within ±1.5° of level.
/// Samples CoreMotion only while on screen and the app is active. Assumes a portrait-locked UI.
struct HorizonLevel: View {
    // swiftlint:disable:next large_tuple
    typealias Reading = (angle: Double, isLevel: Bool, isVisible: Bool)

    @Environment(\.scenePhase) private var scenePhase
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var reading: Reading = (0, false, false)

    private static let levelTolerance = 1.5
    /// Beyond this camera elevation (degrees from upright) the horizon is meaningless.
    private static let maxPitch = 60.0
    private static let sampleInterval = Duration.milliseconds(50)
    /// Exponential low-pass factor per sample (~20 Hz): higher is snappier, lower is steadier.
    private static let smoothing = 0.2

    /// `roll`: in-plane device tilt in degrees, clockwise positive, 0 = upright portrait.
    /// `pitch`: camera elevation in degrees from upright, 0 = looking at the horizon.
    /// `angle` is the clockwise rotation (degrees) to draw the line with.
    nonisolated static func compute(roll: Double, pitch: Double) -> Reading {
        let isVisible = abs(pitch) <= maxPitch
        return (-roll, isVisible && abs(roll) <= levelTolerance, isVisible)
    }

    var body: some View {
        GeometryReader { proxy in
            Rectangle()
                .fill(reading.isLevel ? Theme.green : Theme.amber)
                .frame(width: proxy.size.width * 0.4, height: 1)
                .rotationEffect(.degrees(reading.angle))
                .position(x: proxy.size.width / 2, y: proxy.size.height / 2)
        }
        .opacity(reading.isVisible ? 1 : 0)
        .animation(reduceMotion ? nil : .linear(duration: 0.05), value: reading.angle)
        .allowsHitTesting(false)
        .accessibilityHidden(true)
        .onChange(of: reading.isLevel) { _, isLevel in
            if isLevel { Haptics.selection() }
        }
        // Started on appear and only while active; cancellation (disappear/background) stops the sensor.
        .task(id: scenePhase) {
            guard scenePhase == .active else { return }
            await track()
        }
    }

    private func track() async {
        let manager = CMMotionManager()
        guard manager.isDeviceMotionAvailable else {
            Log.camera.info("Device motion unavailable; horizon level hidden")
            return
        }
        manager.startDeviceMotionUpdates()
        defer { manager.stopDeviceMotionUpdates() }
        var smoothed: (roll: Double, pitch: Double)?
        // Pull the latest sample rather than receiving callbacks: no queue hops, nothing escapes this task.
        while !Task.isCancelled {
            if let gravity = manager.deviceMotion?.gravity {
                let roll = atan2(gravity.x, -gravity.y) * 180 / .pi
                let pitch = asin(max(-1, min(1, gravity.z))) * 180 / .pi
                var next = (roll: roll, pitch: pitch)
                if let previous = smoothed {
                    next.roll = previous.roll + Self.smoothing * (roll - previous.roll)
                    next.pitch = previous.pitch + Self.smoothing * (pitch - previous.pitch)
                }
                smoothed = next
                reading = Self.compute(roll: next.roll, pitch: next.pitch)
            }
            try? await Task.sleep(for: Self.sampleInterval)
        }
    }
}
