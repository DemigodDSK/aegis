// IdentityTests.swift
// Property and behaviour tests for IdentityKeyPair / IdentityPublicKey.

import CryptoKit
import XCTest
@testable import AegisCrypto

final class IdentityTests: XCTestCase {

    // MARK: - Generation

    func testGenerate_producesBothComponents() throws {
        let id = try IdentityKeyPair.generate()
        XCTAssertFalse(id.signing.publicKey.isEmpty)
        XCTAssertFalse(id.signing.privateKey.isEmpty)
        XCTAssertFalse(id.dh.publicKey.isEmpty)
        XCTAssertFalse(id.dh.privateKey.isEmpty)
    }

    func testGenerate_producesFreshIdentities() throws {
        let a = try IdentityKeyPair.generate()
        let b = try IdentityKeyPair.generate()
        XCTAssertNotEqual(a.publicKey, b.publicKey)
        XCTAssertNotEqual(a.signing.privateKey, b.signing.privateKey)
        XCTAssertNotEqual(a.dh.privateKey, b.dh.privateKey)
    }

    // MARK: - Public-key extraction

    func testPublicKey_signing_matchesUnderlyingKeyPair() throws {
        let id = try IdentityKeyPair.generate()
        XCTAssertEqual(id.publicKey.signing, id.signing.publicKey)
    }

    func testPublicKey_dh_matchesUnderlyingKeyPair() throws {
        let id = try IdentityKeyPair.generate()
        XCTAssertEqual(id.publicKey.dh, id.dh.publicKey)
    }

    // MARK: - Component sizes

    func testPublicKey_signing_isMLDSA65Size() throws {
        let id = try IdentityKeyPair.generate()
        XCTAssertEqual(
            id.publicKey.signing.count, 1952,
            "signing public key must be ML-DSA-65 size (FIPS 204)"
        )
    }

    func testPublicKey_dh_isX25519Size() throws {
        let id = try IdentityKeyPair.generate()
        XCTAssertEqual(
            id.publicKey.dh.count, 32,
            "dh public key must be X25519 size"
        )
    }

    // MARK: - End-to-end usage

    func testIdentity_canSignAndVerify() throws {
        let alice = try IdentityKeyPair.generate()
        let signer = MLDSA65Signature()
        let message = Data("hello from alice".utf8)
        let sig = try signer.sign(message, with: alice.signing.privateKey)
        XCTAssertTrue(
            try signer.isValidSignature(sig, of: message, by: alice.publicKey.signing),
            "Alice's identity must be able to produce a verifiable signature"
        )
    }

    func testIdentity_canPerformDH() throws {
        let alice = try IdentityKeyPair.generate()
        let bob = try IdentityKeyPair.generate()

        let aliceComputes = try X25519.sharedSecret(
            privateKey: alice.dh.privateKey,
            peerPublicKey: bob.publicKey.dh
        )
        let bobComputes = try X25519.sharedSecret(
            privateKey: bob.dh.privateKey,
            peerPublicKey: alice.publicKey.dh
        )
        XCTAssertEqual(aliceComputes, bobComputes,
                       "Alice and Bob's identities must agree on DH(IK_A, IK_B)")
    }

    // MARK: - Codable round-trip

    func testPublicKey_jsonRoundTrip() throws {
        let id = try IdentityKeyPair.generate()
        let original = id.publicKey

        let encoded = try JSONEncoder().encode(original)
        let decoded = try JSONDecoder().decode(IdentityPublicKey.self, from: encoded)

        XCTAssertEqual(original, decoded,
                       "IdentityPublicKey must round-trip through JSON without loss")
        XCTAssertEqual(decoded.signing, id.signing.publicKey)
        XCTAssertEqual(decoded.dh, id.dh.publicKey)
    }

    func testPublicKey_jsonShape_hasBothFields() throws {
        let id = try IdentityKeyPair.generate()
        let encoded = try JSONEncoder().encode(id.publicKey)
        let json = String(data: encoded, encoding: .utf8) ?? ""
        XCTAssertTrue(json.contains("\"signing\""), "JSON must contain a 'signing' field")
        XCTAssertTrue(json.contains("\"dh\""), "JSON must contain a 'dh' field")
    }
}
