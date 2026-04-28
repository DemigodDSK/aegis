// X25519.swift
// Tier 1 algorithm: X25519 elliptic-curve Diffie-Hellman.
//
// X25519 is the classical-DH primitive of choice for Aegis,
// used inside PQXDH (alongside ML-KEM-1024) and inside the
// X-Wing hybrid KEM (transparently to AegisCrypto callers).
//
// References:
//   - RFC 7748 (Elliptic Curves for Security)
//   - https://datatracker.ietf.org/doc/html/rfc7748
//
// Why no `KeyAgreement` protocol seam?
//   We have a single DH primitive in Aegis Tier 1 and no
//   plausible Tier 1 successor on the horizon (P-256 / P-384
//   are not used; the post-quantum component is handled by
//   the KEM layer, not by another DH curve). Introducing a
//   protocol seam now would be premature abstraction. If a
//   second DH algorithm enters Aegis later, refactoring this
//   file into a `KeyAgreement` protocol conformer is straight-
//   forward.
//
// Implementation notes:
//   - We wrap Apple's `CryptoKit.Curve25519.KeyAgreement`
//     directly. No Aegis-side cryptographic logic.
//   - Per FIPS 203 / SP 800-56C guidance, the raw 32-byte
//     output of an ECDH operation should be passed through a
//     KDF (typically HKDF) before being used as a symmetric
//     key. Callers receive raw bytes from this module and are
//     responsible for the KDF step. PQXDH uses this directly
//     in its HKDF concatenation.

import CryptoKit
import Foundation

/// X25519 elliptic-curve Diffie-Hellman. Tier 1 namespace.
public enum X25519 {

    public static let publicKeyByteCount = 32
    public static let privateKeyByteCount = 32
    public static let sharedSecretByteCount = 32

    /// Generate a fresh keypair using the system CSPRNG.
    public static func generateKeyPair() -> DHKeyPair {
        let priv = Curve25519.KeyAgreement.PrivateKey()
        return DHKeyPair(
            publicKey: priv.publicKey.rawRepresentation,
            privateKey: priv.rawRepresentation
        )
    }

    /// Compute the X25519 shared secret given our private key
    /// and a peer's public key. Returns 32 raw bytes — these
    /// MUST be passed through HKDF (or another KDF) before
    /// being used as a symmetric key.
    ///
    /// - Throws: `AegisError.invalidKey` if either byte string
    ///   is the wrong length or otherwise unparseable.
    public static func sharedSecret(
        privateKey: Data,
        peerPublicKey: Data
    ) throws -> Data {
        guard privateKey.count == privateKeyByteCount else {
            throw AegisError.invalidKey(
                reason: "X25519 private key must be \(privateKeyByteCount) bytes; got \(privateKey.count)"
            )
        }
        guard peerPublicKey.count == publicKeyByteCount else {
            throw AegisError.invalidKey(
                reason: "X25519 peer public key must be \(publicKeyByteCount) bytes; got \(peerPublicKey.count)"
            )
        }

        let priv: Curve25519.KeyAgreement.PrivateKey
        do {
            priv = try Curve25519.KeyAgreement.PrivateKey(
                rawRepresentation: privateKey
            )
        } catch {
            throw AegisError.invalidKey(
                reason: "X25519 private-key bytes could not be deserialised"
            )
        }

        let peer: Curve25519.KeyAgreement.PublicKey
        do {
            peer = try Curve25519.KeyAgreement.PublicKey(
                rawRepresentation: peerPublicKey
            )
        } catch {
            throw AegisError.invalidKey(
                reason: "X25519 peer-public-key bytes could not be deserialised"
            )
        }

        let secret: SharedSecret
        do {
            secret = try priv.sharedSecretFromKeyAgreement(with: peer)
        } catch {
            throw AegisError.underlying(description: "\(error)")
        }

        return secret.withUnsafeBytes { Data($0) }
    }
}

/// A Diffie-Hellman keypair, serialised for storage or
/// transmission. Currently only X25519 produces these; if a
/// second DH algorithm ever lands, this envelope becomes
/// algorithm-tagged.
public struct DHKeyPair: Sendable, Equatable, Codable {

    /// 32-byte X25519 public key. Treat as opaque. Send to
    /// peers who want to compute a shared secret with you.
    public let publicKey: Data

    /// 32-byte X25519 private key. Treat as opaque AND as
    /// secret. Anyone who reads these bytes can derive every
    /// shared secret you can.
    public let privateKey: Data

    public init(publicKey: Data, privateKey: Data) {
        self.publicKey = publicKey
        self.privateKey = privateKey
    }
}
