import SwiftUI

/// Transparent layer over the preview: tap to focus + meter, drag up/down while the reticle is
/// visible to adjust exposure compensation (-2...+2 EV in 1/3 steps).
///
/// `onFocus` receives the tap point normalized to this view's size (0...1, origin top-left, portrait).
/// Pass it straight to `CameraService.focus(atNormalizedPoint:)`: the service maps it to the
/// portrait sensor (device x = normalized y, device y = 1 - normalized x). Size the view to the
/// preview area only so taps outside it (shutter, chips) are untouched.
struct FocusOverlay: View {
    let onFocus: (CGPoint) -> Void
    let onExposureBias: (Double) -> Void

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var reticle: CGPoint?
    @State private var bias = 0.0
    @State private var dragStartBias: Double?
    @State private var hideTask: Task<Void, Never>?

    /// Vertical drag distance per 1/3 EV step.
    private static let pointsPerStep: CGFloat = 24
    private static let reticleSize: CGFloat = 72

    var body: some View {
        GeometryReader { proxy in
            ZStack {
                Color.clear.contentShape(Rectangle())
                if let reticle {
                    reticleView
                        .position(reticle)
                        .transition(reduceMotion ? .opacity : .opacity.combined(with: .scale(scale: 1.4)))
                        .allowsHitTesting(false)
                }
            }
            .gesture(SpatialTapGesture().onEnded { tap in
                focus(at: tap.location, in: proxy.size)
            })
            .simultaneousGesture(DragGesture(minimumDistance: 10).onChanged { drag in
                guard reticle != nil else { return }
                let start = dragStartBias ?? bias
                dragStartBias = start
                // Dragging up brightens.
                setBias(start - Double(drag.translation.height / Self.pointsPerStep) * ExposureBias.step)
                scheduleHide()
            }.onEnded { _ in dragStartBias = nil })
        }
        .accessibilityElement()
        .accessibilityLabel(Text("Focus and exposure"))
        .accessibilityHint(Text("Tap to focus. Drag up or down to adjust exposure."))
        .accessibilityValue(Text(verbatim: Self.format(bias)))
        .accessibilityAdjustableAction { direction in
            setBias(bias + (direction == .increment ? ExposureBias.step : -ExposureBias.step))
        }
    }

    private var reticleView: some View {
        HStack(spacing: Theme.spacingS) {
            Rectangle()
                .strokeBorder(Theme.amber, lineWidth: 1.5)
                .frame(width: Self.reticleSize, height: Self.reticleSize)
            VStack(spacing: 2) {
                Image(systemName: "sun.max")
                Text(verbatim: Self.format(bias)).monoLabel(color: Theme.amber)
            }
            .foregroundStyle(Theme.amber)
        }
        .fixedSize()
    }

    private func focus(at location: CGPoint, in size: CGSize) {
        guard size.width > 0, size.height > 0 else { return }
        onFocus(CGPoint(x: min(max(location.x / size.width, 0), 1), y: min(max(location.y / size.height, 0), 1)))
        withAnimation(reduceMotion ? nil : .spring(duration: 0.25)) { reticle = location }
        scheduleHide()
    }

    private func setBias(_ ev: Double) {
        let snapped = ExposureBias.snapped(ev)
        guard snapped != bias else { return }
        bias = snapped
        Haptics.selection()
        onExposureBias(snapped)
    }

    private func scheduleHide() {
        hideTask?.cancel()
        hideTask = Task {
            try? await Task.sleep(for: .seconds(1.2))
            guard !Task.isCancelled else { return }
            withAnimation(.easeOut(duration: 0.3)) { reticle = nil }
        }
    }

    private static func format(_ ev: Double) -> String {
        ev == 0 ? "0" : ev.formatted(.number.precision(.fractionLength(1)).sign(strategy: .always()))
    }
}
