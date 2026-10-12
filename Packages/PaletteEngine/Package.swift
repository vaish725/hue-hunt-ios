// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "PaletteEngine",
    platforms: [.iOS("26.0")],
    products: [
        .library(name: "PaletteEngine", targets: ["PaletteEngine"])
    ],
    targets: [
        .target(
            name: "PaletteEngine",
            swiftSettings: [.swiftLanguageMode(.v6)]
        ),
        .testTarget(
            name: "PaletteEngineTests",
            dependencies: ["PaletteEngine"],
            swiftSettings: [.swiftLanguageMode(.v6)]
        )
    ]
)
