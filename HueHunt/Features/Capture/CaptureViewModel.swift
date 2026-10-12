import AVFoundation
import PaletteEngine

@Observable
@MainActor
final class CaptureViewModel {
  private(set) var palette = ExtractedPalette(colors: [])

  private let cameraService = CameraService()
  private let paletteExtractor = PaletteExtractor()
  private var frameTask: Task<Void, Never>?

  var previewLayer: AVCaptureVideoPreviewLayer {
    cameraService.previewLayer
  }

  func start() {
    let stream = cameraService.makeFrameStream()
    cameraService.start()
    frameTask = Task {
      for await sample in stream {
        palette = await paletteExtractor.extract(pixels: sample.pixels)
      }
    }
  }

  func stop() {
    frameTask?.cancel()
    frameTask = nil
    cameraService.stop()
  }
}
