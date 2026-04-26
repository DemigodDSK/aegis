// swift-tools-version: 5.9
//
// Aegis — post-quantum messaging, in the open.
//
// This Package describes the Aegis Swift packages. As of v0.0.2,
// only the cryptographic core (AegisCrypto) exists. Subsequent
// sprints will add:
//   - AegisProtocol  (key exchange + message wire format)
//   - AegisStorage   (Keychain + Secure Enclave wrappers)
//   - AegisApp       (the iOS application target)
//
// See docs/STAGES.md (TBD) for the per-version roadmap and
// docs/ARCHITECTURE.md (TBD) for the architectural overview.

import PackageDescription

let package = Package(
    name: "Aegis",
    platforms: [
        // CryptoKit features used by AegisCrypto require iOS 13 / macOS 10.15+.
        // We pin tighter than that to keep options open for future
        // post-quantum primitives shipped in newer CryptoKit releases.
        .iOS(.v16),
        .macOS(.v13),
    ],
    products: [
        .library(
            name: "AegisCrypto",
            targets: ["AegisCrypto"]
        ),
    ],
    dependencies: [
        // No external dependencies in v0.0.2. CryptoKit is a system
        // framework on Apple platforms; we deliberately avoid pulling
        // in third-party crypto until the Security Council can
        // review what we depend on (see GOVERNANCE.md).
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
