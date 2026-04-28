// MLDSA65SmokeTests.swift
// Smoke tests for Apple CryptoKit's standalone ML-DSA-65.
//
// Aegis ships its public ML-DSA-65 surface via
// `MLDSA65Signature` — these tests exercise Apple's primitive
// directly via CryptoKit (NOT via AegisCrypto) as a tripwire.
// If a future macOS / Xcode update changes ML-DSA-65 byte sizes
// or seed semantics, these tests fail and the maintainer is
// alerted before the wrapper silently drifts.
//
// What this file is NOT: a NIST FIPS 204 KAT suite. KAT
// vectors live in MLDSA65KATTests.swift.

import CryptoKit
import XCTest
@testable import AegisCrypto

final class MLDSA65SmokeTests: XCTestCase {

    // MARK: - Round trip

    func testRoundTrip_signAndVerify() throws {
        let priv = try CryptoKit.MLDSA65.PrivateKey()
        let message = Data("hello world".utf8)
        let sig = try priv.signature(for: message)
        XCTAssertTrue(priv.publicKey.isValidSignature(sig, for: message))
    }

    // MARK: - Output shape pinning

    func testPublicKey_isFixedLength() throws {
        // ML-DSA-65 public-key length per FIPS 204 is 1952 bytes.
        let priv = try CryptoKit.MLDSA65.PrivateKey()
        XCTAssertEqual(
            priv.publicKey.rawRepresentation.count, 1952,
            "ML-DSA-65 public key must be 1952 bytes (FIPS 204)"
        )
    }

    func testSignature_isFixedLength() throws {
        // ML-DSA-65 signature length per FIPS 204 is 3309 bytes.
        let priv = try CryptoKit.MLDSA65.PrivateKey()
        let sig = try priv.signature(for: Data("x".utf8))
        XCTAssertEqual(
            sig.count, 3309,
            "ML-DSA-65 signature must be 3309 bytes (FIPS 204)"
        )
    }

    func testSeedRepresentation_isFixedLength() throws {
        // ML-DSA-65 seed per FIPS 204 is 32 bytes (xi).
        // CryptoKit's seedRepresentation should match.
        let priv = try CryptoKit.MLDSA65.PrivateKey()
        XCTAssertEqual(
            priv.seedRepresentation.count, 32,
            "ML-DSA-65 seed must be 32 bytes (FIPS 204 xi)"
        )
    }

    // MARK: - Seed determinism

    func testSeedRepresentation_roundTrips() throws {
        // Regenerating from the same seed must yield the same
        // public key. This is the property MLDSA65Signature
        // relies on for its `seedRepresentation`-based
        // serialisation.
        let original = try CryptoKit.MLDSA65.PrivateKey()
        let seed = original.seedRepresentation
        let regenerated = try CryptoKit.MLDSA65.PrivateKey(
            seedRepresentation: seed,
            publicKey: nil
        )
        XCTAssertEqual(
            original.publicKey.rawRepresentation,
            regenerated.publicKey.rawRepresentation,
            "public key must be deterministic in the seed"
        )
    }

    func testSeedRepresentation_signaturesVerifyAfterReload() throws {
        // After regeneration from the seed, signatures produced
        // by the new key must verify under the original public
        // key.
        let original = try CryptoKit.MLDSA65.PrivateKey()
        let regenerated = try CryptoKit.MLDSA65.PrivateKey(
            seedRepresentation: original.seedRepresentation,
            publicKey: nil
        )
        let message = Data("after reload".utf8)
        let sig = try regenerated.signature(for: message)
        XCTAssertTrue(
            original.publicKey.isValidSignature(sig, for: message),
            "regenerated key must produce signatures valid under original pk"
        )
    }
}
