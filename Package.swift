// swift-tools-version:5.10
import PackageDescription

let package = Package(
    name: "Vigil",
    platforms: [.macOS(.v14)],
    products: [
        .library(name: "VigilKit", targets: ["VigilKit"]),
        .executable(name: "vigil", targets: ["vigil"]),
        .executable(name: "VigilApp", targets: ["VigilApp"])
    ],
    targets: [
        .target(
            name: "VigilKit",
            path: "Sources/VigilKit",
            linkerSettings: [.linkedFramework("IOKit")]
        ),
        .executableTarget(
            name: "vigil",
            dependencies: ["VigilKit"],
            path: "Sources/VigilCLI"
        ),
        .executableTarget(
            name: "VigilApp",
            dependencies: ["VigilKit"],
            path: "Sources/VigilApp"
        ),
        .testTarget(
            name: "VigilTests",
            dependencies: ["VigilKit"],
            path: "Tests/VigilTests"
        )
    ]
)
