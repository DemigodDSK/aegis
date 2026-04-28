// MLKEM1024SmokeTests.swift
// Smoke tests for Apple CryptoKit's standalone ML-KEM-1024.
//
// These exercise Apple's primitive directly via CryptoKit (NOT
// via AegisCrypto) as a tripwire. If a future macOS / Xcode
// update changes ML-KEM-1024 byte sizes or seed semantics,
// these tests fail and the maintainer is alerted before
// MLKEM1024KEM silently drifts.
//
// Algorithm-correctness against NIST FIPS 203 KAT vectors
// lives in MLKEM1024KATTests.swift.

import CryptoKit
import XCTest
@testable import AegisCrypto

final class MLKEM1024SmokeTests: XCTestCase {

    // MARK: - Round trip

    func testRoundTrip_encapDecap() throws {
        let priv = try CryptoKit.MLKEM1024.PrivateKey()
        let result = try priv.publicKey.encapsulate()
        let recovered = try priv.decapsulate(result.encapsulated)
        XCTAssertEqual(
            result.sharedSecret.withUnsafeBytes { Data($0) },
            recovered.withUnsafeBytes { Data($0) }
        )
    }

    func testRoundTrip_acrossManyKeyPairs() throws {
        for _ in 0..<8 {
            let priv = try CryptoKit.MLKEM1024.PrivateKey()
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
        let priv = try CryptoKit.MLKEM1024.PrivateKey()
        let a = try priv.publicKey.encapsulate()
        let b = try priv.publicKey.encapsulate()
        XCTAssertNotEqual(a.encapsulated, b.encapsulated)
        XCTAssertNotEqual(
            a.sharedSecret.withUnsafeBytes { Data($0) },
            b.sharedSecret.withUnsafeBytes { Data($0) }
        )
    }

    // MARK: - Seed determinism

    func testSeedRepresentation_roundTrips() throws {
        let original = try CryptoKit.MLKEM1024.PrivateKey()
        let seed = original.seedRepresentation
        let regenerated = try CryptoKit.MLKEM1024.PrivateKey(
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
        let original = try CryptoKit.MLKEM1024.PrivateKey()
        let result = try original.publicKey.encapsulate()
        let regenerated = try CryptoKit.MLKEM1024.PrivateKey(
            seedRepresentation: original.seedRepresentation,
            publicKey: nil
        )
        let recovered = try regenerated.decapsulate(result.encapsulated)
        XCTAssertEqual(
            result.sharedSecret.withUnsafeBytes { Data($0) },
            recovered.withUnsafeBytes { Data($0) }
        )
    }

    // MARK: - Output shape pinning

    func testSharedSecret_is256Bits() throws {
        let priv = try CryptoKit.MLKEM1024.PrivateKey()
        let result = try priv.publicKey.encapsulate()
        XCTAssertEqual(
            result.sharedSecret.bitCount, 256,
            "ML-KEM-1024 shared secret must be 256 bits"
        )
    }

    func testCiphertext_isFixedLength() throws {
        // ML-KEM-1024 ciphertext per FIPS 203 is 1568 bytes.
        let priv = try CryptoKit.MLKEM1024.PrivateKey()
        let result = try priv.publicKey.encapsulate()
        XCTAssertEqual(
            result.encapsulated.count, 1568,
            "ML-KEM-1024 ciphertext must be 1568 bytes (FIPS 203)"
        )
    }

    func testPublicKey_isFixedLength() throws {
        // ML-KEM-1024 encapsulation key per FIPS 203 is 1568 bytes.
        let priv = try CryptoKit.MLKEM1024.PrivateKey()
        XCTAssertEqual(
            priv.publicKey.rawRepresentation.count, 1568,
            "ML-KEM-1024 encapsulation key must be 1568 bytes (FIPS 203)"
        )
    }

    func testSeedRepresentation_isFixedLength() throws {
        // ML-KEM-1024 seed per FIPS 203 is 64 bytes (d || z, each 32).
        let priv = try CryptoKit.MLKEM1024.PrivateKey()
        XCTAssertEqual(
            priv.seedRepresentation.count, 64,
            "ML-KEM-1024 seed must be 64 bytes (FIPS 203 d||z)"
        )
    }
}
