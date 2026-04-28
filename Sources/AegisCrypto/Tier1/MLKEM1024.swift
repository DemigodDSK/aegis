// MLKEM1024.swift
// Tier 1 algorithm: ML-KEM-1024 (NIST FIPS 203 Category 5).
//
// ML-KEM-1024 is the highest-security parameter set of the
// NIST post-quantum KEM standard, targeting roughly the same
// security strength as AES-256 against both classical and
// quantum attackers. It is what Signal's PQXDH specification
// uses (under its old name "Kyber1024") for the post-quantum
// component of their key-exchange handshake.
//
// References:
//   - NIST FIPS 203 (ML-KEM)
//   - https://csrc.nist.gov/pubs/fips/203/final
//   - Signal's PQXDH specification:
//     https://signal.org/docs/specifications/pqxdh/
//
// When to use this vs HybridKEM:
//   - For end-to-end *message* encryption / KEM-then-AEAD
//     bootstrap, use `HybridKEM` (X-Wing). It is hybridised
//     against both classical and quantum attackers and ships
//     the natural full-message envelope semantics.
//   - For *protocol-internal* PQ key agreement that runs
//     alongside a separate ECDH chain (e.g. PQXDH, where
//     X25519 DH operations supply the classical hybridisation
//     externally), use `MLKEM1024KEM`. Layering a hybrid KEM
//     inside a hybrid handshake would double up the X25519
//     operations needlessly.
//
// Implementation notes:
//   - We wrap Apple's `CryptoKit.MLKEM1024` directly.
//     No Aegis-side cryptographic logic is added.
//   - We name the type `MLKEM1024KEM` rather than `MLKEM1024`
//     to avoid shadowing CryptoKit's primitive at the module
//     surface, matching the rationale in MLDSA65.swift.
//   - The private-key wire form is `seedRepresentation`
//     (64 B FIPS 203 d||z; smallest serialised form).
//   - Decapsulation uses FIPS 203's implicit-rejection rule:
//     a wrong-but-well-formed ciphertext returns a different
//     shared secret without throwing. Detection is the outer
//     AEAD's job. Structural malformity (truncated / wrong
//     length) does throw, surfaced as
//     `AegisError.ciphertextCorrupted`.

import CryptoKit
import Foundation

/// ML-KEM-1024 post-quantum key encapsulation, bare (no
/// classical hybridisation).
///
/// Tier 1 algorithm. NIST FIPS 203 Category 5 — the highest
/// security parameter set in the standard. Public-key size
/// 1568 B, ciphertext size 1568 B, shared-secret size 32 B.
public struct MLKEM1024KEM: KeyEncapsulation {

    public static let methodId = "tier1.ml-kem-1024"

    public static let methodMetadata = EncryptionMethod(
        id: MLKEM1024KEM.methodId,
        displayName: "ML-KEM-1024",
        description: "Post-quantum key encapsulation based on "
            + "lattice cryptography (CRYSTALS-Kyber). "
            + "Standardised in NIST FIPS 203 Category 5. "
            + "Bare (non-hybrid) variant; intended for "
            + "protocol-internal use alongside ECDH (e.g. PQXDH).",
        tier: .tier1Approved,
        standardReference: "NIST FIPS 203"
    )

    public var method: EncryptionMethod { Self.methodMetadata }

    /// FIPS 203 byte sizes for ML-KEM-1024. Pinned here so we
    /// can pre-validate inputs before handing them to Apple's
    /// CryptoKit primitives — the underlying API contains a
    /// `try!` path that traps (rather than throws) on certain
    /// malformed seed lengths, so structural validation must
    /// happen at the wrapper boundary. Same defensive pattern
    /// as AES-GCM nonce/tag length checks (see issue #1
    /// family). Also captured by `MLKEM1024SmokeTests`.
    public static let publicKeyByteCount = 1568
    public static let ciphertextByteCount = 1568
    public static let seedByteCount = 64

    public init() {}

    // MARK: - Key generation

    public func generateKeyPair() throws -> KEMKeyPair {
        let priv: CryptoKit.MLKEM1024.PrivateKey
        do {
            priv = try CryptoKit.MLKEM1024.PrivateKey()
        } catch {
            throw AegisError.underlying(description: "\(error)")
        }
        return KEMKeyPair(
            publicKey: priv.publicKey.rawRepresentation,
            privateKey: priv.seedRepresentation
        )
    }

    // MARK: - Encapsulate

    public func encapsulate(toPublicKey publicKey: Data) throws -> KEMEncapsulation {
        guard publicKey.count == Self.publicKeyByteCount else {
            throw AegisError.invalidKey(
                reason: "ML-KEM-1024 public key must be \(Self.publicKeyByteCount) bytes; got \(publicKey.count)"
            )
        }

        let pk: CryptoKit.MLKEM1024.PublicKey
        do {
            pk = try CryptoKit.MLKEM1024.PublicKey(rawRepresentation: publicKey)
        } catch {
            throw AegisError.invalidKey(
                reason: "ML-KEM-1024 public-key bytes could not be deserialised"
            )
        }

        let result: KEM.EncapsulationResult
        do {
            result = try pk.encapsulate()
        } catch {
            throw AegisError.underlying(description: "\(error)")
        }

        return KEMEncapsulation(
            ciphertext: result.encapsulated,
            sharedSecret: result.sharedSecret
        )
    }

    // MARK: - Decapsulate

    public func decapsulate(
        _ ciphertext: Data,
        with privateKey: Data
    ) throws -> SymmetricKey {
        guard privateKey.count == Self.seedByteCount else {
            throw AegisError.invalidKey(
                reason: "ML-KEM-1024 private-key seed must be \(Self.seedByteCount) bytes; got \(privateKey.count)"
            )
        }
        guard ciphertext.count == Self.ciphertextByteCount else {
            throw AegisError.ciphertextCorrupted
        }

        let dk: CryptoKit.MLKEM1024.PrivateKey
        do {
            dk = try CryptoKit.MLKEM1024.PrivateKey(
                seedRepresentation: privateKey,
                publicKey: nil
            )
        } catch {
            throw AegisError.invalidKey(
                reason: "ML-KEM-1024 private-key seed could not be deserialised"
            )
        }

        do {
            return try dk.decapsulate(ciphertext)
        } catch {
            // FIPS 203 implicit rejection: a wrong-but-well-
            // formed ciphertext returns a different shared
            // secret without throwing. A throw here means the
            // bytes are structurally malformed despite passing
            // the length pre-check above (e.g. unexpected
            // CryptoKit-internal validation failure).
            throw AegisError.ciphertextCorrupted
        }
    }
}
