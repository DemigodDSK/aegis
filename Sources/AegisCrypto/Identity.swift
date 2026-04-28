// Identity.swift
// Long-term user identity in Aegis.
//
// An Aegis identity is a *pair* of keypairs:
//
//   - A signing keypair (ML-DSA-65) — used to sign prekey
//     bundles, warrant canaries, and any other artefact whose
//     authorship a peer must verify.
//   - A Diffie-Hellman keypair (X25519) — used as the long-
//     term DH key inside PQXDH (the "IK" component of X3DH-
//     style handshakes).
//
// We do not (and cannot) re-use a single Curve25519 secret for
// both sign and DH the way classical Signal does, because
// ML-DSA and X25519 operate over different mathematical
// structures. The two-keypair shape is canonical for
// post-quantum hybrid identities.
//
// Persistence:
//   This file ships *in-memory* identity types only. Sprint 6
//   (iOS app shell) adds the AegisStorage layer that backs
//   identity keypairs onto the iOS Keychain / Secure Enclave.
//   Until then, identities are generated freshly per process.
//
// Wire format:
//   `IdentityPublicKey` is `Codable`. The default JSON
//   encoding is the v0.x wire format. A binary framing arrives
//   at v1.0; the JSON form remains usable forever as a
//   debug / interop fallback.

import Foundation

/// A complete, locally-held Aegis identity. Contains both the
/// signing keypair and the Diffie-Hellman keypair.
///
/// `IdentityKeyPair` is sensitive material — both component
/// `privateKey` byte strings are secrets. The canonical home
/// for these is the Keychain / Secure Enclave (see
/// `AegisStorage`); in-memory Swift values are short-lived
/// during a session.
///
/// `Codable` for serialisation into Keychain blobs; treat the
/// encoded form as just as sensitive as the in-memory one.
public struct IdentityKeyPair: Sendable, Codable {

    /// ML-DSA-65 signing keypair. Used for signing prekey
    /// bundles, attestations, and any artefact whose authorship
    /// must be verifiable by peers.
    public let signing: SignatureKeyPair

    /// X25519 Diffie-Hellman keypair. Used as the long-term
    /// "IK" key inside PQXDH and similar handshakes.
    public let dh: DHKeyPair

    public init(signing: SignatureKeyPair, dh: DHKeyPair) {
        self.signing = signing
        self.dh = dh
    }

    /// Generate a fresh identity keypair. Both component
    /// keypairs draw randomness from the system CSPRNG.
    public static func generate() throws -> IdentityKeyPair {
        let signer = MLDSA65Signature()
        let signing = try signer.generateKeyPair()
        let dh = X25519.generateKeyPair()
        return IdentityKeyPair(signing: signing, dh: dh)
    }

    /// The publishable form of this identity — what gets
    /// shared with peers and embedded in prekey bundles.
    public var publicKey: IdentityPublicKey {
        IdentityPublicKey(
            signing: signing.publicKey,
            dh: dh.publicKey
        )
    }
}

/// The publishable, network-shareable identity record.
///
/// Encodes to JSON for v0.x; pinned to a binary wire format at
/// v1.0. Two identities are considered the same iff both their
/// signing public key and their DH public key match — collision
/// requires breaking both ML-DSA-65 and X25519, which is the
/// hybrid-security goal of this construction.
public struct IdentityPublicKey: Sendable, Equatable, Codable {

    /// Raw 1952-byte ML-DSA-65 public key (FIPS 204 format).
    public let signing: Data

    /// Raw 32-byte X25519 public key.
    public let dh: Data

    public init(signing: Data, dh: Data) {
        self.signing = signing
        self.dh = dh
    }
}
