// swift-tools-version:5.10
import PackageDescription

let package = Package(
    name: "Kozo",
    platforms: [.macOS(.v13)],
    targets: [
        .executableTarget(
            name: "Kozo",
            path: "Sources/Kozo",
            linkerSettings: [.linkedFramework("Carbon")]
        )
    ]
)
