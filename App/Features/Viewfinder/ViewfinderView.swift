import SwiftUI

/// Camera tab (PLAN §13.1). The view model needs the environment, so it is built on first appearance.
/// `isTabActive` is false when another tab is selected; the camera pauses while hidden and resumes on return.
struct ViewfinderView: View {
    @Environment(AppEnvironment.self) private var env
    @State private var model: ViewfinderViewModel?
    var isTabActive: Bool = true

    var body: some View {
        Group {
            if let model {
                ViewfinderContent(model: model, isTabActive: isTabActive)
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
    @AppStorage("camera_show_grid") private var showGrid = false
    var isTabActive: Bool

    /// Camera runs only while the tab is active AND the app is in the foreground; cancellation stops it.
    private var cameraShouldRun: Bool { isTabActive && scenePhase == .active }

    var body: some View {
        VStack(spacing: 0) {
            topBar
            exposureLine
            preview
            stockRow
            controls
        }
        .background(Theme.bg.ignoresSafeArea())
        .task(id: cameraShouldRun) {
            guard cameraShouldRun else { return }
            await model.run()
        }
        .task(id: model.flashCount) {
            guard model.flashCount > 0, !reduceMotion else { return }
            flashVisible = true
            try? await Task.sleep(for: .milliseconds(120))
            flashVisible = false
        }
        .task(id: model.notice) {
            guard model.notice != nil else { return }
            try? await Task.sleep(for: .seconds(3))
            withAnimation(.easeInOut(duration: 0.25)) {
                model.dismissNotice()
            }
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

            RollCounter(taken: model.exposedCount, capacity: model.capacity)
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
                // Approximate look of the loaded stock; the real grade is applied when the frame is developed.
                Color(hex: model.stock.swatchHex).opacity(0.3).blendMode(.softLight).allowsHitTesting(false)
                if showGrid { GridOverlay() }
                HorizonLevel()
                if model.canShoot {
                    FocusOverlay(
                        onFocus: { point in Task { await env.camera.focus(atNormalizedPoint: point) } },
                        onExposureBias: { ev in Task { await env.camera.setExposureBias(ev) } }
                    )
                }
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
        .overlay(alignment: .top) {
            if let notice = model.notice {
                noticeBanner(notice)
                    .padding(.top, Theme.spacingM)
            }
        }
    }

    private func noticeBanner(_ text: LocalizedStringKey) -> some View {
        HStack(spacing: 8) {
            Image(systemName: "flask.fill")
                .font(.system(size: 14))
                .foregroundStyle(Theme.amber)
            Text(text)
                .monoLabel(size: 12, color: Theme.text)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .background(Theme.surface.opacity(0.95))
        .clipShape(RoundedRectangle(cornerRadius: Theme.cardRadius))
        .overlay {
            RoundedRectangle(cornerRadius: Theme.cardRadius)
                .strokeBorder(Theme.amber.opacity(0.6), lineWidth: 1)
        }
        .shadow(color: .black.opacity(0.5), radius: 8, y: 4)
        .onTapGesture {
            withAnimation(.easeInOut(duration: 0.25)) {
                model.dismissNotice()
            }
        }
        .transition(.move(edge: .top).combined(with: .opacity))
    }

    @ViewBuilder
    private var stateOverlay: some View {
        switch model.state {
        case .loading:
            ProgressView().tint(Theme.amber)
        case .rollFull:
            dimmed {
                if model.taken < model.capacity {
                    Text("Roll closed (\(model.taken)/\(model.capacity))").monoDisplay(size: 24)
                } else {
                    Text("Roll is full").monoDisplay(size: 24)
                }
                developControl
                if model.canLoadWhileClosed {
                    PrimaryButton(title: "Load \(model.stock.displayName)", systemImage: "film", style: .secondary) {
                        model.loadSelectedStock()
                    }
                }
            }
        case .noActiveRoll:
            dimmed {
                PrimaryButton(title: "Load \(model.stock.displayName)", systemImage: "film") { model.loadSelectedStock() }
            }
        default:
            EmptyView()
        }
    }

    /// "Develop now", or the countdown of the roll in the tank when the free tier cannot develop in parallel.
    private var developControl: some View {
        TimelineView(.periodic(from: .now, by: 1)) { context in
            if let readyAt = model.waitingUntil, readyAt > context.date {
                VStack(spacing: 6) {
                    Text("Waiting for previous roll").monoLabel(size: 12, color: Theme.amber)
                    Text("Remaining \(DevelopingTicker.remainingText(until: readyAt, now: context.date))")
                        .monoLabel(size: 12, color: Theme.text)
                }
            } else {
                PrimaryButton(title: "Develop now", systemImage: "flask") { model.developNow() }
            }
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
            Button {
                if model.canChangeStock { model.showStockPicker = true } else { model.explainLockedStock() }
            } label: { stockChip }
                .buttonStyle(.plain)
                .accessibilityHint(model.canChangeStock ? Text("Choose film stock") : Text("Film loaded"))
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
            if !model.canChangeStock {
                Image(systemName: "lock.fill").font(.system(size: 10)).foregroundStyle(Theme.muted)
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
            Text(verbatim: "#\(model.exposedCount)")
                .monoLabel(size: 14, color: Theme.text)
                .frame(width: 56, height: 56)
                .monoBox()
            Text("Roll").monoLabel(size: 10)
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(Text("Frame \(model.exposedCount)"))
    }

    @ViewBuilder
    private var finishButton: some View {
        if model.canFinishEarly {
            Button { confirmFinish = true } label: {
                VStack(spacing: 4) {
                    Image(systemName: "film")
                        .font(.system(size: 16))
                        .foregroundStyle(Theme.amber)
                    Text("Finish early")
                        .monoLabel(size: 10, color: Theme.text)
                        .lineLimit(1)
                }
                .padding(.horizontal, 10)
                .frame(height: 56)
                .monoBox()
            }
            .buttonStyle(.plain)
            .accessibilityLabel(Text("Finish roll early"))
        }
    }
}

/// Four amber corner brackets, 20pt long.
private nonisolated struct FramingBrackets: Shape {
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
