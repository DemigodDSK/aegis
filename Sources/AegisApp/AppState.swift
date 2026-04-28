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

    // MARK: - Conversation surface (Sprint 8)

    /// All conversations on this device, freshly loaded from
    /// the SQLite store. Refreshed on demand via
    /// `refreshConversations()`. Empty when the database has
    /// not been opened yet (eg before the first screen calls
    /// `setupDatabase()`).
    public private(set) var conversations: [Conversation] = []

    /// Surfaces a non-fatal database error (e.g. the SQLite
    /// file could not be opened). Views can render an error
    /// card when this is non-nil.
    public private(set) var databaseError: String?

    // MARK: - Internals

    private let defaults: UserDefaults
    private let databaseURL: URL?

    private var database: SQLiteDatabase?
    private var sessionStore: RatchetSessionStore?
    private var conversationStoreImpl: ConversationStore?

    /// Public access for screens that drive send / receive
    /// directly. Nil before `setupDatabase()` succeeds.
    public var conversationStore: ConversationStore? { conversationStoreImpl }

    private static let onboardingKey =
        "io.github.demigoddsk.aegis.onboardingCompleted"
    private static let displayNameKey =
        "io.github.demigoddsk.aegis.displayName"

    // MARK: - Init

    /// Build the app state, loading any persisted values from
    /// the injected UserDefaults and AegisStorage.
    ///
    /// - Parameter databaseURL: location of the SQLite file
    ///   the conversation store reads from. Nil uses the
    ///   default per-app Application Support path. Tests
    ///   inject a temp URL.
    public init(
        defaults: UserDefaults = .standard,
        databaseURL: URL? = nil
    ) {
        self.defaults = defaults
        self.databaseURL = databaseURL
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

    // MARK: - Database lifecycle (Sprint 8)

    /// Open the SQLite file, run any pending migrations, and
    /// wire up the session + conversation stores. Idempotent
    /// — calling twice keeps the same handles. Errors are
    /// captured into `databaseError` rather than thrown so a
    /// view in `onAppear` can call this without fearing a
    /// crash.
    public func setupDatabase() {
        guard database == nil else { return }
        do {
            let url = try databaseURL ?? Self.defaultDatabaseURL()
            let db = try SQLiteDatabase(url: url)
            _ = try Migrations.apply(to: db)
            let sessions = RatchetSessionStore(database: db)
            let conversations = ConversationStore(
                database: db, sessionStore: sessions
            )
            self.database = db
            self.sessionStore = sessions
            self.conversationStoreImpl = conversations
            self.databaseError = nil
            try refreshConversations()
        } catch {
            databaseError = "\(error)"
        }
    }

    /// Reload the in-memory `conversations` list from the
    /// SQLite store. Throws only if the store call itself
    /// fails — a fresh, empty database returns an empty list
    /// without throwing.
    public func refreshConversations() throws {
        guard let store = conversationStoreImpl else { return }
        conversations = try store.list()
    }

    /// Default SQLite path: per-app Application Support
    /// directory, file named `aegis.sqlite`. Application
    /// Support is created if missing.
    private static func defaultDatabaseURL() throws -> URL {
        let fm = FileManager.default
        let dir = try fm.url(
            for: .applicationSupportDirectory,
            in: .userDomainMask,
            appropriateFor: nil,
            create: true
        )
        return dir.appendingPathComponent("aegis.sqlite")
    }
}
