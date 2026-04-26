// EncryptionMethod.swift
// Metadata describing a registered encryption algorithm.
//
// `EncryptionMethod` is what users see in the picker UI and what
// gets serialised on the wire ("which algorithm produced this
// ciphertext?"). The struct contains NO key material and NO state
// — it's a description, not an implementation. The implementation
// is a value conforming to the `Encryption` protocol.

import Foundation

/// Describes one encryption algorithm registered with Aegis.
///
/// Two tiers exist (see ALGORITHM-SUBMISSION.md):
///
/// - `tier1Approved`: NIST/IETF-standardised, Council-reviewed,
///   safe to use as the default for real conversations.
/// - `tier2Sandbox`: community-contributed, NOT audited, may
///   contain bugs or design flaws; only usable when the user
///   explicitly types "EXPERIMENTAL" in the UI confirmation.
public struct EncryptionMethod: Codable, Hashable, Sendable, Identifiable {

    /// Stable identifier used on the wire and in logs.
    /// Convention: `"<tier>.<short-name>"` e.g. `"tier1.aes-256-gcm"`.
    public let id: String

    /// Short human-readable name shown in the UI.
    public let displayName: String

    /// One- or two-sentence description shown in the algorithm picker.
    public let description: String

    public let tier: Tier

    /// Optional pointer at the standardising document (NIST FIPS,
    /// IETF RFC, etc.) for Tier 1. Nil for Tier 2.
    public let standardReference: String?

    public enum Tier: String, Codable, Sendable, CaseIterable {
        case tier1Approved = "tier1"
        case tier2Sandbox = "tier2"

        public var isApproved: Bool {
            self == .tier1Approved
        }
    }

    public init(
        id: String,
        displayName: String,
        description: String,
        tier: Tier,
        standardReference: String? = nil
    ) {
        self.id = id
        self.displayName = displayName
        self.description = description
        self.tier = tier
        self.standardReference = standardReference
    }
}
