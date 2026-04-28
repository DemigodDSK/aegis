// RatchetSessionTests.swift
// End-to-end tests for the Double Ratchet bidirectional
// session — initialisation, encrypt/decrypt round-trip, DH
// rotation, header AAD binding. Out-of-order delivery is
// tested in Sprint 5 commit 4 once the skipped-keys cache
// lands.

import CryptoKit
import XCTest
@testable import AegisCrypto

final class RatchetSessionTests: XCTestCase {

    /// Build a starting (Alice, Bob) session pair from a fixed
    /// shared secret. Mirrors the PQXDH → ratchet handoff
    /// without actually running PQXDH (covered separately in
    /// the PQXDH integration test added with commit 5).
    private func makePair(
        sharedSecret: Data = Data(repeating: 0xC1, count: 32)
    ) throws -> (alice: RatchetSession, bob: RatchetSession, bobSPK: DHKeyPair) {
        let bobSPK = X25519.generateKeyPair()
        let alice = try RatchetSession.initiateAsAlice(
            sharedSecret: sharedSecret,
            bobSignedPrekeyPublic: bobSPK.publicKey
        )
        let bob = try RatchetSession.initiateAsBob(
            sharedSecret: sharedSecret,
            signedPrekeyKeyPair: bobSPK
        )
        return (alice, bob, bobSPK)
    }

    // MARK: - Initialisation

    func testInitiateAsAlice_populatesSendingChain() throws {
        let (alice, _, _) = try makePair()
        XCTAssertNotNil(alice.sendingChainKey,
                        "Alice must have a sending chain ready immediately")
        XCTAssertNil(alice.receivingChainKey,
                     "Alice has no receiving chain until Bob replies")
    }

    func testInitiateAsBob_chainsAreNil() throws {
        let (_, bob, _) = try makePair()
        XCTAssertNil(bob.sendingChainKey,
                     "Bob has no sending chain until he runs his first DH ratchet step on inbound")
        XCTAssertNil(bob.receivingChainKey,
                     "Bob has no receiving chain until inbound message")
    }

    func testInitiate_rejectsWrongSizedSharedSecret() throws {
        let bobSPK = X25519.generateKeyPair()
        let bad = Data(repeating: 0x00, count: 16)  // not 32
        XCTAssertThrowsError(
            try RatchetSession.initiateAsAlice(
                sharedSecret: bad,
                bobSignedPrekeyPublic: bobSPK.publicKey
            )
        ) { error in
            guard case AegisError.invalidKey = error else {
                return XCTFail("expected .invalidKey, got \(error)")
            }
        }
    }

    // MARK: - Round trip: Alice → Bob (Bob's first inbound)

    func testRoundTrip_aliceToBob_first() throws {
        var (alice, bob, _) = try makePair()
        let plaintext = Data("hello bob".utf8)

        let m = try alice.encrypt(plaintext)
        let recovered = try bob.decrypt(m)

        XCTAssertEqual(recovered, plaintext)
    }

    func testRoundTrip_severalMessagesOneDirection() throws {
        var (alice, bob, _) = try makePair()
        let messages = ["one", "two", "three", "four", "five"].map { Data($0.utf8) }

        for m in messages {
            let envelope = try alice.encrypt(m)
            let recovered = try bob.decrypt(envelope)
            XCTAssertEqual(recovered, m)
        }
    }

    // MARK: - Round trip: bidirectional with DH rotation

    func testRoundTrip_bidirectional_with_DH_rotation() throws {
        // Alice → Bob → Alice → Bob …
        // Each direction-flip rotates DH keys and exercises
        // the full Double Ratchet flow.
        var (alice, bob, _) = try makePair()

        let plaintexts: [Data] = (0..<6).map {
            Data("msg-\($0)".utf8)
        }

        var fromAlice = true
        for m in plaintexts {
            if fromAlice {
                let env = try alice.encrypt(m)
                XCTAssertEqual(try bob.decrypt(env), m)
            } else {
                let env = try bob.encrypt(m)
                XCTAssertEqual(try alice.decrypt(env), m)
            }
            fromAlice.toggle()
        }
    }

    func testDH_rotation_advancesRootKey() throws {
        var (alice, bob, _) = try makePair()
        let rkBefore = alice.rootKey

        // Round trip: Bob's reply triggers Alice's DH ratchet.
        let m1 = try alice.encrypt(Data("first".utf8))
        _ = try bob.decrypt(m1)
        let m2 = try bob.encrypt(Data("reply".utf8))
        _ = try alice.decrypt(m2)

        XCTAssertNotEqual(alice.rootKey, rkBefore,
                          "DH ratchet must advance Alice's root key")
    }

    func testHeaderEcho_carriesPreviousChainLength() throws {
        // After Alice has sent N messages then Bob replies and
        // Alice replies again, Alice's new outgoing header must
        // report previousChainLength == N.
        var (alice, bob, _) = try makePair()

        for i in 0..<3 {
            let env = try alice.encrypt(Data("a-\(i)".utf8))
            _ = try bob.decrypt(env)
        }
        // Alice has sent 3. Now Bob replies (rotates his DH).
        let bobEnv = try bob.encrypt(Data("b-0".utf8))
        _ = try alice.decrypt(bobEnv)
        // Alice's next outgoing header should report
        // previousChainLength = 3.
        let aliceEnv = try alice.encrypt(Data("a-after".utf8))
        XCTAssertEqual(aliceEnv.header.previousChainLength, 3)
    }

    // MARK: - Bob can't send before first inbound

    func testBob_cannotEncryptBeforeFirstInbound() throws {
        var (_, bob, _) = try makePair()
        XCTAssertThrowsError(try bob.encrypt(Data("nope".utf8))) { error in
            guard case AegisError.underlying = error else {
                return XCTFail("expected .underlying, got \(error)")
            }
        }
    }

    // MARK: - Header AAD binding

    func testTamperedHeader_failsAuthentication() throws {
        var (alice, bob, _) = try makePair()
        var env = try alice.encrypt(Data("authenticated".utf8))
        // Tamper messageNumber while keeping the header
        // structurally valid. The receiving chain advance will
        // still produce the same key (because we only bound
        // the header to AAD), so the auth-tag check is what
        // catches this.
        let tamperedHeader = RatchetMessageHeader(
            dhPublicKey: env.header.dhPublicKey,
            previousChainLength: env.header.previousChainLength,
            messageNumber: env.header.messageNumber  // unchanged
        )
        // Actually tamper the dh key — receiving side will
        // mistakenly trigger a DH step against bogus bytes.
        var fakeDH = env.header.dhPublicKey
        fakeDH[0] ^= 0x01
        let tampered = RatchetMessage(
            header: RatchetMessageHeader(
                dhPublicKey: fakeDH,
                previousChainLength: tamperedHeader.previousChainLength,
                messageNumber: tamperedHeader.messageNumber
            ),
            payload: env.payload
        )
        XCTAssertThrowsError(try bob.decrypt(tampered),
                             "tampered DH key in header must NOT decrypt cleanly")
    }

    func testTamperedAAD_failsAuthentication() throws {
        var (alice, bob, _) = try makePair()
        let aad = Data("conversation-id".utf8)
        let env = try alice.encrypt(Data("body".utf8), additionalData: aad)
        // Bob decrypts with a different AAD — must fail.
        XCTAssertThrowsError(
            try bob.decrypt(env, additionalData: Data("different-id".utf8))
        ) { error in
            guard case AegisError.authenticationFailed = error else {
                return XCTFail("expected .authenticationFailed, got \(error)")
            }
        }
    }

    func testRoundTrip_withAdditionalData() throws {
        var (alice, bob, _) = try makePair()
        let aad = Data("conversation-id-12345".utf8)
        let env = try alice.encrypt(Data("body".utf8), additionalData: aad)
        let recovered = try bob.decrypt(env, additionalData: aad)
        XCTAssertEqual(recovered, Data("body".utf8))
    }

    // MARK: - Out-of-order is rejected (commit 4 will support)

    func testOutOfOrder_rejected_forNow() throws {
        // Alice sends three messages; Bob receives them in
        // order 0, 2, 1. The second inbound (msg #2) should
        // throw — current strict-in-order policy.
        var (alice, bob, _) = try makePair()
        let m0 = try alice.encrypt(Data("zero".utf8))
        let m1 = try alice.encrypt(Data("one".utf8))
        let m2 = try alice.encrypt(Data("two".utf8))

        _ = try bob.decrypt(m0)
        XCTAssertThrowsError(try bob.decrypt(m2)) { error in
            guard case AegisError.invalidNonce = error else {
                return XCTFail("expected .invalidNonce (out-of-order), got \(error)")
            }
        }
        // m1 still works
        XCTAssertEqual(try bob.decrypt(m1), Data("one".utf8))
    }

    // MARK: - Wire format

    func testRatchetMessage_jsonRoundTrips() throws {
        var (alice, bob, _) = try makePair()
        let env = try alice.encrypt(Data("on the wire".utf8))

        let encoded = try JSONEncoder().encode(env)
        let decoded = try JSONDecoder().decode(RatchetMessage.self, from: encoded)
        XCTAssertEqual(decoded, env)

        let recovered = try bob.decrypt(decoded)
        XCTAssertEqual(recovered, Data("on the wire".utf8))
    }
}
