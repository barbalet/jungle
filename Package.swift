// swift-tools-version: 6.2
import PackageDescription

let package = Package(
    name: "jungle",
    platforms: [
        .macOS(.v14),
    ],
    products: [
        .executable(name: "jungle", targets: ["JungleApp"]),
        .library(name: "JungleRenderer", targets: ["JungleRenderer"]),
        .library(name: "JungleShared", targets: ["JungleShared"]),
        .library(name: "JungleCore", targets: ["JungleCore"]),
    ],
    targets: [
        .executableTarget(
            name: "JungleApp",
            dependencies: ["JungleRenderer", "JungleShared", "JungleCore"],
            path: "Sources/App"
        ),
        .target(
            name: "JungleRenderer",
            dependencies: ["JungleShared", "JungleCore"],
            path: "Sources/Renderer",
            linkerSettings: [
                .linkedFramework("Metal"),
                .linkedFramework("MetalKit"),
            ]
        ),
        .target(
            name: "JungleShared",
            path: "Sources/Shared"
        ),
        .target(
            name: "JungleCore",
            path: "Sources/Core",
            publicHeadersPath: "include"
        ),
        .testTarget(
            name: "JungleCoreTests",
            dependencies: ["JungleCore"],
            path: "Tests/CoreTests"
        ),
        .testTarget(
            name: "JungleSharedTests",
            dependencies: ["JungleShared"],
            path: "Tests/SharedTests"
        ),
    ],
    cLanguageStandard: .c17
)
