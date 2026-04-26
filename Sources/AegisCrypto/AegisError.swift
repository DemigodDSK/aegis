// AegisError.swift
// Aegis cryptographic core — error taxonomy.
//
// One error type, exhaustively cased. Callers can pattern-match
// instead of stringly-comparing. All cases include a human-readable
// reason where useful for debugging; we deliberately do NOT include
// any user-controlled data in `reason` strings — these can appear in
// logs and we don't want to leak plaintext or key material.

import Foundation

/// Every cryptographic operation in Aegis returns either a value or
/// an `AegisError`. We use a single error type per the
/// "small surface, exhaustive cases" principle so callers don't have
/// to bridge across error hierarchies.
public enum AegisError: Error, Equatable, Sendable {
    /// Key material is the wrong size, wrong format, or otherwise
    /// not usable with the requested algorithm.
    case invalidKey(reason: String)

    /// Nonce / IV is malformed or wrong length for the algorithm.
    case invalidNonce(reason: String)

    /// Ciphertext bytes failed structural validation before any
    /// decryption attempt (wrong tag length, payload truncated, etc.)
    case ciphertextCorrupted

    /// Decryption was attempted but the authentication tag did not
    /// verify. The plaintext is *not* returned; treat the message
    /// as forged or tampered.
    case authenticationFailed

    /// The payload claims a methodId we don't have a registered
    /// implementation for, or the algorithm is registered in a tier
    /// the caller is not allowed to use.
    case unsupportedMethod(id: String)

    /// An algorithm with this id was registered twice.
    case methodAlreadyRegistered(id: String)

    /// Underlying CryptoKit error that doesn't fit any other case.
    /// We store the type/description rather than the raw error to
    /// keep `AegisError` `Sendable` and `Equatable`.
    case underlying(description: String)
}

extension AegisError: LocalizedError {
    public var errorDescription: String? {
        switch self {
        case .invalidKey(let reason):
            return "Aegis: invalid key — \(reason)"
        case .invalidNonce(let reason):
            return "Aegis: invalid nonce — \(reason)"
        case .ciphertextCorrupted:
            return "Aegis: ciphertext is corrupted or truncated"
        case .authenticationFailed:
            return "Aegis: authentication tag verification failed; message may be forged or tampered"
        case .unsupportedMethod(let id):
            return "Aegis: no registered implementation for method id '\(id)'"
        case .methodAlreadyRegistered(let id):
            return "Aegis: a method with id '\(id)' is already registered"
        case .underlying(let description):
            return "Aegis: \(description)"
        }
    }
}
