// AppState.swift
// Single source of truth for the AegisApp UI's view-model
// state. SwiftUI views observe it, screens push state
// transitions through it, and the persistence boundary
// (Keychain via AegisStorage, UserDefaults for non-sensitive
// flags) lives behind a small set of methods.
//
// Why @Observable + @MainActor: SwiftUI binds to @Observable
// types automatically and re-renders on property mutations.
// AppState mutations come from user actions in the UI thread,
// so pinning it to @MainActor keeps Swift 6 strict-concurrency
// happy without scattering `await`s through every view.

import AegisCrypto
import AegisStorage
import Foundation
import Observation

/// View-model state shared across every Aegis screen.
@Observable
@MainActor
public final class AppState {

    // MARK: - Persisted flags

    /// True once the user has tapped through the 3-screen
    /// mandatory honesty onboarding (THREAT-MODEL.md
    /// "In-app honesty"). Persisted in the injected
    /// UserDefaults instance.
    public private(set) var onboardingCompleted: Bool

    /// The local identity, if one has been generated and
    /// saved. Nil on a fresh install or after a reset.
    /// Backed by AegisStorage / Keychain.
    public private(set) var identity: IdentityKeyPair?

    /// User-chosen display name. Optional — the demo flow
    /// doesn't strictly require one. Persisted in
    /// UserDefaults (non-sensitive).
    public private(set) var displayName: String?

    // MARK: - Internals

    private let defaults: UserDefaults

    private static let onboardingKey =
        "io.github.demigoddsk.aegis.onboardingCompleted"
    private static let displayNameKey =
        "io.github.demigoddsk.aegis.displayName"

    // MARK: - Init

    /// Build the app state, loading any persisted values from
    /// the injected UserDefaults and AegisStorage.
    public init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        self.onboardingCompleted = defaults.bool(forKey: Self.onboardingKey)
        self.displayName = defaults.string(forKey: Self.displayNameKey)
        self.identity = (try? AegisStorage.loadIdentity()).flatMap { $0 }
    }

    // MARK: - Mutations

    /// Mark the mandatory onboarding flow complete. Called
    /// from the third onboarding screen after the user has
    /// seen the "use Signal instead" disclosure.
    public func markOnboardingComplete() {
        onboardingCompleted = true
        defaults.set(true, forKey: Self.onboardingKey)
    }

    /// Generate a fresh identity, save it to the Keychain,
    /// and update in-memory state.
    @discardableResult
    public func generateAndSaveIdentity() throws -> IdentityKeyPair {
        let fresh = try IdentityKeyPair.generate()
        try AegisStorage.saveIdentity(fresh)
        identity = fresh
        return fresh
    }

    /// Update the local display name (non-sensitive
    /// metadata). Pass nil to clear.
    public func setDisplayName(_ name: String?) {
        let trimmed = name?.trimmingCharacters(in: .whitespacesAndNewlines)
        if let trimmed = trimmed, !trimmed.isEmpty {
            displayName = trimmed
            defaults.set(trimmed, forKey: Self.displayNameKey)
        } else {
            displayName = nil
            defaults.removeObject(forKey: Self.displayNameKey)
        }
    }

    /// Reset everything — clear the identity (and its
    /// Keychain entry), drop the display name, and rewind to
    /// the pre-onboarding state. Wired to a developer-only
    /// affordance for now; user-facing "delete account" is a
    /// later sprint when there's networking to leave.
    public func resetEverything() {
        try? AegisStorage.deleteIdentity()
        defaults.removeObject(forKey: Self.onboardingKey)
        defaults.removeObject(forKey: Self.displayNameKey)
        identity = nil
        displayName = nil
        onboardingCompleted = false
    }
}
