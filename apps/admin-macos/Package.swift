// swift-tools-version:5.9
import PackageDescription

let package = Package(
    name: "LineOAAdmin",
    platforms: [.macOS(.v13)],
    targets: [
        .executableTarget(
            name: "AdminMacOS",
            path: "Sources/AdminMacOS"
        )
    ]
)
