import simd

// A single color in an extracted palette, with its position in Lab space and its share of the image.
public struct PaletteColor: Codable, Hashable, Sendable {
    public let hex: String
    public let lab: SIMD3<Float>
    public let weight: Float
    public let name: String

    public init(hex: String, lab: SIMD3<Float>, weight: Float, name: String) {
        self.hex = hex
        self.lab = lab
        self.weight = weight
        self.name = name
    }
}

// The result of running the extraction pipeline on a single frame or image.
public struct ExtractedPalette: Sendable, Equatable {
    public let colors: [PaletteColor]

    public init(colors: [PaletteColor]) {
        self.colors = colors
    }
}

// Runs the extraction pipeline off the main thread so camera frames never block the UI.
public actor PaletteExtractor {
    public init() {}
}
