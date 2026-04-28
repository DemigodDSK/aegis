// KeyEncapsulation.swift
// The pluggable key-encapsulation seam.
//
// `KeyEncapsulation` is the parallel of `Encryption` for KEMs
// (Key Encapsulation Mechanisms). Where `Encryption` describes
// "given a key and a plaintext, produce a ciphertext", a KEM
// describes "given the peer's public key, derive a fresh shared
// secret AND a ciphertext that lets the peer derive that same
// secret". KEMs are how Aegis bootstraps a per-conversation AEAD
// key from each party's long-term identity.
//
// Rules every conformer MUST respect:
//
//   1. `generateKeyPair()` MUST use the system CSPRNG. Tests that
//      need a deterministic keypair go through algorithm-specific
//      seed-based initialisers, not through this protocol.
//
//   2. `encapsulate(toPublicKey:)` and `decapsulate(_:with:)` MUST
//      return a 256-bit `SymmetricKey`. The KEM is a key-agreement
//      primitive — the caller's protocol layer is responsible for
//      passing the result through a KDF before using it as an AEAD
//      key.
//
//   3. The serialised `publicKey` and `privateKey` byte forms in
//      `KEMKeyPair` are algorithm-specific and SHOULD be treated as
//      opaque by callers. Round-trip via the algorithm's own API
//      is the only supported usage; do not attempt to parse the
//      bytes.
//
//   4. Failure to deserialise a public or private key MUST throw
//      `AegisError.invalidKey`. Failure to decapsulate due to
//      structurally malformed ciphertext bytes MUST throw
//      `AegisError.ciphertextCorrupted`. Genuine ML-KEM-style
//      "implicit rejection" — a wrong-but-well-formed ciphertext —
//      does NOT throw: decapsulation succeeds and returns a
//      different shared secret, and the mismatch is detected at
//      the outer AEAD layer.

import CryptoKit
import Foundation

/// The contract every Aegis key-encapsulation algorithm satisfies.
public protocol KeyEncapsulation: Sendable {

    /// Metadata about this algorithm. Static (does not depend on
    /// per-instance state). The `EncryptionMethod` type is reused
    /// here for both AEADs and KEMs: it is a generic
    /// algorithm-description record, not bound to encryption per se.
    var method: EncryptionMethod { get }

    /// Generate a fresh keypair using the system CSPRNG. The
    /// returned `KEMKeyPair` carries opaque `publicKey` and
    /// `privateKey` byte representations suitable for storage and
    /// transmission.
    func generateKeyPair() throws -> KEMKeyPair

    /// Encapsulate against a peer's serialised public key. Returns
    /// the ciphertext to transmit to the peer alongside the shared
    /// secret to retain locally.
    func encapsulate(toPublicKey publicKey: Data) throws -> KEMEncapsulation

    /// Decapsulate `ciphertext` using our own serialised private
    /// key to recover the shared secret.
    func decapsulate(_ ciphertext: Data, with privateKey: Data) throws -> SymmetricKey
}

/// A KEM keypair, serialised for storage or transmission.
///
/// The `privateKey` bytes are sensitive material — store them in
/// the Keychain or Secure Enclave, not on disk in the clear.
public struct KEMKeyPair: Sendable, Equatable {

    /// Algorithm-specific public-key bytes. Treat as opaque. Send
    /// this to peers who want to encapsulate to you.
    public let publicKey: Data

    /// Algorithm-specific private-key bytes. Treat as opaque AND as
    /// secret. Anyone who reads these bytes can decapsulate every
    /// ciphertext sent to the corresponding `publicKey`.
    public let privateKey: Data

    public init(publicKey: Data, privateKey: Data) {
        self.publicKey = publicKey
        self.privateKey = privateKey
    }
}

/// The result of a single KEM encapsulation: the wire bytes the
/// sender transmits, and the shared secret the sender retains.
///
/// `KEMEncapsulation` is intentionally NOT `Equatable` — comparing
/// `SymmetricKey` instances requires going through their byte
/// representation, and silently doing that in `==` would risk
/// constant-time-comparison surprises. Tests that need to compare
/// two shared secrets do so explicitly via `withUnsafeBytes`.
public struct KEMEncapsulation: Sendable {

    /// Encapsulated bytes to send to the peer holding the matching
    /// private key. Algorithm-specific; treat as opaque.
    public let ciphertext: Data

    /// Symmetric shared secret derived by this encapsulation. Use
    /// as input to a KDF (typically HKDF) before deriving an AEAD
    /// key — do not use raw KEM output as an AEAD key directly.
    public let sharedSecret: SymmetricKey

    public init(ciphertext: Data, sharedSecret: SymmetricKey) {
        self.ciphertext = ciphertext
        self.sharedSecret = sharedSecret
    }
}
