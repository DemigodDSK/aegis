// PQXDHRatchetIntegrationTests.swift
// End-to-end test of the Sprint 4 → Sprint 5 seam: an Alice
// who has fetched Bob's prekey bundle runs PQXDH to derive a
// shared secret, hands it to RatchetSession, and exchanges
// real bidirectional Double Ratchet messages with a Bob who
// did the same on his side.
//
// This is the "migration test" called out in
// Sprint 5 / issue #5: messages sealed via the ratchet must
// decrypt correctly when both sides bootstrapped from
// PQXDH-derived state. If anything in the seam drifts —
// PQXDH's HKDF output, RatchetSession's seed expectations,
// the SPK key-pair plumbing — this fails loudly.

import CryptoKit
import XCTest
@testable import AegisCrypto

final class PQXDHRatchetIntegrationTests: XCTestCase {

    /// Run a full PQXDH handshake, build matching ratchets on
    /// both sides, and return them ready for use.
    private func bootstrapPair(
        oneTimePrekeyCount: Int = 5
    ) throws -> (
        alice: RatchetSession,
        bob: RatchetSession,
        bundle: PrekeyBundle,
        bundleSecrets: PrekeyBundleSecrets,
        aliceIdentity: IdentityKeyPair,
        bobIdentity: IdentityKeyPair
    ) {
        let aliceIdentity = try IdentityKeyPair.generate()
        let bobIdentity = try IdentityKeyPair.generate()

        let (bundle, bundleSecrets) = try PrekeyBundle.generate(
            identity: bobIdentity,
            oneTimePrekeyCount: oneTimePrekeyCount,
            signedPrekeyEpoch: 1
        )

        // PQXDH.
        let initiate = try PQXDH.initiate(
            as: aliceIdentity, toBundle: bundle
        )
        let bobSK = try PQXDH.respond(
            as: bobIdentity,
            bundleSecrets: bundleSecrets,
            bundleEpoch: 1,
            receiving: initiate.initialMessage
        )
        XCTAssertEqual(initiate.sharedSecret, bobSK,
                       "PQXDH must produce identical SK on both sides")

        // Hand the SK off to the ratchets. Alice uses Bob's
        // signed-prekey *public* key (from the bundle) as her
        // initial peer DH; Bob uses the matching keypair from
        // his retained secrets.
        let bobSignedPrekey = DHKeyPair(
            publicKey: bundle.signedPrekey.publicKey,
            privateKey: bundleSecrets.signedPrekey.privateKey
        )

        let alice = try RatchetSession.initiateAsAlice(
            sharedSecret: initiate.sharedSecret,
            bobSignedPrekeyPublic: bundle.signedPrekey.publicKey
        )
        let bob = try RatchetSession.initiateAsBob(
            sharedSecret: bobSK,
            signedPrekeyKeyPair: bobSignedPrekey
        )

        return (alice, bob, bundle, bundleSecrets, aliceIdentity, bobIdentity)
    }

    // MARK: - Seam works end-to-end

    func testFullStack_aliceToBob_first() throws {
        var pair = try bootstrapPair()
        let plaintext = Data("first message after PQXDH".utf8)
        let env = try pair.alice.encrypt(plaintext)
        let recovered = try pair.bob.decrypt(env)
        XCTAssertEqual(recovered, plaintext)
    }

    func testFullStack_bidirectionalConversation() throws {
        // Several rounds of back-and-forth. Each direction
        // change rotates DH keys; the underlying seam between
        // PQXDH-seeded RK and the Double Ratchet's KDF_RK must
        // hold across the rotations.
        var pair = try bootstrapPair()

        let exchange: [(speaker: Speaker, body: String)] = [
            (.alice, "hello bob"),
            (.bob, "hi alice"),
            (.alice, "everything ok?"),
            (.alice, "(meant to ask sooner)"),
            (.bob, "yeah, all good"),
            (.bob, "the ratchet is rotating"),
            (.alice, "neat, signing off"),
        ]

        for step in exchange {
            let bytes = Data(step.body.utf8)
            switch step.speaker {
            case .alice:
                let env = try pair.alice.encrypt(bytes)
                XCTAssertEqual(try pair.bob.decrypt(env), bytes,
                               "[\(step.body)] failed to round-trip Alice→Bob")
            case .bob:
                let env = try pair.bob.encrypt(bytes)
                XCTAssertEqual(try pair.alice.decrypt(env), bytes,
                               "[\(step.body)] failed to round-trip Bob→Alice")
            }
        }
    }

    func testFullStack_outOfOrderAcrossDHRotation() throws {
        // Stress the cache through a real PQXDH handshake.
        // Alice sends two; Bob receives one; Bob replies (DH
        // rotates); Alice sends two more; Bob's missing
        // straggler from the first chain must still arrive
        // and decrypt cleanly via cache.
        var pair = try bootstrapPair()

        let a0 = try pair.alice.encrypt(Data("a-0".utf8))
        let a1 = try pair.alice.encrypt(Data("a-1".utf8))

        XCTAssertEqual(try pair.bob.decrypt(a0), Data("a-0".utf8))

        let b0 = try pair.bob.encrypt(Data("b-0".utf8))
        XCTAssertEqual(try pair.alice.decrypt(b0), Data("b-0".utf8))

        let a2 = try pair.alice.encrypt(Data("a-2".utf8))
        XCTAssertEqual(try pair.bob.decrypt(a2), Data("a-2".utf8))

        // a1 from Alice's old chain straggles in last.
        XCTAssertEqual(try pair.bob.decrypt(a1), Data("a-1".utf8))
    }

    func testFullStack_independentSessions_deriveDistinctRatchets() throws {
        // Two independently-bootstrapped sessions against the
        // same Bob (same bundle, two separate PQXDHs) must
        // derive distinct shared secrets and therefore
        // distinct ratchet states. No cross-session
        // decryptability.
        let bobIdentity = try IdentityKeyPair.generate()
        let (bundle, secrets) = try PrekeyBundle.generate(
            identity: bobIdentity,
            oneTimePrekeyCount: 4,
            signedPrekeyEpoch: 1
        )
        let aliceIdentity = try IdentityKeyPair.generate()

        let init1 = try PQXDH.initiate(as: aliceIdentity, toBundle: bundle)
        let init2 = try PQXDH.initiate(as: aliceIdentity, toBundle: bundle)
        XCTAssertNotEqual(init1.sharedSecret, init2.sharedSecret,
                          "two PQXDH runs against the same bundle must produce distinct SKs")

        let bobSignedPrekey = DHKeyPair(
            publicKey: bundle.signedPrekey.publicKey,
            privateKey: secrets.signedPrekey.privateKey
        )

        var alice1 = try RatchetSession.initiateAsAlice(
            sharedSecret: init1.sharedSecret,
            bobSignedPrekeyPublic: bundle.signedPrekey.publicKey
        )
        var bob1 = try RatchetSession.initiateAsBob(
            sharedSecret: init1.sharedSecret,
            signedPrekeyKeyPair: bobSignedPrekey
        )
        var bob2 = try RatchetSession.initiateAsBob(
            sharedSecret: init2.sharedSecret,
            signedPrekeyKeyPair: bobSignedPrekey
        )

        let env = try alice1.encrypt(Data("session 1 only".utf8))
        XCTAssertEqual(try bob1.decrypt(env), Data("session 1 only".utf8),
                       "session 1 must decrypt itself")

        // Bob2 (different SK) must NOT decrypt the session-1
        // ciphertext. AEAD authentication should reject.
        XCTAssertThrowsError(try bob2.decrypt(env),
                             "session 2 must not decrypt session-1 ciphertext")
    }

    // MARK: - Helpers

    private enum Speaker { case alice, bob }
}
