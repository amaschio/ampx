// swift-tools-version: 6.0
import PackageDescription

/// Secondary build-smoke package (no asset catalog / XCTest target).
/// Run the real suite via `./scripts/run-tests.sh` and `AmpX.xcodeproj`.
let package = Package(
    name: "AmpX",
    platforms: [
        // Xcode 26.4 SDK max deployment target is 26.4.99; product floor remains macOS 26.5+.
        .macOS("26.4")
    ],
    products: [
        .executable(name: "AmpX", targets: ["AmpX"])
    ],
    dependencies: [],
    targets: [
        .executableTarget(
            name: "AmpX",
            dependencies: [],
            path: "Sources",
            swiftSettings: [
                .swiftLanguageMode(.v6),
            ]
        )
    ]
)
