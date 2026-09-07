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
            resources: [.process("Core/Resources")]
        ),
        .testTarget(
            name: "CountdownTests",
            dependencies: ["Countdown"],
            path: "Tests",
            exclude: ["CircleTransitionCheck.swift"]
        )
    ]
)
