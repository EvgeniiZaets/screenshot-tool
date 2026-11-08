// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "Screenshoter",
    platforms: [.macOS(.v14)],
    products: [.executable(name: "Screenshoter", targets: ["Screenshoter"])],
    targets: [
        .target(name: "CaptureCore"),
        .executableTarget(name: "Screenshoter", dependencies: ["CaptureCore"]),
        .testTarget(name: "CaptureCoreTests", dependencies: ["CaptureCore"]),
        .testTarget(name: "ScreenshoterTests", dependencies: ["Screenshoter", "CaptureCore"]),
    ],
    swiftLanguageModes: [.v6]
)
