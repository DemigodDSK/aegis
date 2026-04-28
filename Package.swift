// swift-tools-version: 6.2
//
// Aegis — post-quantum messaging, in the open.
//
// As of v0.0.3 (Sprint 2), AegisCrypto consumes Apple's native
// post-quantum CryptoKit primitives — MLKEM768, MLDSA65,
// XWingMLKEM768X25519, and SecureEnclave.MLKEM768. These APIs are
// gated `@available(iOS 26.0, macOS 26.0, ...)` so the package's
// platform minimums are pinned to match. This decision is documented
// as a conscious deviation in docs/STAGES.md v0.0.3.
//
// Layering as of Sprint 6 (v0.0.7):
//   AegisCrypto    — pure crypto primitives + protocols
//                    (AEAD, KEM, signatures, identity, PQXDH,
//                    Double Ratchet)
//   AegisStorage   — Keychain + (future) Secure Enclave wrappers,
//                    depends on AegisCrypto for the Codable types
//                    it persists
//   AegisApp       — SwiftUI views, depends on AegisStorage
//   aegis-demo     — macOS executable that hosts AegisApp so the
//                    app is visible today; iOS Xcode-project
//                    distribution is Sprint 7 territory

import PackageDescription

let package = Package(
    name: "Aegis",
    platforms: [
        .iOS(.v26),
        .macOS(.v26),
    ],
    products: [
        .library(
            name: "AegisCrypto",
            targets: ["AegisCrypto"]
        ),
        .library(
            name: "AegisStorage",
            targets: ["AegisStorage"]
        ),
        .library(
            name: "AegisApp",
            targets: ["AegisApp"]
        ),
    ],
    dependencies: [
        // No external dependencies. CryptoKit (including its native
        // post-quantum primitives) is a system framework on Apple
        // platforms; we deliberately avoid pulling in third-party
        // crypto until the Security Council can review what we
        // depend on (see GOVERNANCE.md).
    ],
    targets: [
        .target(
            name: "AegisCrypto",
            dependencies: [],
            path: "Sources/AegisCrypto"
        ),
        .target(
            name: "AegisStorage",
            dependencies: ["AegisCrypto"],
            path: "Sources/AegisStorage"
        ),
        .target(
            name: "AegisApp",
            dependencies: ["AegisCrypto", "AegisStorage"],
            path: "Sources/AegisApp"
        ),
        .executableTarget(
            name: "aegis-demo",
            dependencies: ["AegisApp"],
            path: "Sources/aegis-demo"
        ),
        .testTarget(
            name: "AegisCryptoTests",
            dependencies: ["AegisCrypto"],
            path: "Tests/AegisCryptoTests",
            resources: [
                // Shipped as test-bundle resources so KAT files are
                // available via `Bundle.module` regardless of the
                // working directory `swift test` is invoked from.
                .copy("Vectors")
            ]
        ),
        .testTarget(
            name: "AegisStorageTests",
            dependencies: ["AegisStorage"],
            path: "Tests/AegisStorageTests"
        ),
        .testTarget(
            name: "AegisAppTests",
            dependencies: ["AegisApp"],
            path: "Tests/AegisAppTests"
        ),
    ]
)
