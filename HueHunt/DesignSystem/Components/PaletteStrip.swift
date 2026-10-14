import Foundation
import PaletteEngine
import SwiftUI

// A horizontal strip of swatches sized by each color's share of the image, shared by the
// live Capture preview, the catch confirmation, and the Library grid.
struct PaletteStrip: View {
  let colors: [PaletteColor]

  private let spacing: CGFloat = 4

  var body: some View {
    GeometryReader { geometry in
      let availableWidth = max(geometry.size.width - spacing * CGFloat(max(colors.count - 1, 0)), 0)
      HStack(spacing: spacing) {
        ForEach(colors, id: \.hex) { color in
          RoundedRectangle(cornerRadius: 12)
            .fill(Color(paletteHex: color.hex))
            .frame(width: availableWidth * CGFloat(color.weight))
        }
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

#Preview {
  let weighted: [(String, Float)] = [
    ("#FF6B6B", 0.45), ("#4ECDC4", 0.25), ("#FFD93D", 0.15), ("#1A535C", 0.10), ("#F7FFF7", 0.05),
  ]
  let colors = weighted.map { hex, weight in
    PaletteColor(hex: hex, lab: SIMD3(0, 0, 0), weight: weight, name: hex)
  }
  return PaletteStrip(colors: colors)
    .padding()
}
