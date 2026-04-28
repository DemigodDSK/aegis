// RatchetSessionStore.swift
// SQLite-backed persistence for Double Ratchet session state.
//
// Each conversation has at most one ratchet session — the
// (peer-bound) state that encrypt/decrypt advance on every
// message. The store binds sessions to conversations by
// `conversation_id`; deleting the conversation cascades the
// session away (FK ON DELETE CASCADE in schema v2).
//
// On-disk format: the session is JSON-encoded via Swift
// Codable (RatchetSession is Codable as of this commit) and
// stored as a BLOB. Per Sprint 8 settled choice 2, no second
// Keychain-backed encryption layer wraps it — the chain keys
// themselves are the high-value secret here, and a second
// AEAD layer would only protect against on-disk theft of the
// device's keystore (a class of attack we already accept the
// loss against; if your device is unlocked, AEAD-on-AEAD does
// not help).
//
// Threading: this store is NOT Sendable. Hold one per actor /
// MainActor; do not share across concurrency domains.

import AegisCrypto
import Foundation

/// Errors specific to the ratchet-session store.
public enum RatchetSessionStoreError: Error, Equatable {
    /// The session blob in the row could not be JSON-decoded.
    case decodeFailed(reason: String)
    /// JSON-encoding the session blob failed.
    case encodeFailed(reason: String)
}

/// SQLite-backed `RatchetSession` persistence.
public final class RatchetSessionStore {

    private let db: SQLiteDatabase
    private let now: @Sendable () -> Int64

    /// Bind to an open SQLite connection. The store assumes
    /// schema v2 (or later) has already been applied; callers
    /// should run `Migrations.apply(to: db)` once at app
    /// startup before constructing any stores.
    ///
    /// - Parameter now: clock used for `updated_at` writes.
    ///   Callers can substitute a fixed clock for tests.
    public init(
        database: SQLiteDatabase,
        now: @escaping @Sendable () -> Int64 = RatchetSessionStore.defaultClock
    ) {
        self.db = database
        self.now = now
    }

    /// Default clock: seconds since Unix epoch.
    public static let defaultClock: @Sendable () -> Int64 = {
        Int64(Date().timeIntervalSince1970)
    }

    // MARK: - CRUD

    /// Save (or replace) the ratchet session for a conversation.
    public func save(
        _ session: RatchetSession,
        forConversation conversationId: Data
    ) throws {
        let blob: Data
        do {
            blob = try Self.encoder.encode(session)
        } catch {
            throw RatchetSessionStoreError.encodeFailed(reason: "\(error)")
        }

        let stmt = try db.prepare("""
            INSERT INTO ratchet_sessions (conversation_id, state, updated_at)
            VALUES (?, ?, ?)
            ON CONFLICT(conversation_id) DO UPDATE SET
                state = excluded.state,
                updated_at = excluded.updated_at;
            """)
        defer { stmt.finalize() }
        try stmt.bind(conversationId, at: 1)
        try stmt.bind(blob, at: 2)
        try stmt.bind(now(), at: 3)
        _ = try stmt.step()
    }

    /// Load the ratchet session for a conversation, or nil if
    /// none has been saved.
    public func load(
        forConversation conversationId: Data
    ) throws -> RatchetSession? {
        let stmt = try db.prepare(
            "SELECT state FROM ratchet_sessions WHERE conversation_id = ?;"
        )
        defer { stmt.finalize() }
        try stmt.bind(conversationId, at: 1)
        guard try stmt.step() else { return nil }
        guard let blob = stmt.data(at: 0) else { return nil }
        do {
            return try Self.decoder.decode(RatchetSession.self, from: blob)
        } catch {
            throw RatchetSessionStoreError.decodeFailed(reason: "\(error)")
        }
    }

    /// Delete the ratchet session for a conversation. No-op if
    /// none is stored.
    public func delete(
        forConversation conversationId: Data
    ) throws {
        let stmt = try db.prepare(
            "DELETE FROM ratchet_sessions WHERE conversation_id = ?;"
        )
        defer { stmt.finalize() }
        try stmt.bind(conversationId, at: 1)
        _ = try stmt.step()
    }

    // MARK: - Codecs

    private static let encoder: JSONEncoder = {
        let e = JSONEncoder()
        // Stable property ordering so two encodes of the same
        // session produce byte-identical output. Useful for
        // diffing in tests; not a security property.
        e.outputFormatting = [.sortedKeys]
        return e
    }()

    private static let decoder = JSONDecoder()
}
