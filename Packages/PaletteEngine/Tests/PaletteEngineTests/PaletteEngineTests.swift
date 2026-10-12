import Testing
@testable import PaletteEngine

// Smoke test confirming the module builds and its public types are reachable.
@Test func paletteEngineModuleLoads() {
    #expect(ExtractedPalette(colors: []).colors.isEmpty)
}
