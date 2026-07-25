// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "oMLXControl",
    platforms: [.macOS(.v14)],
    targets: [
        .executableTarget(
            name: "oMLXControl",
            path: "Sources/oMLXControl"
        )
    ]
)
