// RatchetSessionCodableTests.swift
// Codable round-trip tests for `RatchetSession`. Persistence
// at the storage layer (Sprint 8) relies on the session being
// serialisable; these tests pin the round-trip semantics so a
// future refactor of the state shape can't silently break it.
//
// We test two layers:
//
//   1. Bytes round-trip — JSONEncoder + JSONDecoder yield a
//      session whose stored fields match the original.
//   2. Crypto round-trip — a session that has been encoded,
//      decoded, and then re-encrypted/-decrypted continues to
//      converse correctly with its (live) peer. This is the
//      stronger guarantee: the chain keys, root key, DH state,
//      and counters all need to survive the round-trip
//      identically for ciphertext to remain interpretable.

@testable import AegisCrypto
import Foundation
import XCTest

final class RatchetSessionCodableTests: XCTestCase {

    private let encoder: JSONEncoder = {
        let e = JSONEncoder()
        e.outputFormatting = [.sortedKeys]
        return e
    }()
    private let decoder = JSONDecoder()

    private func makePair(
        sharedSecret: Data = Data(repeating: 0xC2, count: 32)
    ) throws -> (alice: RatchetSession, bob: RatchetSession) {
        let bobSPK = X25519.generateKeyPair()
        let alice = try RatchetSession.initiateAsAlice(
            sharedSecret: sharedSecret,
            bobSignedPrekeyPublic: bobSPK.publicKey
        )
        let bob = try RatchetSession.initiateAsBob(
            sharedSecret: sharedSecret,
            signedPrekeyKeyPair: bobSPK
        )
        return (alice, bob)
    }

    // MARK: - Bytes round-trip

    func testFreshSession_encodesAndDecodes() throws {
        let (alice, _) = try makePair()
        let blob = try encoder.encode(alice)
        let restored = try decoder.decode(RatchetSession.self, from: blob)

        XCTAssertEqual(restored.rootKey, alice.rootKey)
        XCTAssertEqual(restored.sendingChainKey, alice.sendingChainKey)
        XCTAssertEqual(restored.receivingChainKey, alice.receivingChainKey)
        XCTAssertEqual(restored.sendingDH.publicKey, alice.sendingDH.publicKey)
        XCTAssertEqual(restored.sendingDH.privateKey, alice.sendingDH.privateKey)
        XCTAssertEqual(restored.receivingDH, alice.receivingDH)
        XCTAssertEqual(restored.nSend, alice.nSend)
        XCTAssertEqual(restored.nRecv, alice.nRecv)
        XCTAssertEqual(restored.previousSendingChainLength,
                       alice.previousSendingChainLength)
    }

    func testEncodeIsDeterministic_withSortedKeys() throws {
        let (alice, _) = try makePair()
        let blob1 = try encoder.encode(alice)
        let blob2 = try encoder.encode(alice)
        XCTAssertEqual(blob1, blob2,
                       "JSONEncoder.outputFormatting=.sortedKeys must produce stable bytes")
    }

    // MARK: - Crypto round-trip across restore

    func testRestoredAlice_keepsConversingWithLiveBob() throws {
        var (alice, bob) = try makePair()

        // Alice → Bob, in-order
        let m1 = try alice.encrypt(Data("hello".utf8))
        XCTAssertEqual(try bob.decrypt(m1), Data("hello".utf8))

        // Bob → Alice
        let m2 = try bob.encrypt(Data("hi".utf8))
        XCTAssertEqual(try alice.decrypt(m2), Data("hi".utf8))

        // Persist Alice across an "app restart"
        let blob = try encoder.encode(alice)
        var aliceRestored = try decoder.decode(RatchetSession.self, from: blob)

        // Restored Alice talks to live Bob: outbound and inbound
        let m3 = try aliceRestored.encrypt(Data("after restart".utf8))
        XCTAssertEqual(try bob.decrypt(m3), Data("after restart".utf8))

        let m4 = try bob.encrypt(Data("welcome back".utf8))
        XCTAssertEqual(try aliceRestored.decrypt(m4), Data("welcome back".utf8))
    }

    func testRestoredBob_keepsConversingWithLiveAlice() throws {
        var (alice, bob) = try makePair()

        let m1 = try alice.encrypt(Data("first".utf8))
        XCTAssertEqual(try bob.decrypt(m1), Data("first".utf8))

        let blob = try encoder.encode(bob)
        var bobRestored = try decoder.decode(RatchetSession.self, from: blob)

        let m2 = try bobRestored.encrypt(Data("second".utf8))
        XCTAssertEqual(try alice.decrypt(m2), Data("second".utf8))

        let m3 = try alice.encrypt(Data("third".utf8))
        XCTAssertEqual(try bobRestored.decrypt(m3), Data("third".utf8))
    }

    func testRestoreSurvives_dHRatchetStep() throws {
        var (alice, bob) = try makePair()

        let m1 = try alice.encrypt(Data("a".utf8))
        XCTAssertEqual(try bob.decrypt(m1), Data("a".utf8))

        // Bob replies — triggers his first DH ratchet step on
        // his next outbound. Then Alice receives and runs HER
        // DH ratchet step.
        let m2 = try bob.encrypt(Data("b".utf8))
        XCTAssertEqual(try alice.decrypt(m2), Data("b".utf8))

        // Round-trip both sides
        let aliceBlob = try encoder.encode(alice)
        var aliceRestored = try decoder.decode(RatchetSession.self, from: aliceBlob)
        let bobBlob = try encoder.encode(bob)
        var bobRestored = try decoder.decode(RatchetSession.self, from: bobBlob)

        // Continue the conversation across the restart
        let m3 = try aliceRestored.encrypt(Data("c".utf8))
        XCTAssertEqual(try bobRestored.decrypt(m3), Data("c".utf8))

        let m4 = try bobRestored.encrypt(Data("d".utf8))
        XCTAssertEqual(try aliceRestored.decrypt(m4), Data("d".utf8))
    }

    func testRestoreCarries_skippedKeysCache() throws {
        var (alice, bob) = try makePair()

        // Alice sends three messages; Bob receives only #2 first
        // (so #0 and #1 should land in his skipped-keys cache).
        let m0 = try alice.encrypt(Data("zero".utf8))
        let m1 = try alice.encrypt(Data("one".utf8))
        let m2 = try alice.encrypt(Data("two".utf8))

        XCTAssertEqual(try bob.decrypt(m2), Data("two".utf8))
        // Bob's skipped-keys cache should now contain #0 and #1

        // Persist Bob and restore
        let bobBlob = try encoder.encode(bob)
        var bobRestored = try decoder.decode(RatchetSession.self, from: bobBlob)

        // Late arrivals decrypt out of the (restored) cache
        XCTAssertEqual(try bobRestored.decrypt(m0), Data("zero".utf8))
        XCTAssertEqual(try bobRestored.decrypt(m1), Data("one".utf8))
    }

    // MARK: - Length validation on restore

    func testRestore_rejectsWrongSizedRootKey() throws {
        // Hand-craft a blob where rootKey has the wrong length.
        // We do this by encoding a real session, then patching
        // the JSON via a Dictionary round-trip.
        let (alice, _) = try makePair()
        let blob = try encoder.encode(alice)
        var json = try JSONSerialization.jsonObject(with: blob) as! [String: Any]
        // RootKey encodes as a single-value Data → base64 string.
        // Replace with a too-short base64 string.
        json["rootKey"] = "AAAA"  // 3 bytes decoded
        let patched = try JSONSerialization.data(withJSONObject: json)

        XCTAssertThrowsError(
            try decoder.decode(RatchetSession.self, from: patched)
        ) { error in
            guard error is DecodingError else {
                return XCTFail("expected DecodingError, got \(error)")
            }
        }
    }
}
