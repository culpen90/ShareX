// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "ShareX",
    platforms: [
        .macOS(.v13)
    ],
    products: [
        .executable(name: "ShareX", targets: ["ShareX"])
    ],
    targets: [
        .executableTarget(
            name: "ShareX",
            path: "ShareX/Platforms/macOS/Sources/ShareX"
        )
    ]
)
