import Foundation
import simd

// Color space conversions between sRGB, linear RGB, XYZ, and CIELAB (D65 white point).
public enum ColorSpace {
  private static let rgbToXYZMatrix = simd_float3x3(
    SIMD3<Float>(0.4124564, 0.2126729, 0.0193339),
    SIMD3<Float>(0.3575761, 0.7151522, 0.1191920),
    SIMD3<Float>(0.1804375, 0.0721750, 0.9503041)
  )
  private static let xyzToRGBMatrix = rgbToXYZMatrix.inverse
  private static let d65White = SIMD3<Float>(0.95047, 1.0, 1.08883)

  public static func srgbToLinear(_ c: Float) -> Float {
    c <= 0.04045 ? c / 12.92 : pow((c + 0.055) / 1.055, 2.4)
  }

  public static func linearToSRGB(_ c: Float) -> Float {
    c <= 0.0031308 ? c * 12.92 : 1.055 * pow(c, 1 / 2.4) - 0.055
  }

  public static func srgbToLab(_ srgb: SIMD3<Float>) -> SIMD3<Float> {
    let linear = SIMD3(srgbToLinear(srgb.x), srgbToLinear(srgb.y), srgbToLinear(srgb.z))
    return xyzToLab(rgbToXYZMatrix * linear)
  }

  public static func labToSRGB(_ lab: SIMD3<Float>) -> SIMD3<Float> {
    let linear = xyzToRGBMatrix * labToXYZ(lab)
    let srgb = SIMD3(linearToSRGB(linear.x), linearToSRGB(linear.y), linearToSRGB(linear.z))
    return clamp(srgb, min: SIMD3(repeating: 0), max: SIMD3(repeating: 1))
  }

  public static func hex(from srgb: SIMD3<Float>) -> String {
    let clamped = clamp(srgb, min: SIMD3(repeating: 0), max: SIMD3(repeating: 1))
    let r = UInt8((clamped.x * 255).rounded())
    let g = UInt8((clamped.y * 255).rounded())
    let b = UInt8((clamped.z * 255).rounded())
    return String(format: "#%02X%02X%02X", r, g, b)
  }

  public static func rgb(fromHex hex: String) -> SIMD3<Float> {
    var sanitized = hex
    if sanitized.hasPrefix("#") { sanitized.removeFirst() }
    let value = UInt32(sanitized, radix: 16) ?? 0
    let r = Float((value >> 16) & 0xFF) / 255
    let g = Float((value >> 8) & 0xFF) / 255
    let b = Float(value & 0xFF) / 255
    return SIMD3(r, g, b)
  }

  private static func xyzToLab(_ xyz: SIMD3<Float>) -> SIMD3<Float> {
    let t = xyz / d65White
    let f = SIMD3(labF(t.x), labF(t.y), labF(t.z))
    return SIMD3(116 * f.y - 16, 500 * (f.x - f.y), 200 * (f.y - f.z))
  }

  private static func labToXYZ(_ lab: SIMD3<Float>) -> SIMD3<Float> {
    let fy = (lab.x + 16) / 116
    let fx = fy + lab.y / 500
    let fz = fy - lab.z / 200
    return SIMD3(labFInverse(fx), labFInverse(fy), labFInverse(fz)) * d65White
  }

  // CIE standard piecewise curve, linear near zero to avoid an infinite derivative there.
  private static func labF(_ t: Float) -> Float {
    let delta: Float = 6.0 / 29.0
    return t > delta * delta * delta ? cbrt(t) : t / (3 * delta * delta) + 4.0 / 29.0
  }

  private static func labFInverse(_ t: Float) -> Float {
    let delta: Float = 6.0 / 29.0
    return t > delta ? t * t * t : 3 * delta * delta * (t - 4.0 / 29.0)
  }
}
