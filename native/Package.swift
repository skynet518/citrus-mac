// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "CitrusNative",
    platforms: [.macOS(.v14)],
    products: [.executable(name: "CitrusNative", targets: ["CitrusNative"])],
    dependencies: [.package(url: "https://github.com/ainame/Swift-WebP", exact: "0.5.0")],
    targets: [
        .executableTarget(name: "CitrusNative", dependencies: [.product(name: "WebP", package: "Swift-WebP")], swiftSettings: [.swiftLanguageMode(.v5)])
    ]
)
