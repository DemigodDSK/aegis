// Migrations.swift
// User-version-driven SQL migration runner.
//
// Schema versioning lives in SQLite's PRAGMA user_version
// (a 32-bit integer SQLite tracks per database file, separate
// from any application data). Aegis writes that value as the
// schema-version number and treats version 0 as "fresh DB,
// nothing applied yet".
//
// Adding a new schema version: append a Migration entry to
// `Migrations.all`, with `version` strictly greater than any
// existing entry. The runner applies each missing migration
// in order, inside its own transaction, and bumps user_version
// at the end of each. Existing migrations must NEVER be
// edited — they describe the on-disk shape of databases in
// the wild.

import Foundation

/// One step of the schema's history.
public struct Migration: Sendable {
    public let version: Int64
    public let description: String
    public let sql: String

    public init(version: Int64, description: String, sql: String) {
        self.version = version
        self.description = description
        self.sql = sql
    }
}

public enum Migrations {

    /// Schema migrations in strictly ascending `version` order.
    /// Append-only — old migrations are part of the on-disk
    /// shape and must never be edited.
    public static let all: [Migration] = [
        Migration(
            version: 1,
            description: "Sprint 8 schema v1: conversations + messages",
            sql: """
            CREATE TABLE conversations (
                id                  BLOB    PRIMARY KEY NOT NULL,
                peer_identity       BLOB    NOT NULL,
                display_name        TEXT    NOT NULL,
                aead_method         TEXT    NOT NULL,
                kem_method          TEXT    NOT NULL,
                signature_method    TEXT    NOT NULL,
                created_at          INTEGER NOT NULL,
                updated_at          INTEGER NOT NULL
            );
            CREATE INDEX idx_conversations_updated
                ON conversations(updated_at DESC);

            CREATE TABLE messages (
                id                  BLOB    PRIMARY KEY NOT NULL,
                conversation_id     BLOB    NOT NULL
                                    REFERENCES conversations(id)
                                    ON DELETE CASCADE,
                direction           INTEGER NOT NULL,
                ciphertext          BLOB    NOT NULL,
                sent_at             INTEGER NOT NULL,
                message_number      INTEGER NOT NULL
            );
            CREATE INDEX idx_messages_conv_sent
                ON messages(conversation_id, sent_at);
            """
        ),
        Migration(
            version: 2,
            description: "Sprint 8 schema v2: ratchet_sessions table",
            sql: """
            CREATE TABLE ratchet_sessions (
                conversation_id     BLOB    PRIMARY KEY NOT NULL
                                    REFERENCES conversations(id)
                                    ON DELETE CASCADE,
                state               BLOB    NOT NULL,
                updated_at          INTEGER NOT NULL
            );
            """
        )
    ]

    /// Apply every migration whose version is strictly greater
    /// than the database's current `user_version`. No-op if the
    /// DB is already at or above the latest version.
    ///
    /// Each migration runs inside its own transaction; a
    /// failure halts the run and leaves any earlier successful
    /// migrations committed.
    @discardableResult
    public static func apply(
        _ migrations: [Migration] = Migrations.all,
        to db: SQLiteDatabase
    ) throws -> Int {
        let current = try db.userVersion()
        let pending = migrations
            .filter { $0.version > current }
            .sorted { $0.version < $1.version }

        for migration in pending {
            try db.transaction {
                try db.execute(migration.sql)
                try db.setUserVersion(migration.version)
            }
        }

        return pending.count
    }
}
