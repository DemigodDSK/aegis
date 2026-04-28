// Signature.swift
// The pluggable digital-signature seam.
//
// `Signature` is the third pluggable algorithm seam in Aegis,
// alongside `Encryption` (AEAD) and `KeyEncapsulation` (KEM).
// Where AEAD answers "does this party with the symmetric key
// see the same plaintext I sealed?" and KEM answers "can this
// party with the matching private key derive the shared secret
// I encapsulated?", a signature answers "is this party with the
// matching public key the one that endorsed this message?".
//
// Signatures are the bedrock of identity in Aegis: every
// long-term identity public key is a signature key. Once we
// have signatures we can sign prekey bundles, sign warrant
// canaries from inside the app, and bootstrap any protocol
// that needs authenticated artefacts.
//
// Rules every conformer MUST respect:
//
//   1. `generateKeyPair()` MUST use the system CSPRNG. Tests
//      that need a deterministic keypair go through algorithm-
//      specific seed-based initialisers, not through this
//      protocol.
//
//   2. `sign(_:with:)` MUST throw `AegisError.invalidKey` if
//      `privateKey` cannot be deserialised. The signature
//      itself MUST be deterministic OR randomised per the
//      algorithm's published spec (ML-DSA hedges signing with
//      internal randomness; signing the same message twice
//      typically yields different bytes — both verifiable).
//
//   3. `isValidSignature(_:of:by:)` MUST throw
//      `AegisError.invalidKey` if `publicKey` bytes are
//      structurally malformed, but MUST return `false` (not
//      throw) on a well-formed key whose verification simply
//      fails. The distinction matters: callers need to tell
//      "I have garbage" from "I have a forgery".
//
//   4. The serialised `publicKey` and `privateKey` byte forms
//      in `SignatureKeyPair` are algorithm-specific and SHOULD
//      be treated as opaque by callers. Round-trip via the
//      algorithm's own API is the only supported usage; do not
//      attempt to parse the bytes.

import CryptoKit
import Foundation

/// The contract every Aegis signature algorithm satisfies.
public protocol Signature: Sendable {

    /// Metadata about this algorithm. Static (does not depend
    /// on per-instance state). The `EncryptionMethod` type is
    /// reused here for AEADs, KEMs, and signatures: it is a
    /// generic algorithm-description record.
    var method: EncryptionMethod { get }

    /// Generate a fresh signature keypair using the system
    /// CSPRNG.
    func generateKeyPair() throws -> SignatureKeyPair

    /// Sign `message` under `privateKey` and return the
    /// signature bytes.
    ///
    /// - Throws: `AegisError.invalidKey` if `privateKey` bytes
    ///   cannot be deserialised. `AegisError.underlying` for
    ///   any other error from the underlying primitive.
    func sign(_ message: Data, with privateKey: Data) throws -> Data

    /// Verify `signature` against `publicKey` and `message`.
    /// Returns `true` if and only if the signature is a valid
    /// endorsement of `message` by the holder of the matching
    /// private key.
    ///
    /// - Throws: `AegisError.invalidKey` if `publicKey` bytes
    ///   are structurally malformed. Does NOT throw on a
    ///   well-formed key whose verification simply fails —
    ///   that case returns `false`.
    func isValidSignature(
        _ signature: Data,
        of message: Data,
        by publicKey: Data
    ) throws -> Bool
}

/// A signature keypair, serialised for storage or transmission.
///
/// The `privateKey` bytes are sensitive material — store them
/// in the Keychain or Secure Enclave, not on disk in the clear.
public struct SignatureKeyPair: Sendable, Equatable {

    /// Algorithm-specific public-key bytes. Treat as opaque.
    /// Publish this as part of an identity record so peers can
    /// verify signatures by you.
    public let publicKey: Data

    /// Algorithm-specific private-key bytes. Treat as opaque
    /// AND as secret. Anyone who reads these bytes can sign
    /// indistinguishably from you.
    public let privateKey: Data

    public init(publicKey: Data, privateKey: Data) {
        self.publicKey = publicKey
        self.privateKey = privateKey
    }
}
