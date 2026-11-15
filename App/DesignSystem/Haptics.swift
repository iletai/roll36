import UIKit

enum Haptics {
    static func shutter() {
        UIImpactFeedbackGenerator(style: .rigid).impactOccurred()
    }

    static func developed() {
        UINotificationFeedbackGenerator().notificationOccurred(.success)
    }

    static func selection() {
        UISelectionFeedbackGenerator().selectionChanged()
    }
}
