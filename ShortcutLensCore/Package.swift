// swift-tools-version: 6.0
import PackageDescription

/// Core logic for ShortcutLens. This package must not declare dependencies:
/// the app ships without third-party code (see scripts/check-no-telemetry.sh).
let package = Package(
    name: "ShortcutLensCore",
    platforms: [.macOS(.v14)],
    products: [
        .library(name: "ShortcutLensCore", targets: ["ShortcutLensCore"]),
    ],
    targets: [
        .target(name: "ShortcutLensCore"),
        .testTarget(name: "ShortcutLensCoreTests", dependencies: ["ShortcutLensCore"]),
    ]
)
