// RatchetSessionStoreTests.swift
// CRUD tests for RatchetSessionStore + the v2 schema migration
// it depends on.

import AegisCrypto
@testable import AegisStorage
import Foundation
import XCTest

final class RatchetSessionStoreTests: XCTestCase {

    private var dbURL: URL!
    private var db: SQLiteDatabase!
    private var store: RatchetSessionStore!

    override func setUpWithError() throws {
        try super.setUpWithError()
        dbURL = URL(fileURLWithPath: NSTemporaryDirectory())
            .appendingPathComponent("aegis-rss-\(UUID().uuidString).sqlite")
        db = try SQLiteDatabase(url: dbURL)
        _ = try Migrations.apply(to: db)
        store = RatchetSessionStore(database: db)
    }

    override func tearDownWithError() throws {
        store = nil
        db = nil
        if let dbURL {
            try? FileManager.default.removeItem(at: dbURL)
            try? FileManager.default.removeItem(at: dbURL.appendingPathExtension("-wal"))
            try? FileManager.default.removeItem(at: dbURL.appendingPathExtension("-shm"))
        }
        dbURL = nil
        try super.tearDownWithError()
    }

    // MARK: - Helpers

    /// A conversation-id we can bind sessions to. We also have
    /// to insert a row in the `conversations` table since the
    /// FK in `ratchet_sessions` requires it.
    private func freshConversationId() throws -> Data {
        let id = withUnsafeBytes(of: UUID().uuid) { Data($0) }
        try insertConversationRow(id: id)
        return id
    }

    private func insertConversationRow(id: Data) throws {
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
        try stmt.bind("Test peer", at: 3)
        try stmt.bind("AEGIS_AES_256_GCM_v1", at: 4)
        try stmt.bind("AEGIS_XWING_MLKEM768_X25519_v1", at: 5)
        try stmt.bind("AEGIS_MLDSA65_v1", at: 6)
        try stmt.bind(Int64(0), at: 7)
        try stmt.bind(Int64(0), at: 8)
        _ = try stmt.step()
    }

    private func freshSession() throws -> RatchetSession {
        let bobSPK = X25519.generateKeyPair()
        return try RatchetSession.initiateAsAlice(
            sharedSecret: Data(repeating: 0xD3, count: 32),
            bobSignedPrekeyPublic: bobSPK.publicKey
        )
    }

    // MARK: - CRUD round-trip

    func testSaveAndLoad_roundTripsTheSession() throws {
        let id = try freshConversationId()
        let original = try freshSession()
        try store.save(original, forConversation: id)

        let loaded = try XCTUnwrap(try store.load(forConversation: id))

        XCTAssertEqual(loaded.rootKey, original.rootKey)
        XCTAssertEqual(loaded.sendingChainKey, original.sendingChainKey)
        XCTAssertEqual(loaded.sendingDH.publicKey, original.sendingDH.publicKey)
        XCTAssertEqual(loaded.sendingDH.privateKey, original.sendingDH.privateKey)
        XCTAssertEqual(loaded.receivingDH, original.receivingDH)
    }

    func testLoadBeforeSave_returnsNil() throws {
        let id = try freshConversationId()
        XCTAssertNil(try store.load(forConversation: id))
    }

    func testSave_replacesPriorSessionForSameConversation() throws {
        let id = try freshConversationId()
        let first = try freshSession()
        try store.save(first, forConversation: id)
        let second = try freshSession()
        try store.save(second, forConversation: id)

        let loaded = try XCTUnwrap(try store.load(forConversation: id))
        XCTAssertEqual(loaded.sendingDH.publicKey, second.sendingDH.publicKey,
                       "save must upsert, not duplicate")
        XCTAssertNotEqual(loaded.sendingDH.publicKey, first.sendingDH.publicKey)
    }

    func testDelete_removesSession() throws {
        let id = try freshConversationId()
        try store.save(try freshSession(), forConversation: id)
        XCTAssertNotNil(try store.load(forConversation: id))

        try store.delete(forConversation: id)
        XCTAssertNil(try store.load(forConversation: id))
    }

    func testDelete_isIdempotent() throws {
        let id = try freshConversationId()
        XCTAssertNoThrow(try store.delete(forConversation: id))
        XCTAssertNoThrow(try store.delete(forConversation: id))
    }

    // MARK: - Multi-conversation isolation

    func testSessions_areIsolatedByConversationId() throws {
        let idA = try freshConversationId()
        let idB = try freshConversationId()
        let sessionA = try freshSession()
        let sessionB = try freshSession()

        try store.save(sessionA, forConversation: idA)
        try store.save(sessionB, forConversation: idB)

        let loadedA = try XCTUnwrap(try store.load(forConversation: idA))
        let loadedB = try XCTUnwrap(try store.load(forConversation: idB))

        XCTAssertEqual(loadedA.sendingDH.publicKey, sessionA.sendingDH.publicKey)
        XCTAssertEqual(loadedB.sendingDH.publicKey, sessionB.sendingDH.publicKey)
        XCTAssertNotEqual(loadedA.sendingDH.publicKey, loadedB.sendingDH.publicKey)
    }

    // MARK: - FK cascade

    func testDeletingConversation_cascadesAwayItsSession() throws {
        let id = try freshConversationId()
        try store.save(try freshSession(), forConversation: id)
        XCTAssertNotNil(try store.load(forConversation: id))

        try db.execute("DELETE FROM conversations;")

        XCTAssertNil(try store.load(forConversation: id),
                     "FK ON DELETE CASCADE should have removed the orphaned session")
    }

    // MARK: - Updated-at clock

    func testUpdatedAt_isWrittenFromInjectedClock() throws {
        let id = try freshConversationId()
        let fixedNow: @Sendable () -> Int64 = { 1_700_000_000 }
        let withClock = RatchetSessionStore(database: db, now: fixedNow)
        try withClock.save(try freshSession(), forConversation: id)

        let stmt = try db.prepare(
            "SELECT updated_at FROM ratchet_sessions WHERE conversation_id = ?;"
        )
        defer { stmt.finalize() }
        try stmt.bind(id, at: 1)
        XCTAssertTrue(try stmt.step())
        XCTAssertEqual(stmt.int64(at: 0), 1_700_000_000)
    }

    // MARK: - Continued conversation post-restore

    func testReloadedSession_canStillEncryptAndDecrypt() throws {
        // Bootstrap a real Alice/Bob pair, exchange a couple
        // messages, then reload Alice from disk and continue.
        let bobSPK = X25519.generateKeyPair()
        let sharedSecret = Data(repeating: 0xC2, count: 32)
        var alice = try RatchetSession.initiateAsAlice(
            sharedSecret: sharedSecret,
            bobSignedPrekeyPublic: bobSPK.publicKey
        )
        var bob = try RatchetSession.initiateAsBob(
            sharedSecret: sharedSecret,
            signedPrekeyKeyPair: bobSPK
        )

        let m1 = try alice.encrypt(Data("hello".utf8))
        XCTAssertEqual(try bob.decrypt(m1), Data("hello".utf8))

        let id = try freshConversationId()
        try store.save(alice, forConversation: id)

        // "App restart" — drop the in-memory Alice, reload from disk.
        var reloadedAlice = try XCTUnwrap(try store.load(forConversation: id))
        let m2 = try reloadedAlice.encrypt(Data("after restart".utf8))
        XCTAssertEqual(try bob.decrypt(m2), Data("after restart".utf8))
    }
}
