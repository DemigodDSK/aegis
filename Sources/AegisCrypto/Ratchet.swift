// Ratchet.swift
// Symmetric ratchet primitives — the inside half of the
// Double Ratchet that arrives in later Sprint-5 commits.
//
// Conceptually:
//
//   ChainKey ─advance()─▶ (next ChainKey, MessageKey)
//   MessageKey ─derive()─▶ (encryption key, nonce) for AES-GCM
//
// One symmetric chain on each side of a session (sending and
// receiving) — each Encrypt advances the sending chain, each
// Decrypt advances the receiving chain. The chain keys are
// reset on every Diffie-Hellman ratchet step (commit 2 of this
// sprint).
//
// Construction follows Signal's Double Ratchet spec:
//
//   CK_next = HMAC-SHA-256(CK, 0x02)
//   MK      = HMAC-SHA-256(CK, 0x01)
//
// The single-byte tags 0x01 / 0x02 domain-separate the two
// derivations from the same chain key. Message keys are then
// expanded via HKDF-SHA-256 into the AES-256-GCM (32-byte key,
// 12-byte nonce) the AEAD layer needs. Domain string for the
// HKDF expansion is `AEGIS_RATCHET_MK_v1` — versioned so a
// future scheme change is loud.

import CryptoKit
import Foundation

/// A 32-byte symmetric-ratchet chain key. Advances on every
/// message and is rotated on every DH ratchet step.
public struct ChainKey: Sendable, Equatable {
    public static let byteCount = 32
    public let bytes: Data

    public init(bytes: Data) {
        precondition(
            bytes.count == ChainKey.byteCount,
            "ChainKey must be exactly \(ChainKey.byteCount) bytes; got \(bytes.count)"
        )
        self.bytes = bytes
    }

    /// Advance this chain key by one step. Returns the
    /// successor chain key (which the caller persists) and the
    /// message key for the current step (which the caller
    /// consumes immediately or caches in the
    /// skipped-message-keys store).
    ///
    /// The function is pure: identical input always yields
    /// identical outputs. Two consecutive advances of the same
    /// chain key always yield distinct outputs (otherwise the
    /// chain has collapsed — would mean catastrophic key
    /// reuse).
    public func advance() -> (next: ChainKey, message: MessageKey) {
        let key = SymmetricKey(data: bytes)
        let mk = HMAC<SHA256>.authenticationCode(
            for: Data([Self.messageKeyTag]),
            using: key
        )
        let nextCk = HMAC<SHA256>.authenticationCode(
            for: Data([Self.chainKeyTag]),
            using: key
        )
        return (
            next: ChainKey(bytes: Data(nextCk)),
            message: MessageKey(bytes: Data(mk))
        )
    }

    /// Domain-separator byte for chain-key derivation. Must
    /// differ from `messageKeyTag` so that a 32-byte HMAC
    /// output cannot be reinterpreted as a key of the other
    /// kind.
    private static let chainKeyTag: UInt8 = 0x02
    private static let messageKeyTag: UInt8 = 0x01
}

/// A 32-byte ratchet message key. Each MessageKey is consumed
/// at most once — either immediately (in-order delivery) or
/// after being cached in the skipped-message-keys store
/// (out-of-order delivery, commit 4 of this sprint).
public struct MessageKey: Sendable, Equatable {
    public static let byteCount = 32
    public let bytes: Data

    public init(bytes: Data) {
        precondition(
            bytes.count == MessageKey.byteCount,
            "MessageKey must be exactly \(MessageKey.byteCount) bytes; got \(bytes.count)"
        )
        self.bytes = bytes
    }

    /// Expand this message key into the AES-256-GCM material
    /// the AEAD layer expects: a 256-bit encryption key plus a
    /// 96-bit nonce.
    ///
    /// Throws only if the underlying CryptoKit nonce
    /// constructor rejects the bytes — should not happen
    /// since we feed it exactly 12 bytes from HKDF.
    public func derive() throws -> DerivedMessageKeys {
        let derived = HKDF<SHA256>.deriveKey(
            inputKeyMaterial: SymmetricKey(data: bytes),
            salt: Data(),
            info: Self.hkdfInfo,
            outputByteCount: 32 + 12
        )
        let raw = derived.withUnsafeBytes { Data($0) }
        let encKey = SymmetricKey(data: raw.prefix(32))

        let nonce: AES.GCM.Nonce
        do {
            nonce = try AES.GCM.Nonce(data: raw.suffix(12))
        } catch {
            throw AegisError.underlying(
                description: "ratchet message-key nonce derivation failed: \(error)"
            )
        }

        return DerivedMessageKeys(encryptionKey: encKey, nonce: nonce)
    }

    private static let hkdfInfo = Data("AEGIS_RATCHET_MK_v1".utf8)
}

/// The AES-256-GCM material expanded from a single MessageKey.
/// Treat as one-shot: a (key, nonce) pair MUST NOT be reused
/// for two encryptions — that would destroy GCM's
/// confidentiality and authentication guarantees.
public struct DerivedMessageKeys: Sendable {
    /// 256-bit AES key.
    public let encryptionKey: SymmetricKey

    /// 96-bit AES-GCM nonce.
    public let nonce: AES.GCM.Nonce

    public init(encryptionKey: SymmetricKey, nonce: AES.GCM.Nonce) {
        self.encryptionKey = encryptionKey
        self.nonce = nonce
    }
}
