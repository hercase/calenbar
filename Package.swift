// swift-tools-version:6.0
import PackageDescription

let package = Package(
    name: "Calenbar",
    platforms: [.macOS(.v14)],
    dependencies: [
        .package(url: "https://github.com/sparkle-project/Sparkle", exact: "2.10.0")
    ],
    targets: [
        .target(name: "CalenbarCore"),
        .executableTarget(
            name: "Calenbar",
            dependencies: ["CalenbarCore", .product(name: "Sparkle", package: "Sparkle")],
            swiftSettings: [.swiftLanguageMode(.v5)],
            // Sparkle.framework is copied into Contents/Frameworks by scripts/build.sh.
            linkerSettings: [.unsafeFlags(["-Xlinker", "-rpath", "-Xlinker", "@executable_path/../Frameworks"])]
        ),
        .testTarget(name: "CalenbarCoreTests", dependencies: ["CalenbarCore"]),
    ]
)
