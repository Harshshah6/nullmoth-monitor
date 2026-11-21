// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "NullMothMonitor",
    platforms: [
        .macOS(.v14)
    ],
    products: [
        .library(name: "NullMothCore", targets: ["NullMothCore"]),
        .executable(name: "nullmoth-mon", targets: ["NullMothMonitorCLI"]),
        .executable(name: "NullMothMonitor", targets: ["NullMothMonitorApp"]),
    ],
    targets: [
        .target(
            name: "NullMothOpenGL"
        ),
        .target(
            name: "NullMothCore",
            dependencies: ["NullMothOpenGL"],
            linkerSettings: [
                .linkedFramework("IOKit"),
                .linkedFramework("CoreGraphics"),
                .linkedFramework("CoreAudio"),
                .linkedFramework("CoreMedia"),
                .linkedFramework("Metal"),
                .linkedFramework("VideoToolbox"),
                .linkedFramework("AppKit"),
            ]
        ),
        .executableTarget(
            name: "NullMothMonitorCLI",
            dependencies: ["NullMothCore"],
            linkerSettings: [
                .linkedFramework("IOKit"),
                .linkedFramework("CoreGraphics"),
                .linkedFramework("CoreAudio"),
                .linkedFramework("Metal"),
            ]
        ),
        .executableTarget(
            name: "NullMothMonitorApp",
            dependencies: ["NullMothCore"],
            linkerSettings: [
                .linkedFramework("IOKit"),
                .linkedFramework("CoreGraphics"),
                .linkedFramework("CoreAudio"),
                .linkedFramework("Metal"),
                .linkedFramework("AppKit"),
                .linkedFramework("SwiftUI"),
            ]
        ),
        .testTarget(
            name: "NullMothCoreTests",
            dependencies: ["NullMothCore"]
        ),
    ]
)
