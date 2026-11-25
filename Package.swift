// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "HyperMac",
    platforms: [.macOS(.v14)],
    targets: [
        .executableTarget(
            name: "HyperMac",
            path: "Sources",
            linkerSettings: [
                .linkedFramework("IOKit"),
            ]
        )
    ]
)
