// RatchetTests.swift
// Tests for the symmetric-ratchet primitives that underlie
// the Double Ratchet (commits 2-4 of Sprint 5).

import CryptoKit
import XCTest
@testable import AegisCrypto

final class RatchetTests: XCTestCase {

    // MARK: - ChainKey advancement

    func testAdvance_isDeterministic() {
        let seed = Data(repeating: 0xAA, count: 32)
        let ck = ChainKey(bytes: seed)
        let (next1, mk1) = ck.advance()
        let (next2, mk2) = ck.advance()
        XCTAssertEqual(next1, next2,
                       "advance() must be a pure function of the chain key")
        XCTAssertEqual(mk1, mk2)
    }

    func testAdvance_distinguishesNextChainAndMessageKey() {
        // The two HMAC outputs (one with tag 0x01, one with
        // tag 0x02) must differ. If they ever match, an
        // attacker who learns one byte of state could derive
        // both. Cheap sanity check.
        let ck = ChainKey(bytes: Data(repeating: 0x42, count: 32))
        let (nextCk, mk) = ck.advance()
        XCTAssertNotEqual(nextCk.bytes, mk.bytes,
                          "next chain key and message key must differ")
    }

    func testAdvance_chainProgresses() {
        // CK_0 → CK_1 → CK_2 must all be distinct. A collapsed
        // chain (CK_n == CK_n+k for some k) destroys forward
        // secrecy.
        var ck = ChainKey(bytes: Data(repeating: 0x01, count: 32))
        var seen: Set<Data> = [ck.bytes]
        for _ in 0..<8 {
            ck = ck.advance().next
            XCTAssertFalse(
                seen.contains(ck.bytes),
                "chain key collision after fewer than 9 advances — impossible without HMAC compromise"
            )
            seen.insert(ck.bytes)
        }
    }

    func testAdvance_messageKeysAreDistinct() {
        // The first 8 message keys derived from a single chain
        // must all differ.
        var ck = ChainKey(bytes: Data(repeating: 0x02, count: 32))
        var keys: Set<Data> = []
        for _ in 0..<8 {
            let (next, mk) = ck.advance()
            XCTAssertFalse(keys.contains(mk.bytes),
                           "message-key collision in first 8 steps")
            keys.insert(mk.bytes)
            ck = next
        }
    }

    func testAdvance_differentSeeds_yieldDistinctChains() {
        let a = ChainKey(bytes: Data(repeating: 0x11, count: 32))
        let b = ChainKey(bytes: Data(repeating: 0x22, count: 32))
        XCTAssertNotEqual(a.advance().next, b.advance().next)
        XCTAssertNotEqual(a.advance().message, b.advance().message)
    }

    // MARK: - MessageKey derivation

    func testDerive_isDeterministic() throws {
        let mk = MessageKey(bytes: Data(repeating: 0x33, count: 32))
        let a = try mk.derive()
        let b = try mk.derive()
        XCTAssertEqual(
            a.encryptionKey.withUnsafeBytes { Data($0) },
            b.encryptionKey.withUnsafeBytes { Data($0) }
        )
        XCTAssertEqual(Data(a.nonce), Data(b.nonce))
    }

    func testDerive_differentMessageKeys_yieldDistinctMaterial() throws {
        let mk1 = MessageKey(bytes: Data(repeating: 0xAA, count: 32))
        let mk2 = MessageKey(bytes: Data(repeating: 0xBB, count: 32))
        let a = try mk1.derive()
        let b = try mk2.derive()
        XCTAssertNotEqual(
            a.encryptionKey.withUnsafeBytes { Data($0) },
            b.encryptionKey.withUnsafeBytes { Data($0) }
        )
        XCTAssertNotEqual(Data(a.nonce), Data(b.nonce))
    }

    func testDerive_keyShape() throws {
        let mk = MessageKey(bytes: Data(repeating: 0x77, count: 32))
        let derived = try mk.derive()
        XCTAssertEqual(derived.encryptionKey.bitCount, 256,
                       "AES-256 expects a 256-bit key")
        XCTAssertEqual(Data(derived.nonce).count, 12,
                       "AES-GCM expects a 12-byte nonce")
    }

    // MARK: - End-to-end usage with AES-GCM

    func testDerivedKeys_canEncryptAndDecrypt() throws {
        // The whole point of MessageKey.derive() is to feed
        // AEAD encryption/decryption. Round-trip a sample.
        let mk = MessageKey(bytes: Data(repeating: 0x99, count: 32))
        let derived = try mk.derive()
        let plaintext = Data("hello ratchet".utf8)
        let aad = Data("conversation-id".utf8)

        let aes = AESGCM()
        let payload = try aes.encrypt(
            plaintext,
            key: derived.encryptionKey,
            nonce: derived.nonce,
            additionalData: aad
        )
        let recovered = try aes.decrypt(payload, key: derived.encryptionKey)
        XCTAssertEqual(recovered, plaintext)
    }

    // MARK: - Snapshot KAT

    /// Pinned chain advancement output. If the symmetric
    /// ratchet construction (HMAC-SHA-256 with our 0x01/0x02
    /// domain-separator tags) ever changes, these constants
    /// catch it before any session goes off-rails.
    /// Captured on macOS 26.4 / Xcode 26.4.1 / Swift 6.3.1.
    func testKAT_pinnedAdvancement() {
        let seed = Data(repeating: 0xCC, count: 32)
        let (next, mk) = ChainKey(bytes: seed).advance()

        let nextHex = next.bytes.map { String(format: "%02x", $0) }.joined()
        let mkHex = mk.bytes.map { String(format: "%02x", $0) }.joined()

        XCTAssertEqual(
            nextHex,
            "a05d2d057a2649da92a9c9afe7272c639aba867f7186ccf7fc8e16bd526ef696",
            "next chain-key drift"
        )
        XCTAssertEqual(
            mkHex,
            "75e88bd30a30f221d8f619274e149e8714c1ccefc82d469ec485bf2ba5024540",
            "message-key drift"
        )
    }

    // MARK: - RootKey ratchet step

    func testRootKey_ratchet_isDeterministic() {
        let rk = RootKey(bytes: Data(repeating: 0xDD, count: 32))
        let dh = Data(repeating: 0xEE, count: 32)
        let a = rk.ratchet(with: dh)
        let b = rk.ratchet(with: dh)
        XCTAssertEqual(a.root, b.root)
        XCTAssertEqual(a.chain, b.chain)
    }

    func testRootKey_ratchet_distinguishesNextRootAndChain() {
        // The two halves of HKDF output must differ (otherwise
        // collapsing). Cheap sanity check.
        let rk = RootKey(bytes: Data(repeating: 0x11, count: 32))
        let (root, chain) = rk.ratchet(with: Data(repeating: 0x22, count: 32))
        XCTAssertNotEqual(root.bytes, chain.bytes)
    }

    func testRootKey_ratchet_distinctDHOutputs_yieldDistinctState() {
        let rk = RootKey(bytes: Data(repeating: 0x33, count: 32))
        let a = rk.ratchet(with: Data(repeating: 0x44, count: 32))
        let b = rk.ratchet(with: Data(repeating: 0x55, count: 32))
        XCTAssertNotEqual(a.root, b.root)
        XCTAssertNotEqual(a.chain, b.chain)
    }

    func testRootKey_ratchet_distinctRoots_yieldDistinctState() {
        // Same DH output, different starting RK — outputs must
        // differ. Verifies that the salt parameter (the old
        // RK) actually contributes entropy.
        let dh = Data(repeating: 0x66, count: 32)
        let rk1 = RootKey(bytes: Data(repeating: 0xAA, count: 32))
        let rk2 = RootKey(bytes: Data(repeating: 0xBB, count: 32))
        let a = rk1.ratchet(with: dh)
        let b = rk2.ratchet(with: dh)
        XCTAssertNotEqual(a.root, b.root)
        XCTAssertNotEqual(a.chain, b.chain)
    }

    func testRootKey_ratchet_endToEnd_withX25519Output() throws {
        // Two parties with mirrored X25519 keypairs ratchet
        // from the same starting RK. Both sides must derive
        // the same (next root, next chain).
        let alice = X25519.generateKeyPair()
        let bob = X25519.generateKeyPair()
        let dhAlice = try X25519.sharedSecret(
            privateKey: alice.privateKey, peerPublicKey: bob.publicKey
        )
        let dhBob = try X25519.sharedSecret(
            privateKey: bob.privateKey, peerPublicKey: alice.publicKey
        )
        XCTAssertEqual(dhAlice, dhBob, "X25519 must agree to start")

        let rk = RootKey(bytes: Data(repeating: 0x77, count: 32))
        let aliceStep = rk.ratchet(with: dhAlice)
        let bobStep = rk.ratchet(with: dhBob)
        XCTAssertEqual(aliceStep.root, bobStep.root)
        XCTAssertEqual(aliceStep.chain, bobStep.chain)
    }

    func testKAT_pinnedRootKeyRatchet() {
        let rk = RootKey(bytes: Data(repeating: 0xCC, count: 32))
        let dh = Data(repeating: 0xDD, count: 32)
        let (root, chain) = rk.ratchet(with: dh)

        let rootHex = root.bytes.map { String(format: "%02x", $0) }.joined()
        let chainHex = chain.bytes.map { String(format: "%02x", $0) }.joined()

        XCTAssertEqual(
            rootHex,
            "fa3d063c6a20c0ad135fc7bf918d944205cac253a028a3ab8c725ec59e0224ed",
            "DH-ratchet root-key drift"
        )
        XCTAssertEqual(
            chainHex,
            "2617131fabb6c74efdee4260fd4dcf2618383df7e9dc480c48152a9e42af6c9e",
            "DH-ratchet chain-key drift"
        )
    }
}
