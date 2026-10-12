import simd

// Maps a Lab color to its nearest named color by dE76.
//
// This ships with a small curated set of common names as a starting point. The product spec
// calls for a much larger reference table (around 1,500 entries); that is a content/data task,
// sourcing and precomputing Lab values for a real color-name dataset, separate from this engine
// logic, and should replace or extend this list later without changing the lookup API.
public enum ColorNamer {
  private struct NamedColor {
    let name: String
    let lab: SIMD3<Float>
  }

  private static let colors: [NamedColor] = referenceColors.map {
    NamedColor(name: $0.0, lab: ColorSpace.srgbToLab(ColorSpace.rgb(fromHex: $0.1)))
  }

  public static func name(for lab: SIMD3<Float>) -> String {
    var bestName = "Unknown"
    var bestDistance = Float.greatestFiniteMagnitude
    for color in colors {
      let distance = simd_distance(lab, color.lab)
      if distance < bestDistance {
        bestDistance = distance
        bestName = color.name
      }
    }
    return bestName
  }

  private static let referenceColors: [(String, String)] = [
    ("Black", "#000000"), ("White", "#FFFFFF"), ("Gray", "#808080"),
    ("Red", "#FF0000"), ("Crimson", "#DC143C"), ("Maroon", "#800000"),
    ("Orange", "#FFA500"), ("Burnt Sienna", "#A0522D"), ("Coral", "#FF7F50"),
    ("Yellow", "#FFFF00"), ("Gold", "#FFD700"), ("Mustard", "#C5A028"),
    ("Olive", "#808000"), ("Lime", "#32CD32"), ("Green", "#008000"),
    ("Forest Green", "#228B22"), ("Teal", "#008080"), ("Cyan", "#00FFFF"),
    ("Sky Blue", "#87CEEB"), ("Blue", "#0000FF"), ("Navy", "#000080"),
    ("Indigo", "#4B0082"), ("Purple", "#800080"), ("Violet", "#8F00FF"),
    ("Magenta", "#FF00FF"), ("Pink", "#FFC0CB"), ("Hot Pink", "#FF69B4"),
    ("Brown", "#8B4513"), ("Tan", "#D2B48C"), ("Beige", "#F5F5DC"),
    ("Ivory", "#FFFFF0"), ("Charcoal", "#36454F"), ("Slate", "#708090"),
    ("Turquoise", "#40E0D0"), ("Mint", "#98FF98"), ("Lavender", "#E6E6FA"),
    ("Peach", "#FFDAB9"), ("Salmon", "#FA8072"), ("Rust", "#B7410E"),
    ("Amber", "#FFBF00"),
  ]
}
