import os
import SwiftUI

/// Developed frames of one roll as a 3-column contact sheet (PLAN §13.3). Frames are viewable only for `.developed` rolls (PLAN §18.5).
struct ContactSheetView: View {
    let roll: Roll

    @Environment(AppEnvironment.self) private var env
    @Environment(\.dismiss) private var dismiss
    @State private var detailStart = 0
    @State private var showDetail = false
    @State private var notice: LocalizedStringResource?

    private let columns = Array(repeating: GridItem(.flexible(), spacing: 8), count: 3)

    private var isViewable: Bool { roll.state() == .developed }
    private var shots: [Shot] { isViewable ? roll.shots.sorted { $0.index < $1.index } : [] }
    private var title: String {
        roll.isImportRoll ? String(localized: "Darkroom imports") : (FilmCatalog.profile(id: roll.stockID)?.displayName ?? roll.stockID)
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Theme.spacingM) {
                header
                if isViewable {
                    LazyVGrid(columns: columns, spacing: 8) {
                        ForEach(Array(shots.enumerated()), id: \.element.id) { offset, shot in
                            Button {
                                detailStart = offset
                                showDetail = true
                            } label: {
                                FrameThumbnail(shot: shot, imageStore: env.imageStore)
                                    .aspectRatio(3 / 4, contentMode: .fit)
                            }
                            .buttonStyle(.plain)
                            .accessibilityLabel(Text("Frame \(shot.index + 1)"))
                        }
                    }
                } else {
                    Text("This roll is not developed yet.").bodyText(color: Theme.muted)
                }
                if isViewable, !roll.isImportRoll {
                    PrimaryButton(title: "Load a new roll", systemImage: "camera", action: loadNewRoll)
                        .padding(.top, Theme.spacingS)
                }
            }
            .padding(Theme.spacingM)
        }
        .background(Theme.bg)
        .navigationBarTitleDisplayMode(.inline)
        .toolbarBackground(Theme.bg, for: .navigationBar)
        .toolbarBackground(.visible, for: .navigationBar)
        .tint(Theme.amber)
        .fullScreenCover(isPresented: $showDetail) { ShotDetailView(shots: shots, startIndex: detailStart) }
        .alert("ROLL 36", isPresented: Binding(get: { notice != nil }, set: { if !$0 { notice = nil } })) {
            Button("OK") {}
        } message: {
            if let notice { Text(notice) }
        }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(verbatim: title).monoDisplay(size: 26)
            HStack {
                Text(roll.createdAt, format: .dateTime.day().month(.abbreviated).year()).monoLabel(size: 12)
                Text("· \(shots.count) contacts").monoLabel(size: 12)
            }
        }
    }

    /// Starts the next roll with the selected stock (PLAN §13.3); only if it is unlocked and nothing is being shot.
    private func loadNewRoll() {
        guard env.entitlements.isUnlocked(stockID: env.selectedStockID) else {
            notice = "The selected film is locked. Pick another stock in the Library."
            return
        }
        guard (try? env.repository.currentRoll()) == nil else {
            notice = "Finish the roll you are shooting first."
            return
        }
        do {
            _ = try env.repository.startRoll(stockID: env.selectedStockID)
            env.selectedTab = .camera
            dismiss()
        } catch {
            Log.app.error("startRoll failed: \(error)")
            notice = "Couldn't load a new roll."
        }
    }
}

/// Thumbnail with the 2pt white print border of a contact sheet (PLAN §6.3). The parent decides the size.
struct FrameThumbnail: View {
    let shot: Shot
    let imageStore: ImageStore

    @State private var loadToken = 0

    var body: some View {
        Theme.surface
            .overlay {
                AsyncImage(url: imageStore.thumbnailURL(shot.thumbnailFilename)) { phase in
                    switch phase {
                    case let .success(image):
                        image.resizable().scaledToFill()
                    case .failure:
                        ThumbnailFailureView { loadToken += 1 }
                    case .empty:
                        ProgressView().tint(Theme.muted)
                    @unknown default:
                        ProgressView().tint(Theme.muted)
                    }
                }
            }
            .id(loadToken)
            .clipShape(RoundedRectangle(cornerRadius: 2))
            .overlay(RoundedRectangle(cornerRadius: 2).strokeBorder(Color.white, lineWidth: 2))
    }
}

/// Placeholder shown when a thumbnail cannot be loaded.
private struct ThumbnailFailureView: View {
    let retry: () -> Void

    var body: some View {
        VStack(spacing: 4) {
            Image(systemName: "photo")
                .font(.title3)
                .foregroundStyle(Theme.red)
            Text("Unable to load")
                .monoLabel(size: 8, color: Theme.red)
            Button("Retry", action: retry)
                .monoLabel(size: 8, color: Theme.amber)
        }
    }
}
