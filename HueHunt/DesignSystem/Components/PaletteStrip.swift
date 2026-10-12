import Foundation
import PaletteEngine
import SwiftUI

// A horizontal strip of equal-width swatches, shared by the live Capture preview,
// the catch confirmation, and the Library grid. Weight-proportional widths are
// separate, later UI work.
struct PaletteStrip: View {
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

extension Palette {
  // Bridges the storage model back to PaletteEngine's type. The model itself stays
  // free of this dependency, this extension only exists where the app already needs it.
  var decodedColors: [PaletteColor] {
    (try? JSONDecoder().decode([PaletteColor].self, from: colorsData)) ?? []
  }
}
