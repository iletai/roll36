import SwiftUI

/// A film negative strip around a photo: sprocket holes above and below, edge text on the rail. Plain shapes only.
struct NegativeFrame: View {
    let image: UIImage?
    let filmName: String
    var isBusy = false

    private static let photoHeight: CGFloat = 250

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
            if let image {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFit()
                    .accessibilityLabel("Selected photo")
            } else {
                VStack(spacing: Theme.spacingS) {
                    Image(systemName: "photo.badge.plus").font(.system(size: 28)).foregroundStyle(Theme.amber)
                    Text("Choose a photo").monoLabel(size: 12, color: Theme.text)
                }
            }
        }
        .frame(maxWidth: .infinity)
        .frame(height: Self.photoHeight)
        .clipped()
        .overlay(alignment: .bottomLeading) {
            if isBusy {
                Text("Developing preview…")
                    .monoLabel(size: 10, color: Theme.text)
                    .padding(6)
                    .background(Theme.bg.opacity(0.7), in: RoundedRectangle(cornerRadius: Theme.boxRadius))
                    .padding(8)
            }
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
