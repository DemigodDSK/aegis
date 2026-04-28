// PrekeyBundleTests.swift
// Property and behaviour tests for PrekeyBundle generation,
// signature-chain verification, and JSON wire-format
// round-trips.

import CryptoKit
import XCTest
@testable import AegisCrypto

final class PrekeyBundleTests: XCTestCase {

    // MARK: - Generation

    func testGenerate_producesAllPrekeys() throws {
        let identity = try IdentityKeyPair.generate()
        let (bundle, secrets) = try PrekeyBundle.generate(
            identity: identity,
            oneTimePrekeyCount: 5
        )

        XCTAssertEqual(bundle.identity, identity.publicKey)
        XCTAssertEqual(bundle.oneTimePrekeys.count, 5)
        XCTAssertEqual(secrets.oneTimePrekeys.count, 5)
        XCTAssertFalse(bundle.signedPrekey.publicKey.isEmpty)
        XCTAssertFalse(bundle.signedPQKEMPrekey.publicKey.isEmpty)
        XCTAssertFalse(bundle.signedPrekey.signature.isEmpty)
        XCTAssertFalse(bundle.signedPQKEMPrekey.signature.isEmpty)
    }

    func testGenerate_publicAndSecretKeyIdsLineUp() throws {
        let identity = try IdentityKeyPair.generate()
        let (bundle, secrets) = try PrekeyBundle.generate(
            identity: identity,
            oneTimePrekeyCount: 4
        )
        XCTAssertEqual(bundle.signedPrekey.keyId, secrets.signedPrekey.keyId)
        XCTAssertEqual(bundle.signedPQKEMPrekey.keyId, secrets.signedPQKEMPrekey.keyId)
        let publicIds = bundle.oneTimePrekeys.map(\.keyId)
        let secretIds = secrets.oneTimePrekeys.map(\.keyId)
        XCTAssertEqual(publicIds, secretIds)
    }

    func testGenerate_withZeroOneTimePrekeys_succeeds() throws {
        // Bob may publish a bundle without OPKs in low-volume
        // scenarios. The protocol must accept it.
        let identity = try IdentityKeyPair.generate()
        let (bundle, secrets) = try PrekeyBundle.generate(
            identity: identity,
            oneTimePrekeyCount: 0
        )
        XCTAssertTrue(bundle.oneTimePrekeys.isEmpty)
        XCTAssertTrue(secrets.oneTimePrekeys.isEmpty)
    }

    func testGenerate_keyIdsAreNonzero() throws {
        let identity = try IdentityKeyPair.generate()
        let (bundle, _) = try PrekeyBundle.generate(
            identity: identity,
            oneTimePrekeyCount: 8
        )
        XCTAssertNotEqual(bundle.signedPrekey.keyId, 0)
        XCTAssertNotEqual(bundle.signedPQKEMPrekey.keyId, 0)
        for opk in bundle.oneTimePrekeys {
            XCTAssertNotEqual(opk.keyId, 0)
        }
    }

    func testGenerate_setsSizesCorrectly() throws {
        let identity = try IdentityKeyPair.generate()
        let (bundle, _) = try PrekeyBundle.generate(
            identity: identity,
            oneTimePrekeyCount: 3
        )
        XCTAssertEqual(bundle.signedPrekey.publicKey.count, 32,
                       "SPK is X25519 (32 bytes)")
        XCTAssertEqual(bundle.signedPQKEMPrekey.publicKey.count, 1568,
                       "PQPK is ML-KEM-1024 (1568 bytes)")
        for opk in bundle.oneTimePrekeys {
            XCTAssertEqual(opk.publicKey.count, 32,
                           "OPKs are X25519 (32 bytes)")
        }
    }

    // MARK: - Signature verification (positive)

    func testVerify_freshlyGeneratedBundle_succeeds() throws {
        let identity = try IdentityKeyPair.generate()
        let (bundle, _) = try PrekeyBundle.generate(
            identity: identity,
            oneTimePrekeyCount: 4
        )
        XCTAssertTrue(try bundle.verify(),
                      "freshly-generated bundle must verify against its identity")
    }

    func testVerify_zeroOneTimePrekeys_succeeds() throws {
        let identity = try IdentityKeyPair.generate()
        let (bundle, _) = try PrekeyBundle.generate(
            identity: identity,
            oneTimePrekeyCount: 0
        )
        XCTAssertTrue(try bundle.verify())
    }

    // MARK: - Signature verification (rejection)

    func testVerify_swappedIdentity_fails() throws {
        // Bundle was signed by Alice's identity; we substitute
        // Bob's identity in the bundle. The signatures must no
        // longer verify.
        let alice = try IdentityKeyPair.generate()
        let bob = try IdentityKeyPair.generate()
        let (aliceBundle, _) = try PrekeyBundle.generate(
            identity: alice,
            oneTimePrekeyCount: 2
        )
        let tampered = PrekeyBundle(
            identity: bob.publicKey,  // wrong identity
            signedPrekey: aliceBundle.signedPrekey,
            signedPQKEMPrekey: aliceBundle.signedPQKEMPrekey,
            oneTimePrekeys: aliceBundle.oneTimePrekeys,
            bundleId: aliceBundle.bundleId,
            createdAt: aliceBundle.createdAt,
            signedPrekeyEpoch: aliceBundle.signedPrekeyEpoch
        )
        XCTAssertFalse(try tampered.verify(),
                       "swapped identity must invalidate signatures")
    }

    func testVerify_tamperedSignedPrekey_fails() throws {
        let identity = try IdentityKeyPair.generate()
        let (bundle, _) = try PrekeyBundle.generate(
            identity: identity,
            oneTimePrekeyCount: 1
        )
        var spkBytes = bundle.signedPrekey.publicKey
        spkBytes[0] ^= 0x01
        let tamperedSpk = SignedPrekey(
            keyId: bundle.signedPrekey.keyId,
            publicKey: spkBytes,
            signature: bundle.signedPrekey.signature,
            createdAt: bundle.signedPrekey.createdAt
        )
        let tampered = PrekeyBundle(
            identity: bundle.identity,
            signedPrekey: tamperedSpk,
            signedPQKEMPrekey: bundle.signedPQKEMPrekey,
            oneTimePrekeys: bundle.oneTimePrekeys,
            bundleId: bundle.bundleId,
            createdAt: bundle.createdAt,
            signedPrekeyEpoch: bundle.signedPrekeyEpoch
        )
        XCTAssertFalse(try tampered.verify(),
                       "tampered SPK bytes must invalidate the signature")
    }

    func testVerify_tamperedPQPrekey_fails() throws {
        let identity = try IdentityKeyPair.generate()
        let (bundle, _) = try PrekeyBundle.generate(
            identity: identity,
            oneTimePrekeyCount: 1
        )
        var pqBytes = bundle.signedPQKEMPrekey.publicKey
        pqBytes[0] ^= 0x01
        let tamperedPq = SignedPQKEMPrekey(
            keyId: bundle.signedPQKEMPrekey.keyId,
            publicKey: pqBytes,
            signature: bundle.signedPQKEMPrekey.signature,
            createdAt: bundle.signedPQKEMPrekey.createdAt
        )
        let tampered = PrekeyBundle(
            identity: bundle.identity,
            signedPrekey: bundle.signedPrekey,
            signedPQKEMPrekey: tamperedPq,
            oneTimePrekeys: bundle.oneTimePrekeys,
            bundleId: bundle.bundleId,
            createdAt: bundle.createdAt,
            signedPrekeyEpoch: bundle.signedPrekeyEpoch
        )
        XCTAssertFalse(try tampered.verify())
    }

    func testVerify_tamperedOneTimePrekey_fails() throws {
        let identity = try IdentityKeyPair.generate()
        let (bundle, _) = try PrekeyBundle.generate(
            identity: identity,
            oneTimePrekeyCount: 3
        )
        var opks = bundle.oneTimePrekeys
        var bytes = opks[1].publicKey
        bytes[0] ^= 0x01
        opks[1] = OneTimePrekey(
            keyId: opks[1].keyId,
            publicKey: bytes,
            signature: opks[1].signature
        )
        let tampered = PrekeyBundle(
            identity: bundle.identity,
            signedPrekey: bundle.signedPrekey,
            signedPQKEMPrekey: bundle.signedPQKEMPrekey,
            oneTimePrekeys: opks,
            bundleId: bundle.bundleId,
            createdAt: bundle.createdAt,
            signedPrekeyEpoch: bundle.signedPrekeyEpoch
        )
        XCTAssertFalse(try tampered.verify())
    }

    func testVerify_replayedSignatureAcrossRoles_fails() throws {
        // Domain separation guard: a signature legitimately
        // produced for an SPK must not verify when reused as
        // an OPK signature, even if the (keyId, publicKey)
        // happen to match.
        let identity = try IdentityKeyPair.generate()
        let (bundle, _) = try PrekeyBundle.generate(
            identity: identity,
            oneTimePrekeyCount: 1
        )
        // Build a tampered bundle where the OPK uses the
        // SPK's signature.
        let opk = bundle.oneTimePrekeys[0]
        let badOpk = OneTimePrekey(
            keyId: opk.keyId,
            publicKey: opk.publicKey,
            signature: bundle.signedPrekey.signature  // wrong-role signature
        )
        let tampered = PrekeyBundle(
            identity: bundle.identity,
            signedPrekey: bundle.signedPrekey,
            signedPQKEMPrekey: bundle.signedPQKEMPrekey,
            oneTimePrekeys: [badOpk],
            bundleId: bundle.bundleId,
            createdAt: bundle.createdAt,
            signedPrekeyEpoch: bundle.signedPrekeyEpoch
        )
        XCTAssertFalse(try tampered.verify(),
                       "cross-role signature replay must be rejected")
    }

    // MARK: - Wire format (JSON round-trip)

    func testJSON_roundTripsExactly() throws {
        let identity = try IdentityKeyPair.generate()
        let (bundle, _) = try PrekeyBundle.generate(
            identity: identity,
            oneTimePrekeyCount: 3
        )
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601

        let encoded = try encoder.encode(bundle)
        let decoded = try decoder.decode(PrekeyBundle.self, from: encoded)

        XCTAssertEqual(decoded, bundle, "bundle must round-trip JSON without loss")
        XCTAssertTrue(try decoded.verify(),
                      "decoded bundle must still verify after JSON round-trip")
    }

    func testJSON_contains_expectedTopLevelFields() throws {
        let identity = try IdentityKeyPair.generate()
        let (bundle, _) = try PrekeyBundle.generate(
            identity: identity,
            oneTimePrekeyCount: 1
        )
        let encoded = try JSONEncoder().encode(bundle)
        let json = String(data: encoded, encoding: .utf8) ?? ""
        for field in ["identity", "signedPrekey", "signedPQKEMPrekey",
                      "oneTimePrekeys", "bundleId", "createdAt",
                      "signedPrekeyEpoch"] {
            XCTAssertTrue(json.contains("\"\(field)\""),
                          "JSON must contain a '\(field)' field; saw: \(json.prefix(200))")
        }
    }

    // MARK: - Domain-separator format pinning

    func testSignedBytes_layoutIsContext_keyIdBE_pubkey() {
        // Pin the byte layout so a future change is loud.
        // Layout: context bytes || uint32 big-endian || pubkey.
        let context = Data([0xAA, 0xBB, 0xCC])
        let keyId: UInt32 = 0x01020304
        let pubkey = Data([0x10, 0x20])
        let bytes = PrekeyBundle.signedBytes(
            context: context,
            keyId: keyId,
            publicKey: pubkey
        )
        XCTAssertEqual(
            Array(bytes),
            [0xAA, 0xBB, 0xCC, 0x01, 0x02, 0x03, 0x04, 0x10, 0x20]
        )
    }
}
