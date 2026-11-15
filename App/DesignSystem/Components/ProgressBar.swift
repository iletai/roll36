import SwiftUI

/// Flat 3pt track; `progress` is clamped to 0...1.
struct ProgressBar: View {
    let progress: Double
    var tint: Color = Theme.amber

    private var clamped: Double { min(max(progress, 0), 1) }

    var body: some View {
        Rectangle()
            .fill(Theme.line)
            .frame(height: 3)
            .overlay(alignment: .leading) {
                GeometryReader { proxy in
                    Rectangle().fill(tint).frame(width: proxy.size.width * clamped)
                }
            }
            .accessibilityElement(children: .ignore)
            .accessibilityValue(Text(clamped, format: .percent.precision(.fractionLength(0))))
    }
}

#Preview {
    VStack(spacing: 16) {
        ProgressBar(progress: 0.42)
        ProgressBar(progress: 1, tint: Theme.green)
    }
    .padding()
    .background(Theme.bg)
}
