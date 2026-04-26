// Encryption.swift
// The pluggable-cryptography seam.
//
// Every algorithm in Aegis — Tier 1 standards or Tier 2 sandbox —
// conforms to a single `Encryption` protocol. This is the abstraction
// that lets us swap algorithms per-conversation without leaking
// algorithm-specific concepts into the rest of the app.
//
// Rules every conformer MUST respect:
//
//   1. `encrypt(_:key:)` MUST produce an `EncryptedPayload` whose
//      `methodId` matches `self.method.id`.
//
//   2. `decrypt(_:key:)` MUST refuse a payload whose `methodId`
//      does not match (throw `.unsupportedMethod`).
//
//   3. Decryption failure due to a bad authentication tag MUST throw
//      `.authenticationFailed`. It MUST NOT return partial plaintext.
//
//   4. The implementation is responsible for validating key/nonce
//      sizes BEFORE calling into the underlying primitive.

import CryptoKit
import Foundation

/// The contract every Aegis encryption algorithm satisfies.
public protocol Encryption: Sendable {

    /// Metadata about this algorithm. Static (does not depend on
    /// per-instance state).
    var method: EncryptionMethod { get }

    /// Encrypt `plaintext` under `key`. Implementations choose the
    /// nonce (typically random for AEADs).
    func encrypt(_ plaintext: Data, key: SymmetricKey) throws -> EncryptedPayload

    /// Decrypt and authenticate `payload`. On any failure, throws
    /// an `AegisError` and returns no plaintext.
    func decrypt(_ payload: EncryptedPayload, key: SymmetricKey) throws -> Data
}

/// Algorithm-agnostic envelope around an encrypted message.
///
/// Wire format (JSON for v0.0.2; will move to a binary framing
/// once the wire-format spec freezes):
///
/// ```
/// {
///   "methodId":      "tier1.aes-256-gcm",
///   "nonce":         "<base64>",
///   "ciphertext":    "<base64>",
///   "tag":           "<base64>",
///   "additionalData": null
/// }
/// ```
///
/// The same envelope works for Tier 1 (AEAD) and any future Tier 1
/// or Tier 2 algorithms — fields not used by a given algorithm are
/// simply empty / nil.
public struct EncryptedPayload: Codable, Equatable, Sendable {

    /// The id of the `EncryptionMethod` that produced this payload.
    public let methodId: String

    /// Random nonce chosen at encryption time.
    public let nonce: Data

    /// Encrypted message body (for AEADs: ciphertext only — tag is
    /// stored separately for clarity).
    public let ciphertext: Data

    /// Authentication tag (for AEADs). Empty Data for non-AEAD
    /// algorithms that don't produce a separate tag.
    public let tag: Data

    /// Optional associated data that was authenticated but not
    /// encrypted (AEAD pattern).
    public let additionalData: Data?

    public init(
        methodId: String,
        nonce: Data,
        ciphertext: Data,
        tag: Data,
        additionalData: Data? = nil
    ) {
        self.methodId = methodId
        self.nonce = nonce
        self.ciphertext = ciphertext
        self.tag = tag
        self.additionalData = additionalData
    }
}
