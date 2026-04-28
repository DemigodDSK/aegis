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

    // MARK: - Out-of-order delivery (skipped-keys cache)

    func testOutOfOrder_singleChain_decodesEventually() throws {
        // Alice sends three messages in one chain. Bob
        // receives them in order 0, 2, 1. All three must
        // decrypt to the right plaintext.
        var (alice, bob, _) = try makePair()
        let m0 = try alice.encrypt(Data("zero".utf8))
        let m1 = try alice.encrypt(Data("one".utf8))
        let m2 = try alice.encrypt(Data("two".utf8))

        XCTAssertEqual(try bob.decrypt(m0), Data("zero".utf8))
        // Skip ahead — m2 arrives before m1. The skipped-keys
        // cache lets m1 still decrypt later.
        XCTAssertEqual(try bob.decrypt(m2), Data("two".utf8))
        XCTAssertEqual(try bob.decrypt(m1), Data("one".utf8))
    }

    func testOutOfOrder_acrossDHRotation() throws {
        // Alice sends two, Bob replies (DH rotates), Alice
        // sends two more. Bob receives Alice's first chain in
        // reverse order *after* his reply has already been
        // ratcheted — the "old chain" keys must be cached
        // through the DH step so late arrivals still work.
        var (alice, bob, _) = try makePair()

        let a0 = try alice.encrypt(Data("a-0".utf8))
        let a1 = try alice.encrypt(Data("a-1".utf8))

        // Bob receives only a0 first; a1 is still in flight.
        XCTAssertEqual(try bob.decrypt(a0), Data("a-0".utf8))

        // Bob replies, rotating his DH on Alice's side.
        let b0 = try bob.encrypt(Data("b-0".utf8))
        XCTAssertEqual(try alice.decrypt(b0), Data("b-0".utf8))

        // Now Alice sends two more in her *new* chain.
        let a2 = try alice.encrypt(Data("a-2".utf8))
        let a3 = try alice.encrypt(Data("a-3".utf8))
        XCTAssertEqual(try bob.decrypt(a2), Data("a-2".utf8))
        XCTAssertEqual(try bob.decrypt(a3), Data("a-3".utf8))

        // Finally a1 from the old chain straggles in — must
        // decrypt cleanly using a key cached during Bob's
        // DH-step catch-up.
        XCTAssertEqual(try bob.decrypt(a1), Data("a-1".utf8))
    }

    func testOutOfOrder_excessiveSkip_rejected() throws {
        // Bob fakes an inbound message claiming a wildly
        // future messageNumber. Bob (or rather, the receiving
        // side) must refuse to derive 1M+ keys.
        var (alice, bob, _) = try makePair()
        let real = try alice.encrypt(Data("real".utf8))

        let evil = RatchetMessage(
            header: RatchetMessageHeader(
                dhPublicKey: real.header.dhPublicKey,
                previousChainLength: real.header.previousChainLength,
                messageNumber: 5000  // > maxSkipPerInboundMessage (1000)
            ),
            payload: real.payload
        )

        XCTAssertThrowsError(try bob.decrypt(evil)) { error in
            guard case AegisError.invalidNonce(let reason) = error else {
                return XCTFail("expected .invalidNonce, got \(error)")
            }
            XCTAssertTrue(reason.contains("skip distance"),
                          "reason should mention skip distance; got: \(reason)")
        }
    }

    func testCache_evictionBound() throws {
        // Push more than maxSkippedKeysCache messages of skip
        // across a single chain (via a fake "messageNumber"
        // jump on the very last message). Cache must stay
        // bounded.
        var (alice, bob, _) = try makePair()

        // Send and consume a single message to set the
        // chains in sync.
        let first = try alice.encrypt(Data("warm-up".utf8))
        XCTAssertEqual(try bob.decrypt(first), Data("warm-up".utf8))

        // Alice sends 1000 messages; Bob receives only the
        // 1000th. Bob caches 999 skipped keys + consumes 1 =
        // 999 cached after.
        var lastMsg: RatchetMessage!
        for i in 0..<RatchetSession.maxSkippedKeysCache {
            lastMsg = try alice.encrypt(Data("m-\(i)".utf8))
        }
        // Receive only the last one — Bob fast-forwards
        // through 999, caches them all, decrypts the final.
        XCTAssertEqual(
            try bob.decrypt(lastMsg),
            Data("m-\(RatchetSession.maxSkippedKeysCache - 1)".utf8)
        )

        // Cache must contain at most maxSkippedKeysCache
        // entries.
        XCTAssertLessThanOrEqual(
            bob.skippedKeys.count,
            RatchetSession.maxSkippedKeysCache,
            "skipped-keys cache must respect the bound"
        )
        XCTAssertEqual(
            bob.skippedKeys.count,
            bob.skippedKeysOrder.count,
            "skippedKeys and skippedKeysOrder must stay in lockstep"
        )
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
