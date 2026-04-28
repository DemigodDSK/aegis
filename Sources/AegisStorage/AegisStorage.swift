// AegisStorage.swift
// Keychain-backed persistence for sensitive Aegis material.
//
// This module is the canonical home for the Keychain reads,
// writes, and access-control choices Aegis makes. The crypto
// primitives in AegisCrypto have no awareness of persistence
// — they take and return Sendable / Codable values; the rules
// for *where* those values live, *who* can read them, and
// *what* happens at first-unlock all live here.
//
// Default policies (Sprint 6 settled choices):
//
//   - Access control: kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly
//     The Signal-aligned default — items are decryptable
//     after the device is first unlocked following a reboot,
//     and never sync to iCloud. Pick a stricter or relaxed
//     setting via `defaultAccessibility` before the first
//     save call.
//
//   - Biometric protection: off by default. Opt in via the
//     accessibility argument on individual save calls if you
//     want a Face/Touch-ID prompt on each access. Adding
//     biometrics to the default would land us with a UX cost
//     before users have asked for it.
//
//   - iCloud Keychain sync: never. We never set
//     kSecAttrSynchronizable to true. Private keys must not
//     leave the device — full stop, regardless of user
//     opt-in.
//
// Test posture: tests should override `serviceIdentifier`
// before any save/load to a unique per-test value, and call
// `deleteIdentity()` (or `purgeAll(serviceIdentifier:)`) in
// tearDown. The CI runner's login keychain is unlocked, so
// reads/writes work in `swift test` without extra setup.

import AegisCrypto
import Foundation
import Security

/// Stateless namespace for Keychain-backed Aegis persistence.
///
/// All operations are synchronous and throw on Keychain
/// failure (mapped to `KeychainStorageError`). The API is
/// deliberately small for Sprint 6: only the long-term
/// `IdentityKeyPair` is persisted. Per-peer ratchet sessions
/// and Bob-side prekey-bundle secrets are scope for later
/// sprints (Sprint 7+).
public enum AegisStorage {

    /// Keychain `kSecAttrService` value. Override before
    /// first call to namespace per app installation, per
    /// test class, etc.
    ///
    /// `nonisolated(unsafe)` because the value is a
    /// configuration knob that callers are expected to set
    /// once at app startup (or per-test in setUp) and not
    /// race-mutate from concurrent contexts. Swift 6's strict
    /// concurrency check would otherwise reject this static
    /// var.
    public nonisolated(unsafe) static var serviceIdentifier: String =
        "io.github.demigoddsk.aegis"

    /// Default access-control policy applied to all writes
    /// that don't pass an explicit accessibility. See file
    /// header. Same `nonisolated(unsafe)` rationale as
    /// `serviceIdentifier`.
    public nonisolated(unsafe) static var defaultAccessibility: KeychainAccessibility =
        .afterFirstUnlockThisDeviceOnly

    /// Per-account Keychain key for the sole local identity.
    /// Versioned (`-v1`) so a future format change is loud.
    private static let identityAccount = "identity-keypair-v1"

    // MARK: - Identity

    /// Persist `identity` to the Keychain, replacing any
    /// existing identity item under the same service.
    public static func saveIdentity(
        _ identity: IdentityKeyPair,
        accessibility: KeychainAccessibility? = nil
    ) throws {
        let data = try JSONEncoder().encode(identity)
        try Keychain.set(
            data: data,
            service: serviceIdentifier,
            account: identityAccount,
            accessibility: accessibility ?? defaultAccessibility
        )
    }

    /// Load the locally-stored identity. Returns nil when no
    /// identity has been saved yet (clean install).
    public static func loadIdentity() throws -> IdentityKeyPair? {
        guard let data = try Keychain.get(
            service: serviceIdentifier,
            account: identityAccount
        ) else { return nil }
        return try JSONDecoder().decode(IdentityKeyPair.self, from: data)
    }

    /// Delete the locally-stored identity, if any. No-op when
    /// nothing is stored. Use this when rotating identities or
    /// implementing "delete account" — for now there is no UI
    /// path that calls this.
    public static func deleteIdentity() throws {
        try Keychain.delete(
            service: serviceIdentifier,
            account: identityAccount
        )
    }

    // MARK: - Bulk ops (test-only)

    /// Delete every Aegis-namespaced item under
    /// `serviceIdentifier`. Intended for test cleanup;
    /// production code should not call this.
    public static func purgeAll(
        serviceIdentifier service: String
    ) throws {
        try Keychain.deleteAll(service: service)
    }
}
