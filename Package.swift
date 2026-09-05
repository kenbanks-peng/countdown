// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "Countdown",
    platforms: [.macOS(.v13)],
    products: [
        .executable(name: "countdown", targets: ["Countdown"])
    ],
    targets: [
        .executableTarget(
            name: "Countdown",
            path: "src",
            resources: [.process("Resources")]
        )
    ]
)
