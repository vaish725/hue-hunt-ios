import AVFoundation
import Foundation
import PaletteEngine
import SwiftData

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

  // Freezes the current palette, grabs a thumbnail of the live frame, and persists both.
  func catchPalette(in context: ModelContext) async -> Palette? {
    let caughtPalette = palette
    guard
      !caughtPalette.colors.isEmpty,
      let colorsData = try? JSONEncoder().encode(caughtPalette.colors)
    else { return nil }

    let thumbnail = await cameraService.captureThumbnail()
    let record = Palette(
      name: defaultName(for: caughtPalette),
      colorsData: colorsData,
      thumbnail: thumbnail
    )
    context.insert(record)
    return record
  }

  private func defaultName(for palette: ExtractedPalette) -> String {
    let dominant = palette.colors.first?.name ?? "Palette"
    let formatter = DateFormatter()
    formatter.dateStyle = .medium
    return "\(dominant) \(formatter.string(from: .now))"
  }
}
