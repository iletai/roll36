import SwiftUI

/// Camera tab (PLAN §13.1). The view model needs the environment, so it is built on first appearance.
struct ViewfinderView: View {
    @Environment(AppEnvironment.self) private var env
    @State private var model: ViewfinderViewModel?

    var body: some View {
        Group {
            if let model {
                ViewfinderContent(model: model)
            } else {
                Theme.bg
            }
        }
        .task { if model == nil { model = ViewfinderViewModel(env: env) } }
    }
}

private struct ViewfinderContent: View {
    @Bindable var model: ViewfinderViewModel
    @Environment(AppEnvironment.self) private var env
    @Environment(\.scenePhase) private var scenePhase
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var showSettings = false
    @State private var confirmFinish = false
    @State private var flashVisible = false

    var body: some View {
        VStack(spacing: 0) {
            topBar
            exposureLine
            preview
            stockRow
            controls
        }
        .background(Theme.bg.ignoresSafeArea())
        // Camera runs only while the screen is visible and the app is active; cancellation stops it.
        .task(id: scenePhase) {
            guard scenePhase == .active else { return }
            await model.run()
        }
        .task(id: model.flashCount) {
            guard model.flashCount > 0, !reduceMotion else { return }
            flashVisible = true
            try? await Task.sleep(for: .milliseconds(120))
            flashVisible = false
        }
        .sheet(isPresented: $showSettings) { SettingsView() }
        .sheet(isPresented: $model.showStockPicker) { StockPickerView(model: model, selectedID: env.selectedStockID) }
        .sheet(item: $model.paywall) { PaywallView(highlightStockID: $0.stockID) }
        .alert("Something went wrong", isPresented: errorBinding) {
            Button("OK") {}
        } message: {
            Text(model.errorMessage)
        }
        .confirmationDialog("Finish this roll early?", isPresented: $confirmFinish, titleVisibility: .visible) {
            Button("Finish roll") { model.finishEarly() }
        }
    }

    private var errorBinding: Binding<Bool> {
        Binding(get: { model.state == .captureError }, set: { if !$0 { model.dismissError() } })
    }

    // MARK: - Top

    private var topBar: some View {
        HStack {
            Button { Task { await model.cycleFlash() } } label: {
                HStack(spacing: 6) {
                    Image(systemName: "bolt.fill").foregroundStyle(Theme.amber)
                    flashTitle.monoLabel(size: 12, color: Theme.text)
                }
                .padding(.horizontal, 10)
                .frame(height: 40)
                .monoBox()
            }
            .buttonStyle(.plain)
            .frame(maxWidth: .infinity, alignment: .leading)
            .accessibilityLabel(Text("Flash"))
            .accessibilityValue(flashTitle)

            RollCounter(taken: model.taken, capacity: model.capacity)
                .fixedSize()

            Button { showSettings = true } label: {
                Image(systemName: "slider.horizontal.3")
                    .foregroundStyle(Theme.amber)
                    .frame(width: 40, height: 40)
                    .monoBox()
            }
            .buttonStyle(.plain)
            .frame(maxWidth: .infinity, alignment: .trailing)
            .accessibilityLabel(Text("Settings"))
        }
        .padding(.horizontal, Theme.spacingM)
        .padding(.vertical, Theme.spacingS)
    }

    private var flashTitle: Text {
        switch model.flashMode {
        case .auto: Text("Auto")
        case .on: Text("On")
        case .off: Text("Off")
        }
    }

    private var exposureLine: some View {
        HStack {
            Text(verbatim: model.exposure?.displayText ?? " ")
                .monoLabel(size: 12, color: Theme.amber)
            Spacer()
        }
        .padding(.horizontal, Theme.spacingM)
        .padding(.vertical, 10)
        .background(Theme.surface)
        .overlay(alignment: .top) { Theme.line.frame(height: Theme.lineWidth) }
        .overlay(alignment: .bottom) { Theme.line.frame(height: Theme.lineWidth) }
    }

    // MARK: - Preview

    private var preview: some View {
        ZStack {
            if model.state == .noPermission {
                permissionNotice
            } else {
                CameraPreviewView(service: env.camera)
                FramingBrackets()
                    .stroke(Theme.amber, lineWidth: 1.5)
                    .padding(16)
                    .allowsHitTesting(false)
                    .accessibilityHidden(true)
                stateOverlay
                if flashVisible { Color.black }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Theme.surface)
        .clipped()
    }

    @ViewBuilder
    private var stateOverlay: some View {
        switch model.state {
        case .loading:
            ProgressView().tint(Theme.amber)
        case .rollFull:
            dimmed {
                Text("Roll is full").monoDisplay(size: 24)
                PrimaryButton(title: "Develop now", systemImage: "flask") { model.developNow() }
            }
        case .noActiveRoll:
            dimmed {
                PrimaryButton(title: "Load \(model.stock.displayName)", systemImage: "film") { model.loadSelectedStock() }
            }
        default:
            EmptyView()
        }
    }

    private func dimmed(@ViewBuilder _ content: () -> some View) -> some View {
        ZStack {
            Color.black.opacity(0.65)
            VStack(spacing: Theme.spacingM, content: content)
                .padding(.horizontal, Theme.spacingL)
        }
    }

    private var permissionNotice: some View {
        VStack(spacing: Theme.spacingM) {
            Text("Camera access is off").monoDisplay(size: 20)
            Text("ROLL 36 needs the camera to expose frames. Turn it on in Settings.")
                .bodyText(color: Theme.muted)
                .multilineTextAlignment(.center)
            PrimaryButton(title: "Open Settings") { model.openSettings() }
        }
        .padding(Theme.spacingL)
    }

    // MARK: - Bottom

    private var stockRow: some View {
        HStack {
            if model.canChangeStock {
                Button { model.showStockPicker = true } label: { stockChip }
                    .buttonStyle(.plain)
                    .accessibilityHint(Text("Choose film stock"))
            } else {
                stockChip
            }
            Spacer(minLength: Theme.spacingS)
            lensChips
        }
        .padding(.horizontal, Theme.spacingM)
        .padding(.vertical, Theme.spacingS)
        .background(Theme.surface)
        .overlay(alignment: .top) { Theme.line.frame(height: Theme.lineWidth) }
    }

    private var stockChip: some View {
        let stock = model.stock
        return HStack(spacing: 10) {
            Text(verbatim: "\(stock.iso)")
                .monoLabel(size: 12, color: Theme.bg)
                .padding(.horizontal, 6)
                .padding(.vertical, 3)
                .background(Theme.amber, in: RoundedRectangle(cornerRadius: Theme.boxRadius))
            VStack(alignment: .leading, spacing: 2) {
                Text(verbatim: stock.displayName).monoLabel(size: 12, color: Theme.text)
                Text(verbatim: "\(stock.frames) EXP · \(stock.processCode)").monoLabel(size: 9)
            }
        }
        .padding(8)
        .monoBox()
        .accessibilityElement(children: .combine)
    }

    private var lensChips: some View {
        HStack(spacing: 0) {
            ForEach(ViewfinderViewModel.Lens.allCases, id: \.self) { lens in
                let selected = model.lens == lens
                Button { Task { await model.select(lens) } } label: {
                    Text(lens.title)
                        .monoLabel(size: 11, color: selected ? Theme.bg : Theme.text)
                        .padding(.horizontal, 8)
                        .frame(height: 36)
                        .background(selected ? Theme.amber : .clear)
                }
                .buttonStyle(.plain)
                .accessibilityAddTraits(selected ? .isSelected : [])
            }
        }
        .monoBox()
    }

    private var controls: some View {
        HStack {
            frameBadge.frame(maxWidth: .infinity, alignment: .leading)
            ShutterButton(isEnabled: model.canShoot) { Task { await model.shutter() } }
            // The clear spacer keeps the slot (and so the shutter position) when there is no button.
            ZStack(alignment: .trailing) {
                Color.clear.frame(height: 1)
                finishButton
            }
            .frame(maxWidth: .infinity)
        }
        .padding(.horizontal, Theme.spacingM)
        .padding(.vertical, Theme.spacingM)
        .background(Theme.bg)
    }

    /// Frame number only: a captured frame is never shown before it is developed (PLAN §9.4).
    private var frameBadge: some View {
        VStack(spacing: 6) {
            Text(verbatim: "#\(model.taken)")
                .monoLabel(size: 14, color: Theme.text)
                .frame(width: 56, height: 56)
                .monoBox()
            Text("Roll").monoLabel(size: 10)
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(Text("Frame \(model.taken)"))
    }

    @ViewBuilder
    private var finishButton: some View {
        if model.canFinishEarly {
            Button { confirmFinish = true } label: {
                Text("Finish early")
                    .monoLabel(size: 10, color: Theme.text)
                    .multilineTextAlignment(.center)
                    .frame(width: 64, height: 56)
                    .monoBox()
            }
            .buttonStyle(.plain)
        }
    }
}

/// Four amber corner brackets, 20pt long.
private struct FramingBrackets: Shape {
    func path(in rect: CGRect) -> Path {
        let length: CGFloat = 20
        var path = Path()
        for (x, dx) in [(rect.minX, length), (rect.maxX, -length)] {
            for (y, dy) in [(rect.minY, length), (rect.maxY, -length)] {
                path.move(to: CGPoint(x: x + dx, y: y))
                path.addLine(to: CGPoint(x: x, y: y))
                path.addLine(to: CGPoint(x: x, y: y + dy))
            }
        }
        return path
    }
}

#Preview {
    ViewfinderView().environment(AppEnvironment.preview())
}
