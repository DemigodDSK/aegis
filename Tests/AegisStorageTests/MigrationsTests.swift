// MigrationsTests.swift
// Tests for the user_version-driven migration runner.
//
// We test both with the production `Migrations.all` list and
// with synthetic migration lists, so the runner is verified
// independently of which schema versions ship today.

@testable import AegisStorage
import Foundation
import XCTest

final class MigrationsTests: XCTestCase {

    private var dbURL: URL!

    override func setUpWithError() throws {
        try super.setUpWithError()
        dbURL = URL(fileURLWithPath: NSTemporaryDirectory())
            .appendingPathComponent("aegis-mig-\(UUID().uuidString).sqlite")
    }

    override func tearDownWithError() throws {
        if let dbURL {
            try? FileManager.default.removeItem(at: dbURL)
            try? FileManager.default.removeItem(at: dbURL.appendingPathExtension("-wal"))
            try? FileManager.default.removeItem(at: dbURL.appendingPathExtension("-shm"))
        }
        dbURL = nil
        try super.tearDownWithError()
    }

    // MARK: - Runner correctness

    func testApplyAllAdvancesUserVersionToLatest() throws {
        let db = try SQLiteDatabase(url: dbURL)
        XCTAssertEqual(try db.userVersion(), 0)

        let applied = try Migrations.apply(to: db)
        XCTAssertEqual(applied, Migrations.all.count)
        XCTAssertEqual(
            try db.userVersion(),
            Migrations.all.last!.version
        )
    }

    func testReapplyIsNoOp() throws {
        let db = try SQLiteDatabase(url: dbURL)
        _ = try Migrations.apply(to: db)
        let secondPass = try Migrations.apply(to: db)
        XCTAssertEqual(secondPass, 0,
                       "second apply on already-current DB must apply nothing")
    }

    func testAppliesOnlyMissingMigrations() throws {
        let db = try SQLiteDatabase(url: dbURL)
        let migrations: [Migration] = [
            Migration(version: 1, description: "first",
                      sql: "CREATE TABLE a (x INTEGER);"),
            Migration(version: 2, description: "second",
                      sql: "CREATE TABLE b (y INTEGER);"),
            Migration(version: 3, description: "third",
                      sql: "CREATE TABLE c (z INTEGER);"),
        ]

        let firstTwo = Array(migrations.prefix(2))
        let appliedFirst = try Migrations.apply(firstTwo, to: db)
        XCTAssertEqual(appliedFirst, 2)
        XCTAssertEqual(try db.userVersion(), 2)

        let appliedSecond = try Migrations.apply(migrations, to: db)
        XCTAssertEqual(appliedSecond, 1, "only the v3 migration should run on the second pass")
        XCTAssertEqual(try db.userVersion(), 3)

        // All three tables now exist
        try db.execute("INSERT INTO a (x) VALUES (1);")
        try db.execute("INSERT INTO b (y) VALUES (2);")
        try db.execute("INSERT INTO c (z) VALUES (3);")
    }

    func testAppliesOutOfOrderMigrationsInOrder() throws {
        let db = try SQLiteDatabase(url: dbURL)
        let migrations: [Migration] = [
            // Deliberately listed out of order; the runner must
            // sort by version before applying. If it didn't, the
            // FK in v2 would point at a not-yet-created table.
            Migration(version: 2, description: "second",
                      sql: "CREATE TABLE b (id INTEGER REFERENCES a(id));"),
            Migration(version: 1, description: "first",
                      sql: "CREATE TABLE a (id INTEGER PRIMARY KEY);"),
        ]

        let count = try Migrations.apply(migrations, to: db)
        XCTAssertEqual(count, 2)
        XCTAssertEqual(try db.userVersion(), 2)
    }

    // MARK: - Schema v1 surface

    func testV1CreatesConversationsAndMessagesTables() throws {
        let db = try SQLiteDatabase(url: dbURL)
        _ = try Migrations.apply(to: db)

        // Insert a conversation row
        let conversationId = Data(repeating: 0xAA, count: 16)
        let peerIdentity = Data(repeating: 0xBB, count: 32)
        let insertConv = try db.prepare("""
            INSERT INTO conversations
                (id, peer_identity, display_name,
                 aead_method, kem_method, signature_method,
                 created_at, updated_at)
            VALUES (?, ?, ?, ?, ?, ?, ?, ?);
            """)
        defer { insertConv.finalize() }
        try insertConv.bind(conversationId, at: 1)
        try insertConv.bind(peerIdentity, at: 2)
        try insertConv.bind("Alice", at: 3)
        try insertConv.bind("AEGIS_AES_256_GCM_v1", at: 4)
        try insertConv.bind("AEGIS_XWING_MLKEM768_X25519_v1", at: 5)
        try insertConv.bind("AEGIS_MLDSA65_v1", at: 6)
        try insertConv.bind(Int64(1714000000), at: 7)
        try insertConv.bind(Int64(1714000000), at: 8)
        XCTAssertFalse(try insertConv.step())

        // Insert a message
        let messageId = Data(repeating: 0xCC, count: 16)
        let ciphertext = Data(repeating: 0xDD, count: 64)
        let insertMsg = try db.prepare("""
            INSERT INTO messages
                (id, conversation_id, direction, ciphertext, sent_at, message_number)
            VALUES (?, ?, ?, ?, ?, ?);
            """)
        defer { insertMsg.finalize() }
        try insertMsg.bind(messageId, at: 1)
        try insertMsg.bind(conversationId, at: 2)
        try insertMsg.bind(Int64(0), at: 3)
        try insertMsg.bind(ciphertext, at: 4)
        try insertMsg.bind(Int64(1714000001), at: 5)
        try insertMsg.bind(Int64(0), at: 6)
        XCTAssertFalse(try insertMsg.step())

        // Verify both rows readable
        let count = try db.prepare("""
            SELECT (SELECT COUNT(*) FROM conversations),
                   (SELECT COUNT(*) FROM messages);
            """)
        defer { count.finalize() }
        XCTAssertTrue(try count.step())
        XCTAssertEqual(count.int64(at: 0), 1)
        XCTAssertEqual(count.int64(at: 1), 1)
    }

    func testForeignKeyCascadesMessageDeletion() throws {
        let db = try SQLiteDatabase(url: dbURL)
        _ = try Migrations.apply(to: db)

        // Insert one conversation + one message bound to it
        let conversationId = Data(repeating: 0xAA, count: 16)
        try insertConversation(db: db, id: conversationId)
        try insertMessage(db: db, conversationId: conversationId)

        // Delete the conversation; the message should cascade away
        try db.execute("DELETE FROM conversations;")

        let count = try db.prepare("SELECT COUNT(*) FROM messages;")
        defer { count.finalize() }
        XCTAssertTrue(try count.step())
        XCTAssertEqual(count.int64(at: 0), 0,
                       "ON DELETE CASCADE should have removed the message")
    }

    // MARK: - Helpers

    private func insertConversation(db: SQLiteDatabase, id: Data) throws {
        let stmt = try db.prepare("""
            INSERT INTO conversations
                (id, peer_identity, display_name,
                 aead_method, kem_method, signature_method,
                 created_at, updated_at)
            VALUES (?, ?, ?, ?, ?, ?, ?, ?);
            """)
        defer { stmt.finalize() }
        try stmt.bind(id, at: 1)
        try stmt.bind(Data(repeating: 0xBB, count: 32), at: 2)
        try stmt.bind("Alice", at: 3)
        try stmt.bind("AEGIS_AES_256_GCM_v1", at: 4)
        try stmt.bind("AEGIS_XWING_MLKEM768_X25519_v1", at: 5)
        try stmt.bind("AEGIS_MLDSA65_v1", at: 6)
        try stmt.bind(Int64(0), at: 7)
        try stmt.bind(Int64(0), at: 8)
        _ = try stmt.step()
    }

    private func insertMessage(db: SQLiteDatabase, conversationId: Data) throws {
        let stmt = try db.prepare("""
            INSERT INTO messages
                (id, conversation_id, direction, ciphertext, sent_at, message_number)
            VALUES (?, ?, ?, ?, ?, ?);
            """)
        defer { stmt.finalize() }
        try stmt.bind(Data(repeating: 0xCC, count: 16), at: 1)
        try stmt.bind(conversationId, at: 2)
        try stmt.bind(Int64(0), at: 3)
        try stmt.bind(Data(repeating: 0xDD, count: 64), at: 4)
        try stmt.bind(Int64(0), at: 5)
        try stmt.bind(Int64(0), at: 6)
        _ = try stmt.step()
    }
}
