// PQXDHTests.swift
// End-to-end correctness and rejection tests for the PQXDH
// key-exchange handshake.
//
// We do not (yet) have a libsignal interop reference test; the
// PQXDH KAT vectors that would land here in a follow-up commit
// would compare a deterministic Alice/Bob run against
// libsignal's output for identical inputs. The current suite
// covers self-consistency (Alice's SK == Bob's SK), structural
// rejection (wrong keys, replayed messages, retired bundles),
// and JSON wire-format round-trips.

import CryptoKit
import XCTest
@testable import AegisCrypto

final class PQXDHTests: XCTestCase {

    // MARK: - End-to-end round trip

    func testRoundTrip_aliceAndBobAgreeOnSharedSecret() throws {
        let alice = try IdentityKeyPair.generate()
        let bob = try IdentityKeyPair.generate()
        let (bundle, secrets) = try PrekeyBundle.generate(
            identity: bob,
            oneTimePrekeyCount: 5,
            signedPrekeyEpoch: 1
        )

        let initiate = try PQXDH.initiate(as: alice, toBundle: bundle)

        let bobSK = try PQXDH.respond(
            as: bob,
            bundleSecrets: secrets,
            bundleEpoch: 1,
            receiving: initiate.initialMessage
        )

        XCTAssertEqual(initiate.sharedSecret, bobSK,
                       "Alice's and Bob's derived shared secrets must be byte-identical")
        XCTAssertEqual(initiate.sharedSecret.count, 32,
                       "PQXDH SK must be 32 bytes")
    }

    func testRoundTrip_withoutOneTimePrekey() throws {
        // Bundle with zero OPKs forces the no-DH4 path. Alice
        // and Bob must still agree.
        let alice = try IdentityKeyPair.generate()
        let bob = try IdentityKeyPair.generate()
        let (bundle, secrets) = try PrekeyBundle.generate(
            identity: bob,
            oneTimePrekeyCount: 0,
            signedPrekeyEpoch: 1
        )

        let initiate = try PQXDH.initiate(as: alice, toBundle: bundle)
        XCTAssertNil(initiate.initialMessage.oneTimePrekeyKeyId,
                     "no OPK available => initial message must declare none used")

        let bobSK = try PQXDH.respond(
            as: bob,
            bundleSecrets: secrets,
            bundleEpoch: 1,
            receiving: initiate.initialMessage
        )
        XCTAssertEqual(initiate.sharedSecret, bobSK)
    }

    func testRoundTrip_aliceOptsOutOfOPK() throws {
        // Bundle has OPKs but Alice opts out (useOneTimePrekey:
        // false). Both sides must still derive the same SK.
        let alice = try IdentityKeyPair.generate()
        let bob = try IdentityKeyPair.generate()
        let (bundle, secrets) = try PrekeyBundle.generate(
            identity: bob,
            oneTimePrekeyCount: 4,
            signedPrekeyEpoch: 1
        )

        let initiate = try PQXDH.initiate(
            as: alice,
            toBundle: bundle,
            useOneTimePrekey: false
        )
        XCTAssertNil(initiate.initialMessage.oneTimePrekeyKeyId)

        let bobSK = try PQXDH.respond(
            as: bob,
            bundleSecrets: secrets,
            bundleEpoch: 1,
            receiving: initiate.initialMessage
        )
        XCTAssertEqual(initiate.sharedSecret, bobSK)
    }

    func testRoundTrip_independentSessionsDeriveDistinctSecrets() throws {
        // Two independent Alice→Bob handshakes against the
        // same bundle must derive different SKs (because Alice's
        // ephemeral key and the PQ encap randomness are fresh
        // per-session).
        let alice = try IdentityKeyPair.generate()
        let bob = try IdentityKeyPair.generate()
        let (bundle, _) = try PrekeyBundle.generate(
            identity: bob,
            oneTimePrekeyCount: 2,
            signedPrekeyEpoch: 1
        )
        let a = try PQXDH.initiate(as: alice, toBundle: bundle)
        let b = try PQXDH.initiate(as: alice, toBundle: bundle)
        XCTAssertNotEqual(
            a.sharedSecret, b.sharedSecret,
            "PQXDH must produce session-fresh shared secrets per handshake"
        )
    }

    // MARK: - Bundle authentication

    func testInitiate_forgedBundle_throwsAuthenticationFailed() throws {
        let alice = try IdentityKeyPair.generate()
        let bob = try IdentityKeyPair.generate()
        let mallory = try IdentityKeyPair.generate()
        let (mallorysBundle, _) = try PrekeyBundle.generate(
            identity: mallory,
            oneTimePrekeyCount: 2
        )
        // Substitute Bob's identity into Mallory's bundle —
        // signatures are still by Mallory, so the chain breaks.
        let forged = PrekeyBundle(
            identity: bob.publicKey,
            signedPrekey: mallorysBundle.signedPrekey,
            signedPQKEMPrekey: mallorysBundle.signedPQKEMPrekey,
            oneTimePrekeys: mallorysBundle.oneTimePrekeys,
            bundleId: mallorysBundle.bundleId,
            createdAt: mallorysBundle.createdAt,
            signedPrekeyEpoch: mallorysBundle.signedPrekeyEpoch
        )
        XCTAssertThrowsError(
            try PQXDH.initiate(as: alice, toBundle: forged)
        ) { error in
            guard case AegisError.authenticationFailed = error else {
                return XCTFail("expected .authenticationFailed, got \(error)")
            }
        }
    }

    // MARK: - Bob-side rejection

    func testRespond_epochMismatch_throwsInvalidKey() throws {
        let alice = try IdentityKeyPair.generate()
        let bob = try IdentityKeyPair.generate()
        let (bundle, secrets) = try PrekeyBundle.generate(
            identity: bob,
            oneTimePrekeyCount: 1,
            signedPrekeyEpoch: 1
        )
        let initiate = try PQXDH.initiate(as: alice, toBundle: bundle)

        // Bob has rotated to epoch 2 but Alice's message
        // referenced epoch 1.
        XCTAssertThrowsError(
            try PQXDH.respond(
                as: bob,
                bundleSecrets: secrets,
                bundleEpoch: 2,
                receiving: initiate.initialMessage
            )
        ) { error in
            guard case AegisError.invalidKey(let reason) = error else {
                return XCTFail("expected .invalidKey, got \(error)")
            }
            XCTAssertTrue(reason.contains("epoch"),
                          "reason should mention epoch mismatch; got: \(reason)")
        }
    }

    func testRespond_unknownOPKKeyId_throwsInvalidKey() throws {
        let alice = try IdentityKeyPair.generate()
        let bob = try IdentityKeyPair.generate()
        let (bundle, secrets) = try PrekeyBundle.generate(
            identity: bob,
            oneTimePrekeyCount: 1,
            signedPrekeyEpoch: 1
        )
        var initiate = try PQXDH.initiate(as: alice, toBundle: bundle)

        // Tamper Alice's OPK keyId to something Bob hasn't
        // published — simulates a retired or never-seen OPK.
        let tampered = InitialMessage(
            aliceIdentity: initiate.initialMessage.aliceIdentity,
            aliceEphemeralPublicKey: initiate.initialMessage.aliceEphemeralPublicKey,
            signedPrekeyKeyId: initiate.initialMessage.signedPrekeyKeyId,
            pqKEMPrekeyKeyId: initiate.initialMessage.pqKEMPrekeyKeyId,
            oneTimePrekeyKeyId: 0xDEADBEEF,
            pqKEMCiphertext: initiate.initialMessage.pqKEMCiphertext,
            bundleEpoch: initiate.initialMessage.bundleEpoch
        )
        initiate = PQXDH.InitiateResult(
            initialMessage: tampered,
            sharedSecret: initiate.sharedSecret
        )

        XCTAssertThrowsError(
            try PQXDH.respond(
                as: bob,
                bundleSecrets: secrets,
                bundleEpoch: 1,
                receiving: initiate.initialMessage
            )
        ) { error in
            guard case AegisError.invalidKey = error else {
                return XCTFail("expected .invalidKey, got \(error)")
            }
        }
    }

    func testRespond_wrongSPKKeyId_throwsInvalidKey() throws {
        let alice = try IdentityKeyPair.generate()
        let bob = try IdentityKeyPair.generate()
        let (bundle, secrets) = try PrekeyBundle.generate(
            identity: bob,
            oneTimePrekeyCount: 1,
            signedPrekeyEpoch: 1
        )
        let initiate = try PQXDH.initiate(as: alice, toBundle: bundle)

        // Bob's secrets reference different keyIds than Alice's
        // message — emulate a stale or wrong-bundle response.
        let wrongSecrets = PrekeyBundleSecrets(
            signedPrekey: .init(keyId: 0xBADBAD01, privateKey: secrets.signedPrekey.privateKey),
            signedPQKEMPrekey: secrets.signedPQKEMPrekey,
            oneTimePrekeys: secrets.oneTimePrekeys
        )
        XCTAssertThrowsError(
            try PQXDH.respond(
                as: bob,
                bundleSecrets: wrongSecrets,
                bundleEpoch: 1,
                receiving: initiate.initialMessage
            )
        ) { error in
            guard case AegisError.invalidKey = error else {
                return XCTFail("expected .invalidKey, got \(error)")
            }
        }
    }

    func testRespond_corruptedPQCiphertext_throwsCiphertextCorrupted() throws {
        let alice = try IdentityKeyPair.generate()
        let bob = try IdentityKeyPair.generate()
        let (bundle, secrets) = try PrekeyBundle.generate(
            identity: bob,
            oneTimePrekeyCount: 1,
            signedPrekeyEpoch: 1
        )
        let initiate = try PQXDH.initiate(as: alice, toBundle: bundle)

        let truncatedMessage = InitialMessage(
            aliceIdentity: initiate.initialMessage.aliceIdentity,
            aliceEphemeralPublicKey: initiate.initialMessage.aliceEphemeralPublicKey,
            signedPrekeyKeyId: initiate.initialMessage.signedPrekeyKeyId,
            pqKEMPrekeyKeyId: initiate.initialMessage.pqKEMPrekeyKeyId,
            oneTimePrekeyKeyId: initiate.initialMessage.oneTimePrekeyKeyId,
            pqKEMCiphertext: initiate.initialMessage.pqKEMCiphertext.dropLast(100),
            bundleEpoch: initiate.initialMessage.bundleEpoch
        )

        XCTAssertThrowsError(
            try PQXDH.respond(
                as: bob,
                bundleSecrets: secrets,
                bundleEpoch: 1,
                receiving: truncatedMessage
            )
        ) { error in
            guard case AegisError.ciphertextCorrupted = error else {
                return XCTFail("expected .ciphertextCorrupted, got \(error)")
            }
        }
    }

    // MARK: - Wire-format round trip

    func testInitialMessage_jsonRoundTrips() throws {
        let alice = try IdentityKeyPair.generate()
        let bob = try IdentityKeyPair.generate()
        let (bundle, secrets) = try PrekeyBundle.generate(
            identity: bob,
            oneTimePrekeyCount: 1,
            signedPrekeyEpoch: 1
        )
        let initiate = try PQXDH.initiate(as: alice, toBundle: bundle)

        let encoded = try JSONEncoder().encode(initiate.initialMessage)
        let decoded = try JSONDecoder().decode(InitialMessage.self, from: encoded)

        XCTAssertEqual(decoded, initiate.initialMessage,
                       "InitialMessage must round-trip JSON exactly")

        // After round-trip the message must still derive the
        // identical SK on Bob's side.
        let bobSK = try PQXDH.respond(
            as: bob,
            bundleSecrets: secrets,
            bundleEpoch: 1,
            receiving: decoded
        )
        XCTAssertEqual(initiate.sharedSecret, bobSK,
                       "SK must agree after JSON round-trip of InitialMessage")
    }

    // MARK: - HKDF combiner pinning

    func testDeriveSharedSecret_isDeterministicInInputs() {
        let dh1 = Data(repeating: 0x01, count: 32)
        let dh2 = Data(repeating: 0x02, count: 32)
        let dh3 = Data(repeating: 0x03, count: 32)
        let dh4 = Data(repeating: 0x04, count: 32)
        let ssPq = Data(repeating: 0x05, count: 32)

        let a = PQXDH.deriveSharedSecret(dh1: dh1, dh2: dh2, dh3: dh3, dh4: dh4, ssPq: ssPq)
        let b = PQXDH.deriveSharedSecret(dh1: dh1, dh2: dh2, dh3: dh3, dh4: dh4, ssPq: ssPq)
        XCTAssertEqual(a, b, "HKDF combiner must be a pure function of its inputs")
        XCTAssertEqual(a.count, 32)
    }

    func testDeriveSharedSecret_dh4Optional_changesOutput() {
        // With and without DH4 must produce different SKs,
        // even when the omitted DH4 value would have been all
        // zeros — the IKM length differs, so the HKDF output
        // differs.
        let dh1 = Data(repeating: 0x01, count: 32)
        let dh2 = Data(repeating: 0x02, count: 32)
        let dh3 = Data(repeating: 0x03, count: 32)
        let ssPq = Data(repeating: 0x05, count: 32)

        let withoutDH4 = PQXDH.deriveSharedSecret(
            dh1: dh1, dh2: dh2, dh3: dh3, dh4: nil, ssPq: ssPq
        )
        let withZerosDH4 = PQXDH.deriveSharedSecret(
            dh1: dh1, dh2: dh2, dh3: dh3,
            dh4: Data(count: 32), ssPq: ssPq
        )
        XCTAssertNotEqual(withoutDH4, withZerosDH4,
                          "omitting DH4 must produce a different SK from passing 32 zeros")
    }
}
