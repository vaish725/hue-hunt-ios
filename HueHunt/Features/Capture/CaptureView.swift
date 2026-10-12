import CoreGraphics
import ImageIO
import PaletteEngine
import SwiftData
import SwiftUI

struct CaptureView: View {
  @Environment(\.modelContext) private var modelContext
  @State private var viewModel = CaptureViewModel()
  @State private var caughtPalette: Palette?
  @State private var catchCount = 0

  var body: some View {
    CameraPreview(previewLayer: viewModel.previewLayer)
      .ignoresSafeArea()
      .overlay(alignment: .bottom) {
        VStack(spacing: 24) {
          PaletteStrip(colors: viewModel.palette.colors)
          ShutterButton {
            catchCount += 1
            Task { caughtPalette = await viewModel.catchPalette(in: modelContext) }
          }
        }
        .padding(.horizontal, 16)
        .padding(.bottom, 32)
      }
      .sensoryFeedback(.impact(weight: .medium), trigger: catchCount)
      .sheet(item: $caughtPalette) { palette in
        CaughtPaletteSheet(palette: palette)
      }
      .onAppear { viewModel.start() }
      .onDisappear { viewModel.stop() }
  }
}

// Minimal 5-swatch strip proving the pipeline works end to end.
// Weight-proportional widths and the full catch animation are separate, later UI work.
private struct PaletteStrip: View {
  let colors: [PaletteColor]

  var body: some View {
    HStack(spacing: 4) {
      ForEach(colors, id: \.hex) { color in
        RoundedRectangle(cornerRadius: 12)
          .fill(Color(paletteHex: color.hex))
      }
    }
    .frame(height: 48)
  }
}

private struct ShutterButton: View {
  let action: () -> Void

  var body: some View {
    Button(action: action) {
      Circle()
        .strokeBorder(.white, lineWidth: 4)
        .frame(width: 72, height: 72)
        .background(Circle().fill(.white.opacity(0.3)))
    }
  }
}

// Stands in for the full Palette Detail screen (share card, contrast pairs, rename)
// until that feature is built. Just confirms a catch was saved with its colors.
private struct CaughtPaletteSheet: View {
  let palette: Palette

  private var colors: [PaletteColor] {
    (try? JSONDecoder().decode([PaletteColor].self, from: palette.colorsData)) ?? []
  }

  var body: some View {
    VStack(spacing: 16) {
      if let thumbnail = palette.thumbnail, let cgImage = makeCGImage(from: thumbnail) {
        Image(cgImage, scale: 1, label: Text(palette.name))
          .resizable()
          .scaledToFit()
          .clipShape(RoundedRectangle(cornerRadius: 16))
      }

      Text(palette.name)
        .font(.headline)

      ForEach(colors, id: \.hex) { color in
        HStack {
          RoundedRectangle(cornerRadius: 8)
            .fill(Color(paletteHex: color.hex))
            .frame(width: 32, height: 32)
          Text(color.hex)
          Spacer()
          Text(color.name)
            .foregroundStyle(.secondary)
        }
      }
    }
    .padding()
  }

  private func makeCGImage(from data: Data) -> CGImage? {
    guard let source = CGImageSourceCreateWithData(data as CFData, nil) else { return nil }
    return CGImageSourceCreateImageAtIndex(source, 0, nil)
  }
}

extension Color {
  init(paletteHex hex: String) {
    var sanitized = hex
    if sanitized.hasPrefix("#") { sanitized.removeFirst() }
    let value = UInt64(sanitized, radix: 16) ?? 0
    let red = Double((value >> 16) & 0xFF) / 255
    let green = Double((value >> 8) & 0xFF) / 255
    let blue = Double(value & 0xFF) / 255
    self.init(red: red, green: green, blue: blue)
  }
}
