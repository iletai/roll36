import PhotosUI
import SwiftUI

/// Presented full screen from the Darkroom header (DECISIONS D8): pick a photo, choose a stock, develop it.
struct ImportView: View {
    @Environment(AppEnvironment.self) private var env
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        ImportContent(model: ImportViewModel(env: env)) { dismiss() }
    }
}

private struct ImportContent: View {
    @State private var model: ImportViewModel
    let close: () -> Void
    @Environment(AppEnvironment.self) private var env
    @State private var pickerItem: PhotosPickerItem?

    init(model: ImportViewModel, close: @escaping () -> Void) {
        _model = State(initialValue: model)
        self.close = close
    }

    var body: some View {
        VStack(spacing: 0) {
            header
            ScrollView {
                VStack(alignment: .leading, spacing: Theme.spacingL) {
                    introLine
                    PhotosPicker(selection: $pickerItem, matching: .images) {
                        NegativeFrame(image: model.image, filmName: model.stock.displayName, isBusy: model.isPreviewing)
                    }
                    .buttonStyle(.plain)
                    .accessibilityHint("Opens your photo library")
                    emulsionSelector
                    calibrationMatrix
                    if let message = model.errorMessage {
                        Text(message).monoLabel(size: 11, color: Theme.red)
                    }
                }
                .padding(Theme.spacingM)
            }
            actions
                .padding(Theme.spacingM)
        }
        .background(Theme.bg.ignoresSafeArea())
        .task(id: pickerItem) {
            guard let item = pickerItem else { return }
            if let data = try? await item.loadTransferable(type: Data.self) {
                await model.load(data)
            } else {
                model.loadFailed()
            }
        }
        .onChange(of: env.entitlements.isImportUnlimited) { model.refreshQuota() }
        .sheet(item: $model.paywall) { PaywallView(highlightStockID: $0.stockID) }
        #if DEBUG
            .task { await seedIfRequested() }
        #endif
    }

    // MARK: - Sections

    private var header: some View {
        ZStack {
            VStack(spacing: 2) {
                HStack(spacing: 6) {
                    Rectangle().fill(Theme.amber).frame(width: 6, height: 6)
                    Text("Darkroom").monoDisplay(size: 20)
                }
                Text("// Lab import station").monoLabel(size: 10, color: Theme.amber)
            }
            .accessibilityElement(children: .combine)
            .accessibilityAddTraits(.isHeader)
            HStack {
                Button(action: close) {
                    Image(systemName: "chevron.left")
                        .foregroundStyle(Theme.text)
                        .frame(width: 44, height: 44)
                        .monoBox()
                }
                .accessibilityLabel("Close")
                Spacer()
            }
        }
        .padding(.horizontal, Theme.spacingM)
        .padding(.vertical, Theme.spacingS)
    }

    private var introLine: some View {
        HStack(spacing: Theme.spacingS) {
            Rectangle().fill(Theme.amber).frame(width: 6, height: 6)
            Text("Apply emulsion to existing frame").monoLabel(size: 11, color: Theme.text)
        }
    }

    private var emulsionSelector: some View {
        VStack(alignment: .leading, spacing: Theme.spacingS) {
            HStack {
                Text("Emulsion selector [\(FilmCatalog.all.count) profiles]").monoLabel(size: 11, color: Theme.text)
                Spacer()
                Text("135 format // 36 exp").monoLabel(size: 10)
            }
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 12) {
                    ForEach(FilmCatalog.all) { profile in
                        EmulsionTile(profile: profile, isSelected: profile.id == model.stock.id, isLocked: model.isLocked(profile))
                            .onTapGesture { model.select(profile) }
                            .accessibilityAddTraits(.isButton)
                    }
                }
            }
            .padding(.horizontal, -Theme.spacingM)
            .contentMargins(.horizontal, Theme.spacingM, for: .scrollContent)
        }
    }

    private var calibrationMatrix: some View {
        VStack(alignment: .leading, spacing: Theme.spacingS) {
            HStack {
                Text("Chemical calibration matrix").monoLabel(size: 11, color: Theme.text)
                Spacer()
                Text("Bath 01 [standard]").monoLabel(size: 10, color: Theme.amber)
            }
            HStack(spacing: Theme.spacingS) {
                cell("Process", "\(model.stock.processCode) NOM")
                cell("Grain", String(format: "%.1f RMS", model.stock.grainIntensity * 10))
                cell("Temp", "38.0°C")
                cell("Agitation", "30s INT")
            }
        }
        .padding(Theme.spacingS)
        .monoBox(fill: Theme.bg)
    }

    private func cell(_ title: LocalizedStringKey, _ value: String) -> some View {
        VStack(spacing: 4) {
            Text(title).monoLabel(size: 9)
            Text(verbatim: value).monoLabel(size: 11, color: Theme.amber).lineLimit(1).minimumScaleFactor(0.6)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, Theme.spacingS)
        .monoBox(fill: Theme.surface)
        .accessibilityElement(children: .combine)
    }

    @ViewBuilder private var actions: some View {
        if model.phase == .developed {
            VStack(spacing: Theme.spacingS) {
                Label("Frame developed", systemImage: "checkmark.circle")
                    .monoLabel(size: 12, color: Theme.green)
                PrimaryButton(title: "Import another", systemImage: "photo.badge.plus") {
                    pickerItem = nil
                    model.reset()
                }
                PrimaryButton(title: "Close", style: .secondary, action: close)
            }
        } else {
            PrimaryButton(title: ctaTitle, systemImage: "flask") {
                Task { await model.develop() }
            }
            .disabled(!model.canDevelop)
            .opacity(model.canDevelop ? 1 : 0.4)
        }
    }

    private var ctaTitle: LocalizedStringKey {
        if model.phase == .developing { return "Developing…" }
        if let left = model.remaining { return "Develop frame — \(left) left" }
        return "Develop frame"
    }

    #if DEBUG
        /// UI verification only: `-seedImport` loads the mock camera frame as if it had been picked.
        private func seedIfRequested() async {
            guard CommandLine.arguments.contains("-seedImport") else { return }
            let camera = MockCameraService()
            try? await camera.start()
            if let data = try? await camera.capture() { await model.load(data) }
        }
    #endif
}

/// Compact emulsion tile (Import design); locked stocks stay selectable for preview.
private struct EmulsionTile: View {
    let profile: FilmProfile
    let isSelected: Bool
    let isLocked: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text(verbatim: profile.processCode)
                    .monoLabel(size: 10, color: Theme.bg)
                    .padding(.horizontal, 4)
                    .background(Theme.text, in: RoundedRectangle(cornerRadius: 2))
                Spacer()
                Text("ISO \(profile.iso)").monoLabel(size: 10)
            }
            Text(verbatim: profile.displayName).monoDisplay(size: 15).lineLimit(1).minimumScaleFactor(0.6)
            Rectangle().fill(Theme.line).frame(height: Theme.lineWidth)
            Text(verbatim: profile.tagline).monoLabel(size: 9).lineLimit(2, reservesSpace: true)
            HStack {
                Text(isSelected ? "Ready" : "Standby").monoLabel(size: 9, color: isSelected ? Theme.amber : Theme.muted)
                Spacer()
                if isLocked {
                    Image(systemName: "lock.fill").font(.system(size: 10)).foregroundStyle(Theme.muted)
                        .accessibilityLabel("Locked")
                } else {
                    Image(systemName: isSelected ? "checkmark.circle" : "circle")
                        .font(.system(size: 12))
                        .foregroundStyle(isSelected ? Theme.amber : Theme.muted)
                }
            }
        }
        .padding(12)
        .frame(width: 176)
        .background(Theme.card, in: RoundedRectangle(cornerRadius: Theme.cardRadius))
        .overlay {
            RoundedRectangle(cornerRadius: Theme.cardRadius)
                .strokeBorder(isSelected ? Theme.amber : Theme.line, lineWidth: isSelected ? 2 : Theme.lineWidth)
        }
        .accessibilityElement(children: .combine)
    }
}
