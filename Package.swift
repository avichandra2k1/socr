// swift-tools-version:5.9
import PackageDescription

let package = Package(
    name: "socr",
    platforms: [.macOS(.v13)],
    targets: [
        .executableTarget(name: "socr", path: "Sources/socr")
    ]
)
