// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "ShareXMac",
    platforms: [
        .macOS(.v13)
    ],
    products: [
        .executable(name: "ShareXMac", targets: ["ShareXMac"])
    ],
    targets: [
        .executableTarget(
            name: "ShareXMac",
            path: "Sources/ShareXMac"
        )
    ]
)
