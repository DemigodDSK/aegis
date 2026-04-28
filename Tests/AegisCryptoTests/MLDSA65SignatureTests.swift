// MLDSA65SignatureTests.swift
// Property and behaviour tests for MLDSA65Signature.
//
// These cover the *contract* of the implementation — what we
// promise callers regardless of the specific algorithm
// internals. NIST FIPS 204 known-answer tests live in
// MLDSA65KATTests.swift (separate file so failures localise).

import CryptoKit
import XCTest
@testable import AegisCrypto

final class MLDSA65SignatureTests: XCTestCase {

    private let signer = MLDSA65Signature()

    // MARK: - Round trip

    func testRoundTrip_signAndVerify() throws {
        let pair = try signer.generateKeyPair()
        let message = Data("hello aegis".utf8)
        let sig = try signer.sign(message, with: pair.privateKey)
        XCTAssertTrue(
            try signer.isValidSignature(sig, of: message, by: pair.publicKey),
            "freshly-signed message must verify against its own public key"
        )
    }

    func testRoundTrip_emptyMessage() throws {
        let pair = try signer.generateKeyPair()
        let sig = try signer.sign(Data(), with: pair.privateKey)
        XCTAssertTrue(
            try signer.isValidSignature(sig, of: Data(), by: pair.publicKey)
        )
    }

    func testRoundTrip_largeMessage() throws {
        let pair = try signer.generateKeyPair()
        var bytes = Data(count: 256 * 1024)
        bytes.withUnsafeMutableBytes { buf in
            _ = SecRandomCopyBytes(kSecRandomDefault, buf.count, buf.baseAddress!)
        }
        let sig = try signer.sign(bytes, with: pair.privateKey)
        XCTAssertTrue(
            try signer.isValidSignature(sig, of: bytes, by: pair.publicKey)
        )
    }

    // MARK: - Hedged-signing invariant

    func testSign_isHedged_yieldsDistinctSignatures() throws {
        // FIPS 204 default signing mode hedges the per-signature
        // randomness; signing the same (key, message) twice must
        // produce different signature bytes (with overwhelming
        // probability), and BOTH signatures must verify.
        let pair = try signer.generateKeyPair()
        let message = Data("identical".utf8)
        let a = try signer.sign(message, with: pair.privateKey)
        let b = try signer.sign(message, with: pair.privateKey)
        XCTAssertNotEqual(a, b, "ML-DSA-65 default signing must be hedged")
        XCTAssertTrue(try signer.isValidSignature(a, of: message, by: pair.publicKey))
        XCTAssertTrue(try signer.isValidSignature(b, of: message, by: pair.publicKey))
    }

    // MARK: - Key-pair structure invariants

    func testKeyPair_eachGenerationIsUnique() throws {
        let a = try signer.generateKeyPair()
        let b = try signer.generateKeyPair()
        XCTAssertNotEqual(a.publicKey, b.publicKey)
        XCTAssertNotEqual(a.privateKey, b.privateKey)
    }

    func testKeyPair_publicAndPrivateAreDifferent() throws {
        let pair = try signer.generateKeyPair()
        XCTAssertFalse(pair.publicKey.isEmpty)
        XCTAssertFalse(pair.privateKey.isEmpty)
        XCTAssertNotEqual(pair.publicKey, pair.privateKey)
    }

    // MARK: - Forgery rejection

    func testVerify_wrongPublicKey_returnsFalse() throws {
        let alice = try signer.generateKeyPair()
        let bob = try signer.generateKeyPair()
        let message = Data("from alice".utf8)
        let sig = try signer.sign(message, with: alice.privateKey)
        XCTAssertFalse(
            try signer.isValidSignature(sig, of: message, by: bob.publicKey),
            "alice's signature must NOT verify under bob's public key"
        )
    }

    func testVerify_tamperedMessage_returnsFalse() throws {
        let pair = try signer.generateKeyPair()
        let message = Data("legitimate".utf8)
        let sig = try signer.sign(message, with: pair.privateKey)
        let tampered = Data("legitimat3".utf8)  // 1-bit change
        XCTAssertFalse(
            try signer.isValidSignature(sig, of: tampered, by: pair.publicKey)
        )
    }

    func testVerify_tamperedSignature_returnsFalse() throws {
        let pair = try signer.generateKeyPair()
        let message = Data("body".utf8)
        var sig = try signer.sign(message, with: pair.privateKey)
        sig[0] ^= 0x01
        XCTAssertFalse(
            try signer.isValidSignature(sig, of: message, by: pair.publicKey)
        )
    }

    // MARK: - Bad input handling

    func testSign_garbagePrivateKey_throwsInvalidKey() throws {
        let bogus = Data(repeating: 0xAB, count: 16)  // far too short
        XCTAssertThrowsError(
            try signer.sign(Data("x".utf8), with: bogus)
        ) { error in
            guard case AegisError.invalidKey = error else {
                return XCTFail("expected .invalidKey, got \(error)")
            }
        }
    }

    func testVerify_garbagePublicKey_throwsInvalidKey() throws {
        let pair = try signer.generateKeyPair()
        let message = Data("x".utf8)
        let sig = try signer.sign(message, with: pair.privateKey)
        let bogus = Data(repeating: 0xCD, count: 16)
        XCTAssertThrowsError(
            try signer.isValidSignature(sig, of: message, by: bogus)
        ) { error in
            guard case AegisError.invalidKey = error else {
                return XCTFail("expected .invalidKey, got \(error)")
            }
        }
    }

    // MARK: - Method metadata

    func testMethodMetadata_isTier1() {
        XCTAssertEqual(signer.method.tier, .tier1Approved)
        XCTAssertTrue(signer.method.tier.isApproved)
    }

    func testMethodMetadata_idIsStable() {
        XCTAssertEqual(signer.method.id, "tier1.ml-dsa-65")
    }

    func testMethodMetadata_referencesNistStandard() {
        XCTAssertNotNil(signer.method.standardReference)
        XCTAssertTrue(signer.method.standardReference?.contains("FIPS 204") ?? false)
    }
}
