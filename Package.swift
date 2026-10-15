// swift-tools-version:6.0
import PackageDescription

let package = Package(
    name: "Calenbar",
    platforms: [.macOS(.v14)],
    targets: [
        .target(name: "CalenbarCore"),
        .executableTarget(
            name: "Calenbar",
            dependencies: ["CalenbarCore"],
            swiftSettings: [.swiftLanguageMode(.v5)]
        ),
        .testTarget(name: "CalenbarCoreTests", dependencies: ["CalenbarCore"]),
    ]
)
