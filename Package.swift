// swift-tools-version:5.10
import PackageDescription

let package = Package(
    name: "ScreenGlosser",
    platforms: [.macOS(.v13)],
    targets: [
        .executableTarget(
            name: "ScreenGlosser",
            path: "Sources/ScreenGlosser",
            linkerSettings: [.linkedFramework("Carbon")]
        )
    ]
)
