// HybridKEM.swift
// Tier 1 algorithm: X-Wing (ML-KEM-768 + X25519 hybrid KEM).
//
// X-Wing is an IETF-track post-quantum hybrid key-encapsulation
// mechanism that combines NIST FIPS 203 ML-KEM-768 with X25519
// Diffie-Hellman in a way that yields a single PRF-secure shared
// secret. It is "hybrid" in the sense that the construction is
// secure as long as *either* component is secure — so a future
// break of ML-KEM does not by itself break sessions, and a future
// quantum attack on X25519 does not by itself break sessions.
//
// References:
//   - draft-connolly-cfrg-xwing-kem (IETF)
//   - "X-Wing: The Hybrid KEM You've Been Looking For",
//     Bernstein, Connolly, Schwabe, Westerbaan, Wiggers, 2024
//   - NIST FIPS 203 (ML-KEM)
//   - RFC 7748 (X25519)
//
// Implementation notes:
//   - We wrap Apple's `CryptoKit.XWingMLKEM768X25519` directly.
//     That type implements the full hybrid construction; we add no
//     cryptographic logic of our own. See docs/STAGES.md v0.0.3
//     "Conscious deviation" for why we chose Apple's X-Wing over a
//     hand-rolled concat+HKDF combiner.
//   - `seedRepresentation` is what we serialise as the private
//     key: it is the smallest-possible storage form (Apple
//     regenerates the full key from the seed on demand). For
//     higher-integrity storage that catches bit rot, use Apple's
//     `integrityCheckedRepresentation` API directly — we surface
//     a dedicated helper for that in a follow-up sprint when we
//     wire up Keychain / Secure Enclave persistence.
//   - The ciphertext format is whatever `XWingMLKEM768X25519`
//     produces (per the X-Wing draft); we treat it as opaque
//     bytes and pass it round verbatim.

import CryptoKit
import Foundation

/// X-Wing hybrid KEM (ML-KEM-768 ⊕ X25519).
///
/// Tier 1 algorithm. The construction is post-quantum-secure
/// because of the ML-KEM-768 component and provides classical
/// security via the X25519 component. An attacker must break
/// BOTH primitives to recover the shared secret.
public struct HybridKEM: KeyEncapsulation {

    public static let methodId = "tier1.xwing-mlkem768-x25519"

    public static let methodMetadata = EncryptionMethod(
        id: HybridKEM.methodId,
        displayName: "X-Wing (ML-KEM-768 + X25519)",
        description: "Post-quantum key encapsulation hybridising NIST "
            + "FIPS 203 ML-KEM-768 with X25519 Diffie-Hellman. Secure "
            + "as long as either component remains secure.",
        tier: .tier1Approved,
        standardReference:
            "IETF draft-connolly-cfrg-xwing-kem; NIST FIPS 203; RFC 7748"
    )

    public var method: EncryptionMethod { Self.methodMetadata }

    public init() {}

    // MARK: - Key generation

    public func generateKeyPair() throws -> KEMKeyPair {
        let priv: XWingMLKEM768X25519.PrivateKey
        do {
            priv = try XWingMLKEM768X25519.PrivateKey.generate()
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
        let pk: XWingMLKEM768X25519.PublicKey
        do {
            pk = try XWingMLKEM768X25519.PublicKey(rawRepresentation: publicKey)
        } catch {
            throw AegisError.invalidKey(
                reason: "X-Wing public-key bytes could not be deserialised"
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
        let dk: XWingMLKEM768X25519.PrivateKey
        do {
            dk = try XWingMLKEM768X25519.PrivateKey(
                seedRepresentation: privateKey,
                publicKey: nil
            )
        } catch {
            throw AegisError.invalidKey(
                reason: "X-Wing private-key seed could not be deserialised"
            )
        }

        do {
            return try dk.decapsulate(ciphertext)
        } catch {
            // X-Wing per FIPS 203 uses implicit rejection: a
            // wrong-but-well-formed ciphertext returns a different
            // shared secret without throwing. A throw here means
            // the bytes are structurally malformed (truncated,
            // wrong length, etc.).
            throw AegisError.ciphertextCorrupted
        }
    }
}
