import simd

// WCAG 2.x relative luminance and contrast ratio calculations.
public enum Contrast {
    public static func relativeLuminance(of srgb: SIMD3<Float>) -> Float {
        let linear = SIMD3(
            ColorSpace.srgbToLinear(srgb.x),
            ColorSpace.srgbToLinear(srgb.y),
            ColorSpace.srgbToLinear(srgb.z)
        )
        return 0.2126 * linear.x + 0.7152 * linear.y + 0.0722 * linear.z
    }

    public static func contrastRatio(_ a: SIMD3<Float>, _ b: SIMD3<Float>) -> Float {
        let lighter = max(relativeLuminance(of: a), relativeLuminance(of: b))
        let darker = min(relativeLuminance(of: a), relativeLuminance(of: b))
        return (lighter + 0.05) / (darker + 0.05)
    }

    public static func passesAA(_ ratio: Float) -> Bool { ratio >= 4.5 }
    public static func passesAAA(_ ratio: Float) -> Bool { ratio >= 7.0 }
}
