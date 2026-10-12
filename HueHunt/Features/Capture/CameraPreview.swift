import AVFoundation
import SwiftUI

// Wraps AVCaptureVideoPreviewLayer, the one permitted UIKit usage in this project.
struct CameraPreview: UIViewRepresentable {
  let previewLayer: AVCaptureVideoPreviewLayer

  func makeUIView(context: Context) -> PreviewView {
    let view = PreviewView()
    previewLayer.videoGravity = .resizeAspectFill
    view.layer.addSublayer(previewLayer)
    return view
  }

  func updateUIView(_ uiView: PreviewView, context: Context) {
    previewLayer.frame = uiView.bounds
  }

  final class PreviewView: UIView {
    override func layoutSubviews() {
      super.layoutSubviews()
      layer.sublayers?.first?.frame = bounds
    }
  }
}
