import PaletteEngine
import SwiftUI

struct CaptureView: View {
  @State private var viewModel = CaptureViewModel()

  var body: some View {
    CameraPreview(previewLayer: viewModel.previewLayer)
      .ignoresSafeArea()
      .overlay(alignment: .bottom) {
        PaletteStrip(colors: viewModel.palette.colors)
          .padding(.horizontal, 16)
          .padding(.bottom, 32)
      }
      .onAppear { viewModel.start() }
      .onDisappear { viewModel.stop() }
  }
}

// Minimal 5-swatch strip proving the pipeline works end to end.
// Weight-proportional widths, catch animation, and haptics are separate, later UI work.
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
