import SwiftUI

/// A film negative strip around a photo: sprocket holes above and below, edge text on the rail. Plain shapes only.
struct NegativeFrame: View {
    let image: UIImage?
    var originalImage: UIImage?
    let filmName: String
    var isBusy = false

    @State private var isHoldingOriginal = false
    @State private var isComparingToggle = false

    private static let photoHeight: CGFloat = 260

    private var isShowingOriginal: Bool {
        isHoldingOriginal || isComparingToggle
    }

    private var displayImage: UIImage? {
        if isShowingOriginal, let originalImage {
            return originalImage
        }
        return image
    }

    var body: some View {
        VStack(spacing: 8) {
            rail(alignment: .leading) {
                Text(verbatim: filmName).monoLabel(size: 10, color: Theme.amber).lineLimit(1)
                Text(verbatim: "▸ 09A").monoLabel(size: 10)
            }
            photo
            rail(alignment: .trailing) {
                Text(verbatim: "|||| | | ||||| ||").monoLabel(size: 10, color: Theme.amber)
                Text(verbatim: "10").monoLabel(size: 10)
            }
        }
        .padding(8)
        .background(Theme.surface, in: RoundedRectangle(cornerRadius: Theme.boxRadius))
        .overlay(RoundedRectangle(cornerRadius: Theme.boxRadius).strokeBorder(Theme.line, lineWidth: 1))
    }

    private var photo: some View {
        ZStack {
            Color.black
            if let displayImage {
                Image(uiImage: displayImage)
                    .resizable()
                    .scaledToFit()
                    .accessibilityLabel(isShowingOriginal ? "Original photo" : "Selected photo with film stock")
            } else {
                emptyPrompt
            }
        }
        .frame(maxWidth: .infinity)
        .frame(height: Self.photoHeight)
        .clipped()
        .simultaneousGesture(
            DragGesture(minimumDistance: 0)
                .onChanged { _ in
                    if originalImage != nil && !isBusy {
                        isHoldingOriginal = true
                    }
                }
                .onEnded { _ in
                    isHoldingOriginal = false
                }
        )
        .overlay(alignment: .bottomLeading) {
            if isBusy {
                HStack(spacing: 6) {
                    ProgressView()
                        .controlSize(.mini)
                        .tint(Theme.amber)
                    Text("Developing preview…")
                        .monoLabel(size: 10, color: Theme.text)
                }
                .padding(6)
                .background(Theme.bg.opacity(0.85), in: RoundedRectangle(cornerRadius: Theme.boxRadius))
                .padding(8)
            }
        }
        .overlay(alignment: .topTrailing) {
            if originalImage != nil && !isBusy {
                compareControls
                    .padding(8)
            }
        }
        .overlay(alignment: .center) {
            if isHoldingOriginal {
                Text("ORIGINAL")
                    .monoLabel(size: 11, color: Theme.bg)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(Theme.amber, in: Capsule())
                    .shadow(radius: 4)
                    .transition(.opacity)
            }
        }
    }

    private var emptyPrompt: some View {
        VStack(spacing: Theme.spacingM) {
            ZStack {
                Circle()
                    .fill(Theme.card)
                    .frame(width: 54, height: 54)
                    .overlay(Circle().strokeBorder(Theme.amber.opacity(0.4), lineWidth: 1))
                Image(systemName: "photo.badge.plus")
                    .font(.system(size: 24))
                    .foregroundStyle(Theme.amber)
            }

            VStack(spacing: 4) {
                Text("PICK A PHOTO")
                    .monoDisplay(size: 14, color: Theme.text)
                Text("Tap here to choose a photo to apply a film look")
                    .monoLabel(size: 10, color: Theme.muted)
            }

            HStack(spacing: 6) {
                Image(systemName: "plus.circle.fill")
                    .font(.system(size: 12))
                Text("PICK NOW")
                    .monoLabel(size: 11, color: Theme.bg)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
            .background(Theme.amber, in: Capsule())
        }
        .padding(Theme.spacingM)
    }

    private var compareControls: some View {
        HStack(spacing: 6) {
            Button {
                withAnimation(.easeInOut(duration: 0.15)) {
                    isComparingToggle.toggle()
                }
            } label: {
                HStack(spacing: 4) {
                    Image(systemName: isShowingOriginal ? "eye.fill" : "eye")
                        .font(.system(size: 9))
                    Text(isShowingOriginal ? "ORIGINAL" : "FILM LOOK")
                        .monoLabel(size: 9, color: isShowingOriginal ? Theme.bg : Theme.amber)
                }
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(isShowingOriginal ? Theme.amber : Theme.bg.opacity(0.85), in: Capsule())
                .overlay(Capsule().strokeBorder(Theme.amber, lineWidth: 1))
            }
            .buttonStyle(.plain)

            Text("Hold to compare")
                .monoLabel(size: 9, color: Theme.muted)
                .padding(.horizontal, 6)
                .padding(.vertical, 4)
                .background(Theme.bg.opacity(0.75), in: RoundedRectangle(cornerRadius: Theme.boxRadius))
        }
    }

    /// Row of sprocket holes with a caption layered over the right or left end.
    private func rail(alignment: Alignment, @ViewBuilder caption: () -> some View) -> some View {
        ZStack {
            HStack(spacing: 8) {
                ForEach(0 ..< 8, id: \.self) { _ in
                    RoundedRectangle(cornerRadius: 2)
                        .strokeBorder(Theme.line, lineWidth: 1)
                        .frame(height: 14)
                }
            }
            HStack(spacing: 6, content: caption)
                .padding(.horizontal, 4)
                .background(Theme.surface)
                .frame(maxWidth: .infinity, alignment: alignment)
        }
    }
}

#Preview {
    NegativeFrame(image: nil, filmName: "Portra 400")
        .padding()
        .background(Theme.bg)
}
