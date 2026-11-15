import AVFoundation
import SwiftUI
import UIKit

/// Live sensor preview for `LiveCameraService`, a flat placeholder otherwise (simulator mock).
/// Fills its container; the parent decides about safe areas.
struct CameraPreviewView: View {
    let service: any CameraService

    var body: some View {
        if let live = service as? LiveCameraService {
            LivePreview(service: live)
        } else {
            ZStack {
                Color(red: 0x17 / 255, green: 0x14 / 255, blue: 0x0F / 255)
                Text("NO CAMERA (SIMULATOR)")
                    .font(.system(size: 11, weight: .medium, design: .monospaced))
                    .foregroundStyle(Color(red: 0x8A / 255, green: 0x80 / 255, blue: 0x72 / 255))
            }
        }
    }
}

/// The only UIKit in the app (PLAN §4.1): hosts AVCaptureVideoPreviewLayer.
private struct LivePreview: UIViewRepresentable {
    let service: LiveCameraService

    func makeUIView(context _: Context) -> PreviewUIView {
        let view = PreviewUIView()
        view.previewLayer.videoGravity = .resizeAspectFill
        service.connectPreview(view.previewLayer)
        return view
    }

    func updateUIView(_: PreviewUIView, context _: Context) {}

    final class PreviewUIView: UIView {
        override static var layerClass: AnyClass { AVCaptureVideoPreviewLayer.self }
        // swiftlint:disable:next force_cast
        var previewLayer: AVCaptureVideoPreviewLayer { layer as! AVCaptureVideoPreviewLayer }
    }
}
