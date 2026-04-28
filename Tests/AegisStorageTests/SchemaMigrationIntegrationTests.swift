// SchemaMigrationIntegrationTests.swift
// Sprint 8 closeout integration test — verifies that a fresh
// database, migrated from user_version 0 to the latest schema,
// supports the full Sprint 4 → 5 → 8 stack: identities,
// PQXDH handshake, ratchet sessions, AEAD-at-rest persistence,
// thread reconstruction.
//
// Definition-of-done item from issue #12:
//   "Migration test: a session bootstrapped pre-persistence
//    still decrypts after persistence lands"
//
// We interpret this two ways and verify both in this file:
//
//   1. (schema migration) A DB at user_version 0 (i.e. a
//      fresh file with nothing applied) can be migrated to
//      the latest version and is then usable by every store
//      in this module.
//   2. (in-memory → on-disk) A RatchetSession that was
//      running in memory (the way Sprint 5 left them) can be
//      saved to the new RatchetSessionStore and resumed —
//      its peer can keep decrypting messages from the
//      restored session as if no save had happened.

import AegisCrypto
@testable import AegisStorage
import Foundation
import XCTest

final class SchemaMigrationIntegrationTests: XCTestCase {

    private var dbURL: URL!
    private var savedAegisService: String = ""
    private var testKeychainService: String = ""

    override func setUpWithError() throws {
        try super.setUpWithError()
        savedAegisService = AegisStorage.serviceIdentifier
        testKeychainService = "io.github.demigoddsk.aegis.tests.\(UUID().uuidString)"
        AegisStorage.serviceIdentifier = testKeychainService

        dbURL = URL(fileURLWithPath: NSTemporaryDirectory())
            .appendingPathComponent("aegis-mig-int-\(UUID().uuidString).sqlite")
    }

    override func tearDownWithError() throws {
        if let dbURL {
            try? FileManager.default.removeItem(at: dbURL)
            try? FileManager.default.removeItem(at: dbURL.appendingPathExtension("-wal"))
            try? FileManager.default.removeItem(at: dbURL.appendingPathExtension("-shm"))
        }
        try? AegisStorage.purgeAll(serviceIdentifier: testKeychainService)
        AegisStorage.serviceIdentifier = savedAegisService
        try super.tearDownWithError()
    }

    // MARK: - Schema migration → end-to-end usability

    func testFreshDatabase_migratesToLatest_andIsUsableEndToEnd() throws {
        // 1. Open a fresh DB, confirm it starts at version 0.
        let db = try SQLiteDatabase(url: dbURL)
        XCTAssertEqual(try db.userVersion(), 0)

        // 2. Apply migrations. Confirm we landed on the latest
        //    version listed in Migrations.all.
        let applied = try Migrations.apply(to: db)
        XCTAssertEqual(applied, Migrations.all.count)
        XCTAssertEqual(
            try db.userVersion(),
            Migrations.all.last!.version
        )

        // 3. Bootstrap a real Alice ↔ Bob session via the full
        //    Sprint 4 PQXDH stack — same path the iOS app's
        //    TwoUserDemo runs in production.
        let alice = try IdentityKeyPair.generate()
        let bob = try IdentityKeyPair.generate()
        let (bundle, secrets) = try PrekeyBundle.generate(
            identity: bob,
            oneTimePrekeyCount: 0
        )
        let initiate = try PQXDH.initiate(
            as: alice,
            toBundle: bundle,
            useOneTimePrekey: false
        )
        let bobSecret = try PQXDH.respond(
            as: bob,
            bundleSecrets: secrets,
            bundleEpoch: bundle.signedPrekeyEpoch,
            receiving: initiate.initialMessage
        )
        XCTAssertEqual(initiate.sharedSecret, bobSecret)

        let aliceSession = try RatchetSession.initiateAsAlice(
            sharedSecret: initiate.sharedSecret,
            bobSignedPrekeyPublic: bundle.signedPrekey.publicKey
        )
        let bobSPKKeyPair = DHKeyPair(
            publicKey: bundle.signedPrekey.publicKey,
            privateKey: secrets.signedPrekey.privateKey
        )
        let bobSession = try RatchetSession.initiateAsBob(
            sharedSecret: bobSecret,
            signedPrekeyKeyPair: bobSPKKeyPair
        )

        // 4. Drive both sides through ConversationStore on the
        //    freshly-migrated DB.
        let sessionStore = RatchetSessionStore(database: db)
        let conversationStore = ConversationStore(
            database: db, sessionStore: sessionStore
        )
        let aliceConv = try conversationStore.create(
            peerIdentity: bob.publicKey,
            displayName: "Bob",
            ratchetSession: aliceSession
        )
        let bobConv = try conversationStore.create(
            peerIdentity: alice.publicKey,
            displayName: "Alice",
            ratchetSession: bobSession
        )

        // 5. Send a couple of messages each way.
        let m1 = try conversationStore.send(
            plaintext: Data("hi bob".utf8),
            in: aliceConv.id
        )
        _ = try conversationStore.receive(m1.wireMessage, in: bobConv.id)

        let m2 = try conversationStore.send(
            plaintext: Data("hi alice".utf8),
            in: bobConv.id
        )
        _ = try conversationStore.receive(m2.wireMessage, in: aliceConv.id)

        // 6. Both sides see both plaintexts in their threads.
        let aliceMessages = try conversationStore.messages(in: aliceConv.id)
        XCTAssertEqual(aliceMessages.count, 2)
        XCTAssertEqual(aliceMessages.map(\.plaintext),
                       [Data("hi bob".utf8), Data("hi alice".utf8)])

        let bobMessages = try conversationStore.messages(in: bobConv.id)
        XCTAssertEqual(bobMessages.count, 2)
        XCTAssertEqual(bobMessages.map(\.plaintext),
                       [Data("hi bob".utf8), Data("hi alice".utf8)])
    }

    // MARK: - In-memory → on-disk handoff

    func testInMemorySession_canBePersistedAndResumed_byLivePeer() throws {
        // Sprint 5 left ratchet sessions in memory only. This
        // test verifies that an in-memory session
        // (bootstrapped without ever touching the SQLite
        // store) can be handed off to RatchetSessionStore
        // mid-conversation and continue to receive messages
        // from a live peer.
        let db = try SQLiteDatabase(url: dbURL)
        _ = try Migrations.apply(to: db)
        let sessionStore = RatchetSessionStore(database: db)
        let conversationStore = ConversationStore(
            database: db, sessionStore: sessionStore
        )

        // Bootstrap two in-memory sessions the Sprint-5 way —
        // shared secret only, no PrekeyBundle dance, no
        // ConversationStore.
        let bobSPK = X25519.generateKeyPair()
        let secret = Data(repeating: 0xA1, count: 32)
        var alice = try RatchetSession.initiateAsAlice(
            sharedSecret: secret,
            bobSignedPrekeyPublic: bobSPK.publicKey
        )
        var bob = try RatchetSession.initiateAsBob(
            sharedSecret: secret,
            signedPrekeyKeyPair: bobSPK
        )

        // Exchange one message in memory.
        let m1 = try alice.encrypt(Data("first".utf8))
        XCTAssertEqual(try bob.decrypt(m1), Data("first".utf8))

        // NOW persist Alice into the new SQLite store.
        // We need a conversation row first (FK requirement).
        let aliceConv = try conversationStore.create(
            peerIdentity: try IdentityKeyPair.generate().publicKey,
            displayName: "Bob",
            ratchetSession: alice
        )

        // Drop the in-memory Alice and reload from disk.
        var reloadedAlice = try XCTUnwrap(
            try sessionStore.load(forConversation: aliceConv.id.data)
        )

        // Live Bob → reloaded Alice still works.
        let m2 = try bob.encrypt(Data("second".utf8))
        XCTAssertEqual(try reloadedAlice.decrypt(m2), Data("second".utf8))

        // Reloaded Alice → live Bob also works (this is the
        // direction that exercises the post-DH-step state on
        // the reloaded side).
        let m3 = try reloadedAlice.encrypt(Data("third".utf8))
        XCTAssertEqual(try bob.decrypt(m3), Data("third".utf8))
    }
}
