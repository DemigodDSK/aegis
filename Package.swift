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
// Subsequent sprints will add:
//   - AegisProtocol  (key exchange + message wire format)
//   - AegisStorage   (Keychain + Secure Enclave wrappers)
//   - AegisApp       (the iOS application target)

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
        .testTarget(
            name: "AegisCryptoTests",
            dependencies: ["AegisCrypto"],
            path: "Tests/AegisCryptoTests"
        ),
    ]
)
