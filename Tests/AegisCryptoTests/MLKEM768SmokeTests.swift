// MLKEM768SmokeTests.swift
// Smoke tests for Apple CryptoKit's standalone ML-KEM-768.
//
// Aegis ships *only* the X-Wing hybrid in its public surface
// (HybridKEM); it does not expose standalone ML-KEM-768 to
// callers. This file therefore exercises Apple's primitive
// directly via CryptoKit, NOT via AegisCrypto.
//
// Purpose: a tripwire. If a future macOS / Xcode update changes
// ML-KEM-768 behaviour in a way that would also affect X-Wing
// (which uses ML-KEM-768 internally), these tests will fail and
// the maintainer is alerted before HybridKEM behaviour silently
// drifts.
//
// What this file is NOT: a NIST FIPS 203 KAT suite. Hand-
// transcribing 1184-byte encapsulation keys, 2400-byte decap
// keys and 1088-byte ciphertexts is impractical. NIST KAT
// vectors will be added in a follow-up commit alongside the
// X-Wing KATs, fetched from a vetted source with a checksum-
// pinned fetcher in the same spirit as the existing AES-GCM
// KAT plan (see issue #2).

import CryptoKit
import XCTest
@testable import AegisCrypto

final class MLKEM768SmokeTests: XCTestCase {

    // MARK: - Round trip

    func testRoundTrip_encapDecap() throws {
        let priv = try MLKEM768.PrivateKey()
        let result = try priv.publicKey.encapsulate()
        let recovered = try priv.decapsulate(result.encapsulated)

        XCTAssertEqual(
            result.sharedSecret.withUnsafeBytes { Data($0) },
            recovered.withUnsafeBytes { Data($0) },
            "encapsulator's shared secret must equal decapsulator's"
        )
    }

    func testRoundTrip_acrossManyKeyPairs() throws {
        for _ in 0..<8 {
            let priv = try MLKEM768.PrivateKey()
            let result = try priv.publicKey.encapsulate()
            let recovered = try priv.decapsulate(result.encapsulated)
            XCTAssertEqual(
                result.sharedSecret.withUnsafeBytes { Data($0) },
                recovered.withUnsafeBytes { Data($0) }
            )
        }
    }

    // MARK: - Probabilistic encapsulation

    func testEncapsulate_isProbabilistic() throws {
        // Two encapsulations against the same public key MUST
        // produce different ciphertexts. ML-KEM is a probabilistic
        // KEM — each call samples fresh randomness.
        let priv = try MLKEM768.PrivateKey()
        let a = try priv.publicKey.encapsulate()
        let b = try priv.publicKey.encapsulate()
        XCTAssertNotEqual(a.encapsulated, b.encapsulated)
        XCTAssertNotEqual(
            a.sharedSecret.withUnsafeBytes { Data($0) },
            b.sharedSecret.withUnsafeBytes { Data($0) }
        )
    }

    // MARK: - Seed round-trip

    func testSeedRepresentation_roundTrips() throws {
        // Regenerating a private key from its seed must yield the
        // same public key. This is the property HybridKEM relies
        // on for its `seedRepresentation`-based serialisation.
        let original = try MLKEM768.PrivateKey()
        let seed = original.seedRepresentation
        let regenerated = try MLKEM768.PrivateKey(
            seedRepresentation: seed,
            publicKey: nil
        )
        XCTAssertEqual(
            original.publicKey.rawRepresentation,
            regenerated.publicKey.rawRepresentation,
            "public key must be deterministic in the seed"
        )
    }

    func testSeedRepresentation_decapsulationMatches() throws {
        // After regeneration from the seed, decapsulation of a
        // ciphertext encapsulated against the original public key
        // must still recover the same shared secret.
        let original = try MLKEM768.PrivateKey()
        let result = try original.publicKey.encapsulate()
        let regenerated = try MLKEM768.PrivateKey(
            seedRepresentation: original.seedRepresentation,
            publicKey: nil
        )
        let recovered = try regenerated.decapsulate(result.encapsulated)
        XCTAssertEqual(
            result.sharedSecret.withUnsafeBytes { Data($0) },
            recovered.withUnsafeBytes { Data($0) }
        )
    }

    // MARK: - Output shape sanity

    func testSharedSecret_is256Bits() throws {
        let priv = try MLKEM768.PrivateKey()
        let result = try priv.publicKey.encapsulate()
        XCTAssertEqual(result.sharedSecret.bitCount, 256,
                       "ML-KEM-768 shared secret must be 256 bits")
    }

    func testCiphertext_isFixedLength() throws {
        // ML-KEM-768 ciphertext length per FIPS 203 is 1088 bytes.
        // If Apple's implementation deviates, X-Wing ciphertext
        // length will drift accordingly.
        let priv = try MLKEM768.PrivateKey()
        let result = try priv.publicKey.encapsulate()
        XCTAssertEqual(result.encapsulated.count, 1088,
                       "ML-KEM-768 ciphertext must be 1088 bytes (FIPS 203)")
    }

    func testPublicKey_isFixedLength() throws {
        // ML-KEM-768 encapsulation key length per FIPS 203 is
        // 1184 bytes. Same drift-detection rationale as above.
        let priv = try MLKEM768.PrivateKey()
        XCTAssertEqual(priv.publicKey.rawRepresentation.count, 1184,
                       "ML-KEM-768 encapsulation key must be 1184 bytes (FIPS 203)")
    }

    func testSeedRepresentation_isFixedLength() throws {
        // ML-KEM-768 seed per FIPS 203 is 64 bytes (d || z, each 32).
        // CryptoKit returns this format directly.
        let priv = try MLKEM768.PrivateKey()
        XCTAssertEqual(priv.seedRepresentation.count, 64,
                       "ML-KEM-768 seed must be 64 bytes (FIPS 203 d||z)")
    }
}
