import AVFoundation
import Foundation
import PaletteEngine
import SwiftData

@Observable
@MainActor
final class CaptureViewModel {
  private(set) var palette = ExtractedPalette(colors: [])
  private(set) var isCameraAccessDenied = false

  private let cameraService = CameraService()
  private let paletteExtractor = PaletteExtractor()
  private var frameTask: Task<Void, Never>?

  var previewLayer: AVCaptureVideoPreviewLayer {
    cameraService.previewLayer
  }

  // Checks camera authorization before starting the session, prompting the system dialog only
  // when the user has never been asked. A denied or restricted status shows an empty state
  // instead of a blank preview (PRD F1 AC2).
  func prepareAndStart() async {
    switch CameraService.authorizationStatus {
    case .authorized:
      isCameraAccessDenied = false
      start()
    case .notDetermined:
      let granted = await CameraService.requestAccess()
      isCameraAccessDenied = !granted
      if granted { start() }
    default:
      isCameraAccessDenied = true
    }
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
