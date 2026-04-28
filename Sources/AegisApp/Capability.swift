// Capability.swift
// User-facing capability table — what Aegis claims to do
// today, what's planned, and what's out of scope.
//
// THIS FILE IS THE CODE-SIDE MIRROR of the version-by-version
// capability table in THREAT-MODEL.md §"Cryptographic
// guarantees by version". Keep them in sync. THREAT-MODEL.md
// is the source of truth for *what we promise users*; this
// file is what the in-app Settings → Security screen actually
// shows. Per working principle 6 ("don't promise more than
// you ship"), if a capability appears here as `.shipped` it
// MUST be backed by code that runs.
//
// Settings → Security renders this list verbatim. A row tap
// opens an inline disclosure with the capability's `detail`.
// Future polish: code-gen the markdown table from this list
// (or vice-versa) so the two cannot drift. Tracked as a
// post-Sprint-6 polish item.

import Foundation

/// One row in the Settings → Security capability table.
public struct Capability: Sendable, Identifiable, Equatable {

    /// Stable identifier for routing / persistence. Format:
    /// `"<area>.<algorithm-or-feature>"`.
    public let id: String

    /// Short, user-facing title — what the row says.
    public let title: String

    /// One- or two-sentence explainer. Shown when the row is
    /// expanded; designed to be honest about scope, not
    /// marketing copy.
    public let detail: String

    public let status: Status

    public init(
        id: String,
        title: String,
        detail: String,
        status: Status
    ) {
        self.id = id
        self.title = title
        self.detail = detail
        self.status = status
    }

    /// Lifecycle state for a capability. Drives the indicator
    /// glyph and the disclosure copy in the Settings UI.
    public enum Status: Sendable, Equatable {

        /// Implemented and exercised by tests in the current
        /// version.
        case shipped

        /// Planned for a future version. The associated
        /// string names the target ("v0.0.8 / Sprint 7",
        /// "v2.0", etc.) so the UI can show "coming in X".
        case plannedFor(String)

        /// Implemented but with a documented limitation. The
        /// `note` is shown to the user verbatim.
        case partial(note: String)

        /// Out of scope for Aegis. Used for things like
        /// "Voice / video E2EE" that we explicitly do not
        /// promise. Empty string is fine.
        case outOfScope(reason: String)
    }

    /// All capability rows shown by Settings → Security at
    /// v0.0.7. Order is the order they appear on screen —
    /// keep most-relevant-now items at the top.
    public static let all: [Capability] = [

        // --- Tier 1 cryptography -------------------------------

        Capability(
            id: "aead.aes-256-gcm",
            title: "AES-256-GCM authenticated encryption",
            detail: "Per-message AEAD primitive, hardware-accelerated on Apple silicon, NIST FIPS 197 + SP 800-38D. 70 KAT vectors (NIST CAVP + BoringSSL) verify byte-exact agreement with the standard.",
            status: .shipped
        ),

        Capability(
            id: "kem.x-wing",
            title: "Post-quantum key encapsulation (X-Wing / ML-KEM-768 + X25519)",
            detail: "Hybrid KEM combining NIST FIPS 203 ML-KEM-768 with X25519. Used for end-to-end-message KEM bootstrap. Apple's CryptoKit XWingMLKEM768X25519 primitive — no Aegis-side cryptographic logic.",
            status: .shipped
        ),

        Capability(
            id: "kem.ml-kem-1024",
            title: "Post-quantum key encapsulation (ML-KEM-1024, bare)",
            detail: "NIST FIPS 203 Category 5 KEM, used inside PQXDH. 25 NIST KAT vectors verify the underlying primitive against the standard.",
            status: .shipped
        ),

        Capability(
            id: "sig.ml-dsa-65",
            title: "Post-quantum digital signatures (ML-DSA-65)",
            detail: "NIST FIPS 204 Category 3 signature scheme. Used for identity keys and prekey-bundle signing. 25 NIST KeyGen + 160 Wycheproof verify-side KAT vectors verify against the standard.",
            status: .shipped
        ),

        // --- Identity + session establishment ------------------

        Capability(
            id: "identity.local",
            title: "Local post-quantum identity",
            detail: "Per-user (ML-DSA-65 signing, X25519 DH) keypair generated on-device, never sent to a server. Stored in the iOS Keychain, kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly, never iCloud-synced.",
            status: .shipped
        ),

        Capability(
            id: "session.pqxdh",
            title: "PQXDH key exchange",
            detail: "Post-quantum extended Diffie-Hellman handshake between two identities, modeled on Signal's PQXDH spec. Establishes the seed that the Double Ratchet builds on.",
            status: .shipped
        ),

        Capability(
            id: "session.safety-number",
            title: "Safety-number verification (Signal-format)",
            detail: "Twelve groups of five digits, derived from both parties' identity keys. Read aloud out-of-band to detect MITM. Format-compatible with Signal's; the *number* differs because Aegis identities differ.",
            status: .shipped
        ),

        Capability(
            id: "session.forward-secrecy",
            title: "Forward secrecy (Double Ratchet)",
            detail: "Compromising one message key does not compromise past or future messages. Out-of-order arrivals decrypt cleanly via a bounded skipped-keys cache (1000-entry LRU).",
            status: .shipped
        ),

        // --- Persistence / app surface --------------------------

        Capability(
            id: "storage.keychain-identity",
            title: "Keychain identity persistence",
            detail: "Identity keypair survives app restarts via AegisStorage. Access policy is post-first-unlock, this-device-only, never iCloud-synced.",
            status: .shipped
        ),

        Capability(
            id: "app.shell",
            title: "iOS app shell (this surface)",
            detail: "SwiftUI on iOS / macOS. Sprint 7 wraps this in an Xcode project for TestFlight distribution.",
            status: .shipped
        ),

        // --- Planned ---------------------------------------------

        Capability(
            id: "transport.network",
            title: "Network transport between devices",
            detail: "No transport layer ships in v0.0.7 — every encrypt/decrypt round-trip stays on this device. Networking arrives in Sprint 8 (v0.0.9).",
            status: .plannedFor("v0.0.9 / Sprint 8")
        ),

        Capability(
            id: "transport.testflight",
            title: "TestFlight build",
            detail: "First version a real user can install on a phone is Sprint 9 (v0.1.0).",
            status: .plannedFor("v0.1.0 / Sprint 9")
        ),

        Capability(
            id: "audit.external",
            title: "External security audit",
            detail: "First independent security audit is gated on v1.0. Until then Aegis is library-and-demo only — do not use it for life-or-liberty situations.",
            status: .plannedFor("v1.0")
        ),

        Capability(
            id: "metadata.sealed-sender",
            title: "Sealed-sender / metadata protection",
            detail: "At v0.x our future server still sees WHO you talk to and WHEN. Sealed-sender-style metadata protection is a v2.0 commitment.",
            status: .plannedFor("v2.0")
        ),

        // --- Out of scope ---------------------------------------

        Capability(
            id: "voice-video.e2ee",
            title: "Voice / video calls with E2EE",
            detail: "Out of scope for Aegis at every version. We focus on text messaging.",
            status: .outOfScope(reason: "Out of scope at every version.")
        ),
    ]
}
