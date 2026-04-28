// SafetyNumber.swift
// Numeric fingerprint of two identities for out-of-band
// verification.
//
// A safety number is a short, human-readable string that both
// Alice and Bob can compute from their (and the other's)
// identity keys. Comparing the strings out-of-band — over a
// phone call, in person, by reading them aloud — is what
// promotes Aegis from "encryption against passive adversaries"
// to "encryption against active MITM". Without that step, an
// active attacker could substitute keys at first contact and
// neither party would know.
//
// Format:
//   Twelve groups of five decimal digits, separated by single
//   spaces:
//     "12345 67890 12345 67890 12345 67890 12345 67890 12345 67890 12345 67890"
//   60 digits total. Easy to read aloud and easy to compare.
//
// Construction (Signal-format-compatible; the *number* differs
// because Aegis identities differ from Signal's, but the shape
// matches):
//
//   1. Canonically encode each identity: a 1-byte version tag
//      followed by `signing || dh` (1952 + 32 = 1985 bytes
//      after the version byte).
//   2. Sort the two encodings lexicographically so the result
//      is independent of who computed it.
//   3. Iterate SHA-512 over `(domain || A || B)` 5200 times,
//      using the previous output plus the canonical bytes as
//      the next input.
//   4. Take the first 30 bytes of the final hash.
//   5. Convert to 60 decimal digits via six chunks of five
//      bytes each (40-bit big-endian integer mod 10^10 → 10
//      decimal digits per chunk).
//   6. Re-chunk into twelve groups of five digits and join
//      with spaces.
//
// 5200 iterations is the same cost Signal's Numeric
// Fingerprint construction picked: enough work that an
// attacker brute-forcing collisions across many candidate
// identity keys pays meaningfully more, cheap enough that a
// safety-number screen renders without a visible spinner on
// a phone.
//
// We do NOT promise byte-identical output to Signal's
// libsignal — the inputs we hash (ML-DSA-65 + X25519 keys vs
// libsignal's pure Curve25519 IK) cannot match. The format
// matches; the values will not.

import CryptoKit
import Foundation

/// Stateless namespace for safety-number computation and
/// formatting.
public enum SafetyNumber {

    /// Total decimal digits in the formatted output.
    public static let digitCount = 60

    /// Number of digit groups in the formatted output.
    public static let groupCount = 12

    /// Decimal digits per group.
    public static let digitsPerGroup = 5

    /// SHA-512 iterations applied during derivation.
    public static let iterationCount = 5200

    /// Domain-separation prefix mixed into the first hash.
    /// Versioned so a future scheme change is loud.
    private static let domain = Data("AEGIS_SAFETY_v1".utf8)

    /// Canonical-encoding version byte. Distinguishes the
    /// current encoding (signing then dh) from any future
    /// shape (e.g. adding a third key).
    private static let canonicalVersion: UInt8 = 0x01

    /// Compute a safety number for the (local, remote) identity
    /// pair. Order-independent: `compute(local: A, remote: B)`
    /// equals `compute(local: B, remote: A)`.
    public static func compute(
        local: IdentityPublicKey,
        remote: IdentityPublicKey
    ) -> String {
        let localBytes = canonicalEncode(local)
        let remoteBytes = canonicalEncode(remote)

        // Sort so the result doesn't depend on which side
        // computes it.
        let (a, b) = localBytes.lexicographicallyPrecedes(remoteBytes)
            ? (localBytes, remoteBytes)
            : (remoteBytes, localBytes)

        // Iterated SHA-512.
        var h = sha512(domain + a + b)
        for _ in 1..<iterationCount {
            h = sha512(h + a + b)
        }
        let firstThirty = Array(h.prefix(30))

        // Six 5-byte chunks → six 10-digit decimal numbers.
        // `%llu` is the unsigned-long-long format specifier;
        // a plain `%d` would truncate to a 32-bit int and
        // wrap around for large values.
        var digits = ""
        for i in 0..<6 {
            var value: UInt64 = 0
            for j in 0..<5 {
                value = (value << 8) | UInt64(firstThirty[i * 5 + j])
            }
            digits += String(format: "%010llu", value % 10_000_000_000)
        }

        // Re-group into twelve 5-digit blocks separated by
        // single spaces.
        var groups: [String] = []
        groups.reserveCapacity(groupCount)
        for g in 0..<groupCount {
            let start = digits.index(digits.startIndex, offsetBy: g * digitsPerGroup)
            let end = digits.index(start, offsetBy: digitsPerGroup)
            groups.append(String(digits[start..<end]))
        }
        return groups.joined(separator: " ")
    }

    // MARK: - Internals

    private static func canonicalEncode(_ id: IdentityPublicKey) -> Data {
        var out = Data()
        out.reserveCapacity(1 + id.signing.count + id.dh.count)
        out.append(canonicalVersion)
        out.append(id.signing)
        out.append(id.dh)
        return out
    }

    private static func sha512(_ data: Data) -> Data {
        Data(SHA512.hash(data: data))
    }
}
