// swift-tools-version:5.9
import PackageDescription

let package = Package(
    name: "Lyrcing",
    platforms: [.macOS(.v14)],
    targets: [
        .executableTarget(name: "Lyrcing", path: "Sources/Lyrcing")
    ]
)
