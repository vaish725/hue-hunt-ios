import Testing
import simd

@testable import PaletteEngine

@Test func paletteEngineModuleLoads() {
  #expect(ExtractedPalette(colors: []).colors.isEmpty)
}

@Test func sRGBToLabRoundTrip() {
  for _ in 0..<1000 {
    let srgb = SIMD3<Float>(.random(in: 0...1), .random(in: 0...1), .random(in: 0...1))
    let roundTripped = ColorSpace.labToSRGB(ColorSpace.srgbToLab(srgb))
    #expect(abs(roundTripped.x - srgb.x) <= 1.0 / 255.0)
    #expect(abs(roundTripped.y - srgb.y) <= 1.0 / 255.0)
    #expect(abs(roundTripped.z - srgb.z) <= 1.0 / 255.0)
  }
}

@Test func knownReferenceValue() {
  let lab = ColorSpace.srgbToLab(ColorSpace.rgb(fromHex: "#FF0000"))
  #expect(abs(lab.x - 53.24) < 0.1)
  #expect(abs(lab.y - 80.09) < 0.1)
  #expect(abs(lab.z - 67.20) < 0.1)
}

@Test func kMeansRecoversSyntheticColors() {
  let seedHexValues = ["#FF0000", "#00FF00", "#0000FF", "#FFFF00", "#000000"]
  let seedColors = seedHexValues.map { ColorSpace.srgbToLab(ColorSpace.rgb(fromHex: $0)) }
  var points: [SIMD3<Float>] = []
  for color in seedColors {
    points.append(contentsOf: Array(repeating: color, count: 200))
  }

  var kMeans = KMeans(k: 5, seed: 42)
  let clusters = kMeans.run(on: points)

  for seedColor in seedColors {
    let closest =
      clusters.map { simd_distance($0.centroid, seedColor) }.min() ?? .greatestFiniteMagnitude
    #expect(closest < 2.0)
  }
}

@Test func kMeansIsDeterministic() {
  let points = (0..<500).map { _ in
    SIMD3<Float>(.random(in: 0...100), .random(in: -50...50), .random(in: -50...50))
  }
  var first = KMeans(k: 5, seed: 42)
  var second = KMeans(k: 5, seed: 42)
  let resultA = first.run(on: points)
  let resultB = second.run(on: points)
  for (a, b) in zip(resultA, resultB) {
    #expect(a.centroid == b.centroid)
  }
}

@Test func weightsSumToOneAndCountIsFive() async {
  let extractor = PaletteExtractor()
  let pixels = (0..<2000).map { _ in
    SIMD3<Float>(.random(in: 0...1), .random(in: 0...1), .random(in: 0...1))
  }
  let palette = await extractor.extract(pixels: pixels)
  #expect(palette.colors.count == 5)
  let totalWeight = palette.colors.reduce(Float(0)) { $0 + $1.weight }
  #expect(abs(totalWeight - 1.0) < 0.001)
}

@Test func smootherNeverOvershootsRawTarget() {
  let smoother = PaletteSmoother(alpha: 0.35)
  let previous: [SIMD3<Float>] = [SIMD3(50, 0, 0)]
  let current: [SIMD3<Float>] = [SIMD3(60, 10, 10)]
  let smoothed = smoother.smooth(current: current, previous: previous)
  let rawDistance = simd_distance(current[0], previous[0])
  let smoothedDistance = simd_distance(smoothed[0], previous[0])
  #expect(smoothedDistance <= rawDistance)
}

@Test func blackWhiteContrastIsMaximum() {
  let ratio = Contrast.contrastRatio(SIMD3(0, 0, 0), SIMD3(1, 1, 1))
  #expect(abs(ratio - 21.0) < 0.01)
}

@Test func midGrayFailsAAAgainstWhite() {
  let gray = ColorSpace.rgb(fromHex: "#777777")
  let ratio = Contrast.contrastRatio(gray, SIMD3(1, 1, 1))
  #expect(abs(ratio - 4.48) < 0.05)
  #expect(!Contrast.passesAA(ratio))
}

@Test func extractionPerformance() async {
  let extractor = PaletteExtractor()
  let pixels = (0..<4096).map { _ in
    SIMD3<Float>(.random(in: 0...1), .random(in: 0...1), .random(in: 0...1))
  }
  let clock = ContinuousClock()
  var total = Duration.zero
  for _ in 0..<50 {
    let start = clock.now
    _ = await extractor.extract(pixels: pixels)
    total += clock.now - start
  }
  // Debug builds disable optimizations and run far slower than a real device, so only
  // enforce the on-device-derived budget in release; debug just guards against a true hang.
  #if DEBUG
    #expect(total < .seconds(15))
  #else
    #expect(total < .milliseconds(1250))
  #endif
}
