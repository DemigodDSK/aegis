// MLKEM1024KEMTests.swift
// Property and behaviour tests for MLKEM1024KEM.
//
// These cover the *contract* of the AegisCrypto wrapper. NIST
// FIPS 203 known-answer tests live in MLKEM1024KATTests.swift.

import CryptoKit
import XCTest
@testable import AegisCrypto

final class MLKEM1024KEMTests: XCTestCase {

    private let kem = MLKEM1024KEM()

    // MARK: - Round trip

    func testRoundTrip_encapDecap() throws {
        let pair = try kem.generateKeyPair()
        let encap = try kem.encapsulate(toPublicKey: pair.publicKey)
        let recovered = try kem.decapsulate(encap.ciphertext, with: pair.privateKey)
        XCTAssertEqual(
            encap.sharedSecret.withUnsafeBytes { Data($0) },
            recovered.withUnsafeBytes { Data($0) },
            "encapsulator's shared secret must equal decapsulator's"
        )
    }

    func testRoundTrip_acrossManyKeyPairs() throws {
        for _ in 0..<16 {
            let pair = try kem.generateKeyPair()
            let encap = try kem.encapsulate(toPublicKey: pair.publicKey)
            let recovered = try kem.decapsulate(encap.ciphertext, with: pair.privateKey)
            XCTAssertEqual(
                encap.sharedSecret.withUnsafeBytes { Data($0) },
                recovered.withUnsafeBytes { Data($0) }
            )
        }
    }

    // MARK: - Encapsulation invariants

    func testEncapsulate_alwaysProducesFreshCiphertext() throws {
        let pair = try kem.generateKeyPair()
        let a = try kem.encapsulate(toPublicKey: pair.publicKey)
        let b = try kem.encapsulate(toPublicKey: pair.publicKey)
        XCTAssertNotEqual(a.ciphertext, b.ciphertext,
                          "ML-KEM-1024 encap must be probabilistic")
        XCTAssertNotEqual(
            a.sharedSecret.withUnsafeBytes { Data($0) },
            b.sharedSecret.withUnsafeBytes { Data($0) }
        )
    }

    func testSharedSecret_is256Bits() throws {
        let pair = try kem.generateKeyPair()
        let encap = try kem.encapsulate(toPublicKey: pair.publicKey)
        XCTAssertEqual(encap.sharedSecret.bitCount, 256)
    }

    // MARK: - Key-pair structure invariants

    func testKeyPair_publicAndPrivateAreDifferent() throws {
        let pair = try kem.generateKeyPair()
        XCTAssertFalse(pair.publicKey.isEmpty)
        XCTAssertFalse(pair.privateKey.isEmpty)
        XCTAssertNotEqual(pair.publicKey, pair.privateKey)
    }

    func testKeyPair_eachGenerationIsUnique() throws {
        let a = try kem.generateKeyPair()
        let b = try kem.generateKeyPair()
        XCTAssertNotEqual(a.publicKey, b.publicKey)
        XCTAssertNotEqual(a.privateKey, b.privateKey)
    }

    // MARK: - Wrong key handling

    func testEncapsulate_garbagePublicKey_throwsInvalidKey() throws {
        let bogus = Data(repeating: 0xAB, count: 16)
        XCTAssertThrowsError(
            try kem.encapsulate(toPublicKey: bogus)
        ) { error in
            guard case AegisError.invalidKey = error else {
                return XCTFail("expected .invalidKey, got \(error)")
            }
        }
    }

    func testDecapsulate_garbagePrivateKey_throwsInvalidKey() throws {
        let pair = try kem.generateKeyPair()
        let encap = try kem.encapsulate(toPublicKey: pair.publicKey)
        let bogus = Data(repeating: 0xCD, count: 8)
        XCTAssertThrowsError(
            try kem.decapsulate(encap.ciphertext, with: bogus)
        ) { error in
            guard case AegisError.invalidKey = error else {
                return XCTFail("expected .invalidKey, got \(error)")
            }
        }
    }

    func testDecapsulate_wrongLengthCiphertext_throwsCiphertextCorrupted() throws {
        let pair = try kem.generateKeyPair()
        let bogus = Data(repeating: 0xEF, count: 32)
        XCTAssertThrowsError(
            try kem.decapsulate(bogus, with: pair.privateKey)
        ) { error in
            guard case AegisError.ciphertextCorrupted = error else {
                return XCTFail("expected .ciphertextCorrupted, got \(error)")
            }
        }
    }

    func testDecapsulate_wrongPrivateKey_doesNotMatchSharedSecret() throws {
        // FIPS 203 implicit rejection: decapsulating with a
        // different (valid) private key produces a non-matching
        // shared secret rather than throwing.
        let alice = try kem.generateKeyPair()
        let bob = try kem.generateKeyPair()
        let encap = try kem.encapsulate(toPublicKey: alice.publicKey)
        let aliceRecovered = try kem.decapsulate(encap.ciphertext, with: alice.privateKey)
        let bobAttempt = try kem.decapsulate(encap.ciphertext, with: bob.privateKey)
        XCTAssertEqual(
            encap.sharedSecret.withUnsafeBytes { Data($0) },
            aliceRecovered.withUnsafeBytes { Data($0) }
        )
        XCTAssertNotEqual(
            encap.sharedSecret.withUnsafeBytes { Data($0) },
            bobAttempt.withUnsafeBytes { Data($0) },
            "wrong-key decap must produce a non-matching shared secret"
        )
    }

    // MARK: - Method metadata

    func testMethodMetadata_isTier1() {
        XCTAssertEqual(kem.method.tier, .tier1Approved)
        XCTAssertTrue(kem.method.tier.isApproved)
    }

    func testMethodMetadata_idIsStable() {
        XCTAssertEqual(kem.method.id, "tier1.ml-kem-1024")
    }

    func testMethodMetadata_referencesNistStandard() {
        XCTAssertNotNil(kem.method.standardReference)
        XCTAssertTrue(kem.method.standardReference?.contains("FIPS 203") ?? false)
    }
}
