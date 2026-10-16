import PaletteEngine
import SwiftUI

// Derives the app's accent color from the user's most recent palette (PRD 11.3): the
// highest-chroma color that still reaches a minimum contrast against the background, falling
// back to the system accent (nil) when nothing qualifies.
enum PaletteTint {
  static func accentColor(for colors: [PaletteColor], isDarkBackground: Bool) -> Color? {
    let background = SIMD3<Float>(repeating: isDarkBackground ? 0 : 1)
    let byChroma = colors.sorted { chroma($0.lab) > chroma($1.lab) }
    for color in byChroma {
      let rgb = ColorSpace.labToSRGB(color.lab)
      if Contrast.contrastRatio(rgb, background) >= 3 {
        return Color(paletteHex: color.hex)
      }
    }
    return nil
  }

  private static func chroma(_ lab: SIMD3<Float>) -> Float {
    (lab.y * lab.y + lab.z * lab.z).squareRoot()
  }
}
