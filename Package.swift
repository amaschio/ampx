// swift-tools-version: 6.0
import PackageDescription

/// Secondary build-smoke package (no asset catalog / XCTest target).
/// Run the real suite via `./scripts/run-tests.sh` and `Winamp.xcodeproj`.
let package = Package(
    name: "Winamp",
    platforms: [
        // Xcode 26.4 SDK max deployment target is 26.4.99; product floor remains macOS 26.5+.
        .macOS("26.4")
    ],
    products: [
        .executable(name: "Winamp", targets: ["Winamp"])
    ],
    dependencies: [],
    targets: [
        .executableTarget(
            name: "Winamp",
            dependencies: [],
            path: "Sources",
            swiftSettings: [
                .swiftLanguageMode(.v6),
            ]
        )
    ]
)

