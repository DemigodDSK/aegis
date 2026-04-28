// RatchetSession.swift
// The Double Ratchet's bidirectional state and the
// encrypt/decrypt API the rest of the app sees.
//
// Per Signal's Double Ratchet spec, a session holds:
//
//   rootKey                   the outer-ratchet state
//   sendingChainKey           CKs — nil until first DH step
//   receivingChainKey         CKr — nil until first inbound message
//   sendingDH                 our current DH keypair
//   receivingDH               peer's last-seen DH public key
//   nSend, nRecv              message counters per current chain
//   prevSendingChainLength    PN — count of messages in our last sending chain
//
// Initialisation forks by role:
//
//   - Alice (initiator) seeds with the PQXDH SK and generates
//     a fresh DH keypair, then performs an immediate
//     DH-ratchet step against Bob's signed prekey to populate
//     her sending chain.
//   - Bob (responder) seeds with the same PQXDH SK and adopts
//     his existing signed prekey as his sending DH; chains
//     stay nil until his first inbound message triggers the
//     DH ratchet step.
//
// In-order delivery is fully supported in this commit. Out-of-
// order handling and the skipped-message-keys cache arrive in
// commit 4 of this sprint; until then a misordered message is
// rejected loudly with a clear error rather than producing
// silently wrong plaintext.

import CryptoKit
import Foundation

/// One-shot wire envelope sent by a Double Ratchet encrypt
/// step: a public header (so the receiver can advance their
/// state) plus the AES-256-GCM payload.
public struct RatchetMessage: Sendable, Codable, Equatable {
    public let header: RatchetMessageHeader
    public let payload: EncryptedPayload

    public init(header: RatchetMessageHeader, payload: EncryptedPayload) {
        self.header = header
        self.payload = payload
    }
}

/// Public per-message metadata attached to every Double
/// Ratchet ciphertext. Cleartext on the wire (header
/// encryption is a future enhancement — see Sprint 5 plan in
/// STAGES.md).
public struct RatchetMessageHeader: Sendable, Codable, Equatable {
    /// Sender's current sending-DH public key (32 bytes,
    /// X25519 raw).
    public let dhPublicKey: Data

    /// Number of messages the sender produced in their
    /// previous sending chain (the chain that was active
    /// before this header's DH step). Receivers use this to
    /// know how many keys to fast-forward in their
    /// just-retired receiving chain. Used by commit 4's
    /// out-of-order handling.
    public let previousChainLength: UInt32

    /// Sequence number of this message within the current
    /// sending chain (0-based).
    public let messageNumber: UInt32

    public init(
        dhPublicKey: Data,
        previousChainLength: UInt32,
        messageNumber: UInt32
    ) {
        self.dhPublicKey = dhPublicKey
        self.previousChainLength = previousChainLength
        self.messageNumber = messageNumber
    }
}

/// Bidirectional Double Ratchet state. Mutating struct — both
/// `encrypt` and `decrypt` advance state. Hold one per peer.
///
/// Codable: the entire session state — root key, both chain
/// keys, both DH keys, counters, and the skipped-keys cache —
/// is encoded as a single JSON object. Persistence consumers
/// (Sprint 8 onwards) treat the encoded blob as opaque
/// AEAD-protected ciphertext at the storage layer; the only
/// thing the storage layer needs to know is "Codable".
public struct RatchetSession: Sendable, Codable {

    /// Maximum number of skipped message keys we cache. Once
    /// reached, the oldest keys are evicted (LRU). Bounds
    /// memory under adversarial out-of-order delivery.
    public static let maxSkippedKeysCache: Int = 1000

    /// Maximum number of message keys we will derive in a
    /// single inbound message's catch-up step. A peer
    /// claiming a far-future messageNumber would otherwise
    /// pin our CPU.
    public static let maxSkipPerInboundMessage: UInt32 = 1000

    /// Outer-ratchet root key. Advances on every DH step.
    public private(set) var rootKey: RootKey

    /// Symmetric ratchet for outbound messages. Nil between
    /// session creation and the first DH step the local side
    /// initiates. After the first send the value is always
    /// present.
    public private(set) var sendingChainKey: ChainKey?

    /// Symmetric ratchet for inbound messages. Nil until the
    /// peer's first message arrives.
    public private(set) var receivingChainKey: ChainKey?

    /// Our local DH keypair. Replaced on every DH ratchet step
    /// triggered by an inbound peer-DH change.
    public private(set) var sendingDH: DHKeyPair

    /// Peer's last-seen DH public key. Nil until first inbound
    /// message.
    public private(set) var receivingDH: Data?

    /// Counter of messages we have sent in the current sending
    /// chain.
    public private(set) var nSend: UInt32

    /// Counter of messages we have received in the current
    /// receiving chain.
    public private(set) var nRecv: UInt32

    /// Number of messages we sent in the previous sending
    /// chain (before our most recent DH step). Sent in every
    /// header so the receiver can fast-forward their old
    /// receiving chain.
    public private(set) var previousSendingChainLength: UInt32

    /// Cache of message keys we derived during a catch-up step
    /// but did not yet consume. Keyed by (peer-DH-public-key,
    /// messageNumber-within-that-chain). Bounded LRU eviction
    /// keeps memory footprint at most `maxSkippedKeysCache`.
    var skippedKeys: [SkippedKeyIdentity: MessageKey]

    /// FIFO ordering of `skippedKeys` insertions for LRU
    /// eviction. Parallel to `skippedKeys` (always
    /// `.count == skippedKeys.count`).
    var skippedKeysOrder: [SkippedKeyIdentity]

    private init(
        rootKey: RootKey,
        sendingChainKey: ChainKey?,
        receivingChainKey: ChainKey?,
        sendingDH: DHKeyPair,
        receivingDH: Data?
    ) {
        self.rootKey = rootKey
        self.sendingChainKey = sendingChainKey
        self.receivingChainKey = receivingChainKey
        self.sendingDH = sendingDH
        self.receivingDH = receivingDH
        self.nSend = 0
        self.nRecv = 0
        self.previousSendingChainLength = 0
        self.skippedKeys = [:]
        self.skippedKeysOrder = []
    }
}

/// Identity of a single cached skipped message key. The pair
/// `(dhPublicKey, messageNumber)` is unique per chain because
/// `dhPublicKey` is the peer's DH key that was active when the
/// chain produced the message.
struct SkippedKeyIdentity: Hashable, Sendable, Codable {
    let dhPublicKey: Data
    let messageNumber: UInt32
}

// MARK: - Initialisation

extension RatchetSession {

    /// Alice-side initialisation. Seeds the session from the
    /// PQXDH-derived shared secret and performs the first
    /// DH-ratchet step against Bob's signed prekey so Alice
    /// can immediately produce her first ciphertext.
    public static func initiateAsAlice(
        sharedSecret: Data,
        bobSignedPrekeyPublic: Data
    ) throws -> RatchetSession {
        guard sharedSecret.count == RootKey.byteCount else {
            throw AegisError.invalidKey(
                reason: "PQXDH shared secret must be \(RootKey.byteCount) bytes; got \(sharedSecret.count)"
            )
        }
        guard bobSignedPrekeyPublic.count == X25519.publicKeyByteCount else {
            throw AegisError.invalidKey(
                reason: "bob signed-prekey public key must be \(X25519.publicKeyByteCount) bytes"
            )
        }

        let sending = X25519.generateKeyPair()
        let dhOutput = try X25519.sharedSecret(
            privateKey: sending.privateKey,
            peerPublicKey: bobSignedPrekeyPublic
        )
        let initial = RootKey(bytes: sharedSecret)
        let (rk, ck) = initial.ratchet(with: dhOutput)

        return RatchetSession(
            rootKey: rk,
            sendingChainKey: ck,
            receivingChainKey: nil,
            sendingDH: sending,
            receivingDH: bobSignedPrekeyPublic
        )
    }

    /// Bob-side initialisation. Seeds the session from the
    /// PQXDH-derived shared secret and adopts the signed
    /// prekey keypair Alice DHed against — the chains stay
    /// nil until Bob's first inbound message arrives, at
    /// which point the DH ratchet step populates them.
    public static func initiateAsBob(
        sharedSecret: Data,
        signedPrekeyKeyPair: DHKeyPair
    ) throws -> RatchetSession {
        guard sharedSecret.count == RootKey.byteCount else {
            throw AegisError.invalidKey(
                reason: "PQXDH shared secret must be \(RootKey.byteCount) bytes; got \(sharedSecret.count)"
            )
        }
        guard signedPrekeyKeyPair.publicKey.count == X25519.publicKeyByteCount,
              signedPrekeyKeyPair.privateKey.count == X25519.privateKeyByteCount else {
            throw AegisError.invalidKey(
                reason: "signed prekey keypair has wrong-size components"
            )
        }
        return RatchetSession(
            rootKey: RootKey(bytes: sharedSecret),
            sendingChainKey: nil,
            receivingChainKey: nil,
            sendingDH: signedPrekeyKeyPair,
            receivingDH: nil
        )
    }
}

// MARK: - Encrypt

extension RatchetSession {

    public mutating func encrypt(
        _ plaintext: Data,
        additionalData: Data? = nil
    ) throws -> RatchetMessage {
        guard let ck = sendingChainKey else {
            throw AegisError.underlying(
                description: "RatchetSession.encrypt: no sending chain — Bob has not yet received Alice's first message"
            )
        }
        let (nextCK, mk) = ck.advance()
        let derived = try mk.derive()

        let header = RatchetMessageHeader(
            dhPublicKey: sendingDH.publicKey,
            previousChainLength: previousSendingChainLength,
            messageNumber: nSend
        )
        let aad = try Self.aadBytes(header: header, extra: additionalData)

        let aes = AESGCM()
        let payload = try aes.encrypt(
            plaintext,
            key: derived.encryptionKey,
            nonce: derived.nonce,
            additionalData: aad
        )

        sendingChainKey = nextCK
        nSend += 1

        return RatchetMessage(header: header, payload: payload)
    }
}

// MARK: - Decrypt

extension RatchetSession {

    public mutating func decrypt(
        _ message: RatchetMessage,
        additionalData: Data? = nil
    ) throws -> Data {
        // 1. Was this a previously-skipped message? Resolve
        //    from cache and we're done. Cache hit covers both
        //    "old chain, missed message arrived late" and
        //    "current chain, out-of-order arrival" cases —
        //    both look the same from the receiver's POV.
        if let plaintext = try tryConsumeSkippedKey(
            message: message,
            additionalData: additionalData
        ) {
            return plaintext
        }

        // 2. If the peer's DH rotated, fast-forward whatever
        //    keys we missed in our current receiving chain
        //    (saving them to cache so a late old-chain message
        //    can still be decrypted later) and then run the
        //    DH ratchet step.
        if receivingDH == nil || receivingDH != message.header.dhPublicKey {
            try skipKeysInCurrentChain(until: message.header.previousChainLength)
            try performDHRatchetStep(newPeerDH: message.header.dhPublicKey)
        }

        // 3. Within the current chain, fast-forward to the
        //    incoming message's number, caching every key
        //    we step over. The MAX_SKIP guard is enforced
        //    inside skipKeysInCurrentChain.
        try skipKeysInCurrentChain(until: message.header.messageNumber)

        // 4. Derive *this* message's key from the chain and
        //    decrypt.
        guard let ck = receivingChainKey else {
            throw AegisError.underlying(
                description: "RatchetSession.decrypt: no receiving chain after DH step (state corrupted?)"
            )
        }
        let (nextCK, mk) = ck.advance()
        let derived = try mk.derive()

        let aad = try Self.aadBytes(header: message.header, extra: additionalData)
        let payload = EncryptedPayload(
            methodId: message.payload.methodId,
            nonce: message.payload.nonce,
            ciphertext: message.payload.ciphertext,
            tag: message.payload.tag,
            additionalData: aad
        )
        let plaintext = try AESGCM().decrypt(payload, key: derived.encryptionKey)

        receivingChainKey = nextCK
        nRecv += 1
        return plaintext
    }

    /// Try to decrypt `message` using a previously-cached
    /// skipped key. Returns the plaintext on success, nil if
    /// we have no matching cached key. AEAD authentication is
    /// still performed — a tampered cached-decrypt fails with
    /// AegisError.authenticationFailed just like the in-chain
    /// path.
    private mutating func tryConsumeSkippedKey(
        message: RatchetMessage,
        additionalData: Data?
    ) throws -> Data? {
        let id = SkippedKeyIdentity(
            dhPublicKey: message.header.dhPublicKey,
            messageNumber: message.header.messageNumber
        )
        guard let mk = consumeSkippedKey(id: id) else { return nil }
        let derived = try mk.derive()
        let aad = try Self.aadBytes(header: message.header, extra: additionalData)
        let payload = EncryptedPayload(
            methodId: message.payload.methodId,
            nonce: message.payload.nonce,
            ciphertext: message.payload.ciphertext,
            tag: message.payload.tag,
            additionalData: aad
        )
        return try AESGCM().decrypt(payload, key: derived.encryptionKey)
    }

    /// Advance the current receiving chain to `until` (the
    /// soon-to-be-current `nRecv`), caching every key we step
    /// over so that out-of-order arrivals can decrypt later.
    /// Bounded by `maxSkipPerInboundMessage` so an attacker
    /// claiming far-future numbers cannot pin our CPU.
    private mutating func skipKeysInCurrentChain(until: UInt32) throws {
        // No chain yet → nothing to advance. Happens before
        // the first DH ratchet on Bob's side.
        guard receivingChainKey != nil else { return }

        // Refuse adversarial skip-counts.
        if until > nRecv && (until - nRecv) > Self.maxSkipPerInboundMessage {
            throw AegisError.invalidNonce(
                reason: "RatchetSession: skip distance \(until - nRecv) exceeds maxSkipPerInboundMessage (\(Self.maxSkipPerInboundMessage)) — possible DoS attempt"
            )
        }

        // The cache key needs the peer's DH public key for
        // *this* chain. Invariant: receivingChainKey != nil
        // implies receivingDH != nil (set by performDHRatchetStep).
        guard let chainDH = receivingDH else { return }

        while nRecv < until {
            guard let ck = receivingChainKey else { break }
            let (nextCK, mk) = ck.advance()
            let id = SkippedKeyIdentity(
                dhPublicKey: chainDH,
                messageNumber: nRecv
            )
            cacheSkippedKey(id: id, mk: mk)
            receivingChainKey = nextCK
            nRecv += 1
        }
    }

    private mutating func cacheSkippedKey(id: SkippedKeyIdentity, mk: MessageKey) {
        // If we are re-caching the same id (shouldn't happen
        // in a well-behaved session but defensive), refresh
        // the order entry.
        if skippedKeys[id] != nil {
            if let idx = skippedKeysOrder.firstIndex(of: id) {
                skippedKeysOrder.remove(at: idx)
            }
        }
        skippedKeys[id] = mk
        skippedKeysOrder.append(id)

        // LRU eviction.
        while skippedKeysOrder.count > Self.maxSkippedKeysCache {
            let evict = skippedKeysOrder.removeFirst()
            skippedKeys[evict] = nil
        }
    }

    private mutating func consumeSkippedKey(id: SkippedKeyIdentity) -> MessageKey? {
        guard let mk = skippedKeys.removeValue(forKey: id) else { return nil }
        if let idx = skippedKeysOrder.firstIndex(of: id) {
            skippedKeysOrder.remove(at: idx)
        }
        return mk
    }

    /// Apply a DH ratchet step in response to a peer-DH change
    /// observed in an inbound message. Runs two HKDF-on-RK
    /// derivations: one to seed the new receiving chain, one
    /// to seed the new sending chain (after a fresh local DH
    /// keypair is generated).
    private mutating func performDHRatchetStep(newPeerDH: Data) throws {
        guard newPeerDH.count == X25519.publicKeyByteCount else {
            throw AegisError.invalidKey(
                reason: "RatchetSession: peer DH public key wrong size"
            )
        }

        // 1. Mix DH(currentSendingDH, newPeerDH) into RK to
        //    produce the new receiving chain.
        let recvDHOutput = try X25519.sharedSecret(
            privateKey: sendingDH.privateKey,
            peerPublicKey: newPeerDH
        )
        let (rkAfterRecv, ckRecv) = rootKey.ratchet(with: recvDHOutput)
        rootKey = rkAfterRecv
        receivingChainKey = ckRecv
        receivingDH = newPeerDH

        // 2. Roll our local DH keypair, then mix DH(new local
        //    private, newPeerDH) into RK to produce the new
        //    sending chain. previousSendingChainLength carries
        //    the old nSend forward into the next outgoing
        //    header so a receiver who missed messages from
        //    the old chain knows how many to fast-forward.
        previousSendingChainLength = nSend
        nSend = 0
        nRecv = 0

        let newSendingDH = X25519.generateKeyPair()
        let sendDHOutput = try X25519.sharedSecret(
            privateKey: newSendingDH.privateKey,
            peerPublicKey: newPeerDH
        )
        let (rkAfterSend, ckSend) = rootKey.ratchet(with: sendDHOutput)
        rootKey = rkAfterSend
        sendingChainKey = ckSend
        sendingDH = newSendingDH
    }
}

// MARK: - AAD helper

extension RatchetSession {

    /// Stable JSON-encoded header bytes plus optional extra
    /// caller-supplied AAD. Both sides must produce the same
    /// bytes from the same header. We use `.sortedKeys` so
    /// the encoded form is independent of struct property
    /// declaration order.
    private static let stableHeaderEncoder: JSONEncoder = {
        let e = JSONEncoder()
        e.outputFormatting = [.sortedKeys]
        return e
    }()

    fileprivate static func aadBytes(
        header: RatchetMessageHeader,
        extra: Data?
    ) throws -> Data {
        var bytes = try stableHeaderEncoder.encode(header)
        if let extra = extra { bytes.append(extra) }
        return bytes
    }
}
