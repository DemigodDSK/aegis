// MLDSA65.swift
// Tier 1 algorithm: ML-DSA-65 post-quantum digital signatures.
//
// ML-DSA (formerly CRYSTALS-Dilithium) is a lattice-based
// post-quantum digital-signature scheme standardised in NIST
// FIPS 204. ML-DSA-65 is the Category 3 parameter set,
// targeting roughly the same security strength as AES-192
// against both classical and quantum attackers.
//
// References:
//   - NIST FIPS 204 (ML-DSA)
//   - https://csrc.nist.gov/pubs/fips/204/final
//
// Implementation notes:
//   - We wrap Apple's `CryptoKit.MLDSA65` directly. That type
//     ships with macOS 26 / iOS 26 (the same SDK floor the
//     rest of AegisCrypto's PQ surface targets). No Aegis-side
//     cryptographic logic is added.
//   - We name our wrapper `MLDSA65Signature` rather than
//     `MLDSA65` to avoid shadowing CryptoKit's type at the
//     module surface. Callers writing `MLDSA65` against `import
//     CryptoKit` continue to mean Apple's primitive; callers
//     of Aegis use the `Signature` protocol or
//     `MLDSA65Signature` directly.
//   - `seedRepresentation` is what we serialise as the private
//     key: it is the smallest-possible storage form (Apple
//     regenerates the full key from the seed on demand).
//   - Signing in ML-DSA is hedged with internal randomness; two
//     calls to `sign(_:with:)` for the same `(privateKey,
//     message)` typically yield different signature bytes, both
//     of which verify. This matches the FIPS 204 default
//     "hedged signing" mode.
//   - The "context" extension defined by FIPS 204 (an optional
//     domain-separator string carried alongside the message) is
//     not yet exposed through our `Signature` protocol. Sprint
//     4 (PQXDH) may surface it once we have a concrete need;
//     for now both signing and verification use the empty
//     context, which is the spec's default.

import CryptoKit
import Foundation

/// ML-DSA-65 post-quantum digital signature.
///
/// Tier 1 algorithm. Quantum-secure under the standard
/// lattice-cryptography assumptions of FIPS 204. Public-key
/// size ~1.95 KB, signature size ~3.3 KB — meaningfully larger
/// than classical Ed25519 (~32 B / ~64 B), but the trade-off
/// for post-quantum security.
public struct MLDSA65Signature: Signature {

    public static let methodId = "tier1.ml-dsa-65"

    public static let methodMetadata = EncryptionMethod(
        id: MLDSA65Signature.methodId,
        displayName: "ML-DSA-65",
        description: "Post-quantum digital signature based on "
            + "lattice cryptography (CRYSTALS-Dilithium). "
            + "Standardised in NIST FIPS 204.",
        tier: .tier1Approved,
        standardReference: "NIST FIPS 204"
    )

    public var method: EncryptionMethod { Self.methodMetadata }

    public init() {}

    // MARK: - Key generation

    public func generateKeyPair() throws -> SignatureKeyPair {
        let priv: CryptoKit.MLDSA65.PrivateKey
        do {
            priv = try CryptoKit.MLDSA65.PrivateKey()
        } catch {
            throw AegisError.underlying(description: "\(error)")
        }
        return SignatureKeyPair(
            publicKey: priv.publicKey.rawRepresentation,
            privateKey: priv.seedRepresentation
        )
    }

    // MARK: - Sign

    public func sign(_ message: Data, with privateKey: Data) throws -> Data {
        let priv: CryptoKit.MLDSA65.PrivateKey
        do {
            priv = try CryptoKit.MLDSA65.PrivateKey(
                seedRepresentation: privateKey,
                publicKey: nil
            )
        } catch {
            throw AegisError.invalidKey(
                reason: "ML-DSA-65 private-key seed could not be deserialised"
            )
        }

        do {
            return try priv.signature(for: message)
        } catch {
            throw AegisError.underlying(description: "\(error)")
        }
    }

    // MARK: - Verify

    public func isValidSignature(
        _ signature: Data,
        of message: Data,
        by publicKey: Data
    ) throws -> Bool {
        let pk: CryptoKit.MLDSA65.PublicKey
        do {
            pk = try CryptoKit.MLDSA65.PublicKey(rawRepresentation: publicKey)
        } catch {
            throw AegisError.invalidKey(
                reason: "ML-DSA-65 public-key bytes could not be deserialised"
            )
        }

        // Apple's API returns Bool with no throwing path on a
        // well-formed key. A `false` here means the signature
        // does not validate for this (message, key) — i.e. a
        // forgery, a wrong-key combination, or corruption.
        return pk.isValidSignature(signature, for: message)
    }
}
