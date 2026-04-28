// X25519Tests.swift
// Property and behaviour tests for the X25519 wrapper.
//
// X25519 is well-trodden ground (RFC 7748, deployed everywhere
// from TLS to Signal to SSH); these tests cover the wrapper's
// contract, not the primitive's correctness — Apple's
// CryptoKit Curve25519 implementation has been audited and
// fielded for years.

import CryptoKit
import XCTest
@testable import AegisCrypto

final class X25519Tests: XCTestCase {

    // MARK: - Round trip

    func testSharedSecret_isSymmetric() throws {
        // The X25519 shared secret must be the same when
        // computed by either party — that is the entire point
        // of Diffie-Hellman.
        let alice = X25519.generateKeyPair()
        let bob = X25519.generateKeyPair()

        let aliceComputes = try X25519.sharedSecret(
            privateKey: alice.privateKey,
            peerPublicKey: bob.publicKey
        )
        let bobComputes = try X25519.sharedSecret(
            privateKey: bob.privateKey,
            peerPublicKey: alice.publicKey
        )

        XCTAssertEqual(aliceComputes, bobComputes,
                       "shared secret must agree between Alice and Bob")
    }

    func testSharedSecret_acrossManyKeyPairs() throws {
        for _ in 0..<16 {
            let alice = X25519.generateKeyPair()
            let bob = X25519.generateKeyPair()
            let a = try X25519.sharedSecret(privateKey: alice.privateKey, peerPublicKey: bob.publicKey)
            let b = try X25519.sharedSecret(privateKey: bob.privateKey, peerPublicKey: alice.publicKey)
            XCTAssertEqual(a, b)
        }
    }

    // MARK: - Output shape

    func testKeyPair_isFixedLength() {
        let pair = X25519.generateKeyPair()
        XCTAssertEqual(pair.publicKey.count, 32, "X25519 public key must be 32 bytes")
        XCTAssertEqual(pair.privateKey.count, 32, "X25519 private key must be 32 bytes")
    }

    func testSharedSecret_is32Bytes() throws {
        let a = X25519.generateKeyPair()
        let b = X25519.generateKeyPair()
        let ss = try X25519.sharedSecret(privateKey: a.privateKey, peerPublicKey: b.publicKey)
        XCTAssertEqual(ss.count, 32, "X25519 shared secret must be 32 bytes")
    }

    // MARK: - Generation invariants

    func testKeyPair_eachGenerationIsUnique() {
        let a = X25519.generateKeyPair()
        let b = X25519.generateKeyPair()
        XCTAssertNotEqual(a.publicKey, b.publicKey)
        XCTAssertNotEqual(a.privateKey, b.privateKey)
    }

    // MARK: - Wrong key handling

    func testSharedSecret_wrongLengthPrivateKey_throwsInvalidKey() {
        let bob = X25519.generateKeyPair()
        let bogus = Data(repeating: 0xAB, count: 16)
        XCTAssertThrowsError(
            try X25519.sharedSecret(privateKey: bogus, peerPublicKey: bob.publicKey)
        ) { error in
            guard case AegisError.invalidKey = error else {
                return XCTFail("expected .invalidKey, got \(error)")
            }
        }
    }

    func testSharedSecret_wrongLengthPeerPublicKey_throwsInvalidKey() {
        let alice = X25519.generateKeyPair()
        let bogus = Data(repeating: 0xCD, count: 16)
        XCTAssertThrowsError(
            try X25519.sharedSecret(privateKey: alice.privateKey, peerPublicKey: bogus)
        ) { error in
            guard case AegisError.invalidKey = error else {
                return XCTFail("expected .invalidKey, got \(error)")
            }
        }
    }
}
