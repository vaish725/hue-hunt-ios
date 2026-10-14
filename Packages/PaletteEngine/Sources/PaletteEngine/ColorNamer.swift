import simd

// Maps a Lab color to its nearest named color by dE76.
//
// The reference table combines a small hand-picked set with the full CSS Color Module
// Extended Color Keywords list (the standard 147 X11-derived names, e.g. "cornflowerblue",
// "rebeccapurple"), deduplicated by hex and by name against the hand-picked set. That's 141
// entries, well short of the product spec's ~1,500. Reaching that size is a content/data task,
// sourcing and precomputing Lab values for a real large color-name dataset, separate from this
// engine logic, and should extend this list later without changing the lookup API.
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

  private static let referenceColors: [(String, String)] =
    [
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
    ] + cssExtendedColors

  // The CSS Color Module Level 4 Extended Color Keywords (the standard X11-derived name list),
  // alphabetical, minus any entry whose hex or name already appears in the hand-picked set above
  // (e.g. "aqua" and "fuchsia" are exact-hex duplicates of "Cyan" and "Magenta"; British "grey"
  // spellings are dropped in favor of the "gray" ones already used above).
  private static let cssExtendedColors: [(String, String)] = [
    ("Alice Blue", "#F0F8FF"), ("Aquamarine", "#7FFFD4"), ("Azure", "#F0FFFF"),
    ("Bisque", "#FFE4C4"), ("Blanched Almond", "#FFEBCD"), ("Blue Violet", "#8A2BE2"),
    ("Burlywood", "#DEB887"), ("Cadet Blue", "#5F9EA0"), ("Chartreuse", "#7FFF00"),
    ("Chocolate", "#D2691E"), ("Cornflower Blue", "#6495ED"), ("Cornsilk", "#FFF8DC"),
    ("Dark Blue", "#00008B"), ("Dark Cyan", "#008B8B"), ("Dark Goldenrod", "#B8860B"),
    ("Dark Gray", "#A9A9A9"), ("Dark Green", "#006400"), ("Dark Khaki", "#BDB76B"),
    ("Dark Magenta", "#8B008B"), ("Dark Olive Green", "#556B2F"), ("Dark Orange", "#FF8C00"),
    ("Dark Orchid", "#9932CC"), ("Dark Red", "#8B0000"), ("Dark Salmon", "#E9967A"),
    ("Dark Sea Green", "#8FBC8F"), ("Dark Slate Blue", "#483D8B"), ("Dark Slate Gray", "#2F4F4F"),
    ("Dark Turquoise", "#00CED1"), ("Dark Violet", "#9400D3"), ("Deep Pink", "#FF1493"),
    ("Deep Sky Blue", "#00BFFF"), ("Dim Gray", "#696969"), ("Dodger Blue", "#1E90FF"),
    ("Firebrick", "#B22222"), ("Floral White", "#FFFAF0"), ("Gainsboro", "#DCDCDC"),
    ("Ghost White", "#F8F8FF"), ("Goldenrod", "#DAA520"), ("Green Yellow", "#ADFF2F"),
    ("Honeydew", "#F0FFF0"), ("Indian Red", "#CD5C5C"), ("Khaki", "#F0E68C"),
    ("Lavender Blush", "#FFF0F5"), ("Lawn Green", "#7CFC00"), ("Lemon Chiffon", "#FFFACD"),
    ("Light Blue", "#ADD8E6"), ("Light Coral", "#F08080"), ("Light Cyan", "#E0FFFF"),
    ("Light Goldenrod Yellow", "#FAFAD2"), ("Light Gray", "#D3D3D3"), ("Light Green", "#90EE90"),
    ("Light Pink", "#FFB6C1"), ("Light Salmon", "#FFA07A"), ("Light Sea Green", "#20B2AA"),
    ("Light Sky Blue", "#87CEFA"), ("Light Slate Gray", "#778899"),
    ("Light Steel Blue", "#B0C4DE"), ("Light Yellow", "#FFFFE0"), ("Linen", "#FAF0E6"),
    ("Medium Aquamarine", "#66CDAA"), ("Medium Blue", "#0000CD"), ("Medium Orchid", "#BA55D3"),
    ("Medium Purple", "#9370DB"), ("Medium Sea Green", "#3CB371"),
    ("Medium Slate Blue", "#7B68EE"), ("Medium Spring Green", "#00FA9A"),
    ("Medium Turquoise", "#48D1CC"), ("Medium Violet Red", "#C71585"),
    ("Midnight Blue", "#191970"), ("Mint Cream", "#F5FFFA"), ("Misty Rose", "#FFE4E1"),
    ("Moccasin", "#FFE4B5"), ("Navajo White", "#FFDEAD"), ("Old Lace", "#FDF5E6"),
    ("Olive Drab", "#6B8E23"), ("Orange Red", "#FF4500"), ("Orchid", "#DA70D6"),
    ("Pale Goldenrod", "#EEE8AA"), ("Pale Green", "#98FB98"), ("Pale Turquoise", "#AFEEEE"),
    ("Pale Violet Red", "#DB7093"), ("Papaya Whip", "#FFEFD5"), ("Peru", "#CD853F"),
    ("Plum", "#DDA0DD"), ("Powder Blue", "#B0E0E6"), ("Rebecca Purple", "#663399"),
    ("Rosy Brown", "#BC8F8F"), ("Royal Blue", "#4169E1"), ("Sandy Brown", "#F4A460"),
    ("Sea Green", "#2E8B57"), ("Seashell", "#FFF5EE"), ("Silver", "#C0C0C0"),
    ("Slate Blue", "#6A5ACD"), ("Snow", "#FFFAFA"), ("Spring Green", "#00FF7F"),
    ("Steel Blue", "#4682B4"), ("Thistle", "#D8BFD8"), ("Tomato", "#FF6347"),
    ("Wheat", "#F5DEB3"), ("White Smoke", "#F5F5F5"), ("Yellow Green", "#9ACD32"),
  ]
}
