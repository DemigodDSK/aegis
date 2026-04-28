// ConversationStoreTests.swift
// CRUD + send / receive / messages tests for the
// ConversationStore. Each test isolates its Keychain namespace
// (per-test serviceIdentifier) and SQLite file (per-test temp
// path).

import AegisCrypto
@testable import AegisStorage
import Foundation
import XCTest

final class ConversationStoreTests: XCTestCase {

    private var dbURL: URL!
    private var db: SQLiteDatabase!
    private var sessionStore: RatchetSessionStore!
    private var store: ConversationStore!

    private var testService: String = ""
    private var savedService: String = ""

    override func setUpWithError() throws {
        try super.setUpWithError()
        savedService = AegisStorage.serviceIdentifier
        testService = "io.github.demigoddsk.aegis.tests.\(UUID().uuidString)"
        AegisStorage.serviceIdentifier = testService

        dbURL = URL(fileURLWithPath: NSTemporaryDirectory())
            .appendingPathComponent("aegis-cs-\(UUID().uuidString).sqlite")
        db = try SQLiteDatabase(url: dbURL)
        _ = try Migrations.apply(to: db)
        sessionStore = RatchetSessionStore(database: db)
        store = ConversationStore(database: db, sessionStore: sessionStore)
    }

    override func tearDownWithError() throws {
        store = nil
        sessionStore = nil
        db = nil
        if let dbURL {
            try? FileManager.default.removeItem(at: dbURL)
            try? FileManager.default.removeItem(at: dbURL.appendingPathExtension("-wal"))
            try? FileManager.default.removeItem(at: dbURL.appendingPathExtension("-shm"))
        }
        dbURL = nil

        try? AegisStorage.purgeAll(serviceIdentifier: testService)
        AegisStorage.serviceIdentifier = savedService
        try super.tearDownWithError()
    }

    // MARK: - Helpers

    /// Fresh PQXDH-derived shared secret + Bob signed-prekey
    /// pair → both ratchet sessions ready to encrypt/decrypt.
    private func makeRatchetPair() throws -> (alice: RatchetSession, bob: RatchetSession) {
        let bobSPK = X25519.generateKeyPair()
        let secret = Data(repeating: 0xC4, count: 32)
        let alice = try RatchetSession.initiateAsAlice(
            sharedSecret: secret,
            bobSignedPrekeyPublic: bobSPK.publicKey
        )
        let bob = try RatchetSession.initiateAsBob(
            sharedSecret: secret,
            signedPrekeyKeyPair: bobSPK
        )
        return (alice, bob)
    }

    private func makeIdentity() throws -> IdentityPublicKey {
        try IdentityKeyPair.generate().publicKey
    }

    // MARK: - Conversation CRUD

    func testCreate_persistsConversationSessionAndStorageKey() throws {
        let (alice, _) = try makeRatchetPair()
        let peer = try makeIdentity()
        let conv = try store.create(
            peerIdentity: peer,
            displayName: "Bob",
            ratchetSession: alice
        )

        // Conversation persisted
        let loaded = try XCTUnwrap(try store.load(id: conv.id))
        XCTAssertEqual(loaded.id, conv.id)
        XCTAssertEqual(loaded.displayName, "Bob")
        XCTAssertEqual(loaded.peerIdentity, peer)
        XCTAssertEqual(loaded.aeadMethod, ConversationDefaults.aead)
        XCTAssertEqual(loaded.kemMethod, ConversationDefaults.kem)
        XCTAssertEqual(loaded.signatureMethod, ConversationDefaults.signature)

        // Session persisted (via the session store)
        XCTAssertNotNil(try sessionStore.load(forConversation: conv.id.data))

        // Storage key provisioned
        XCTAssertNotNil(try ConversationStorageKey.load(for: conv.id))
    }

    func testList_sortsByUpdatedAtDescending() throws {
        let peer = try makeIdentity()
        let (a1, _) = try makeRatchetPair()
        let (a2, _) = try makeRatchetPair()
        let (a3, _) = try makeRatchetPair()

        final class TestClock: @unchecked Sendable {
            var value: Int64 = 100
            func bump() -> Int64 { value += 1; return value }
        }
        let clock = TestClock()
        let bumpClock: @Sendable () -> Int64 = { clock.bump() }
        let storeWithClock = ConversationStore(
            database: db, sessionStore: sessionStore, now: bumpClock
        )

        _ = try storeWithClock.create(peerIdentity: peer, displayName: "first", ratchetSession: a1)
        let mid = try storeWithClock.create(peerIdentity: peer, displayName: "middle", ratchetSession: a2)
        let last = try storeWithClock.create(peerIdentity: peer, displayName: "last", ratchetSession: a3)

        let listed = try storeWithClock.list()
        XCTAssertEqual(listed.count, 3)
        XCTAssertEqual(listed[0].id, last.id)
        XCTAssertEqual(listed[1].id, mid.id)
    }

    func testLoadById_returnsNilForUnknownId() throws {
        XCTAssertNil(try store.load(id: UUID()))
    }

    func testDelete_removesConversationSessionStorageKey() throws {
        let (alice, _) = try makeRatchetPair()
        let conv = try store.create(
            peerIdentity: try makeIdentity(),
            displayName: "Bob",
            ratchetSession: alice
        )

        try store.delete(id: conv.id)

        XCTAssertNil(try store.load(id: conv.id))
        XCTAssertNil(try sessionStore.load(forConversation: conv.id.data),
                     "FK CASCADE should drop the session row")
        XCTAssertNil(try ConversationStorageKey.load(for: conv.id),
                     "delete should also remove the Keychain storage key")
    }

    // MARK: - send / receive

    func testSendAndReceive_roundTripsThePlaintext() throws {
        let (alice, bob) = try makeRatchetPair()
        let peerForAlice = try makeIdentity()
        let peerForBob = try makeIdentity()

        let aliceConv = try store.create(
            peerIdentity: peerForAlice,
            displayName: "Bob (peer view of Alice)",
            ratchetSession: alice
        )
        let bobConv = try store.create(
            peerIdentity: peerForBob,
            displayName: "Alice (peer view of Bob)",
            ratchetSession: bob
        )

        let result = try store.send(plaintext: Data("hello".utf8), in: aliceConv.id)
        XCTAssertEqual(result.storedMessage.plaintext, Data("hello".utf8))
        XCTAssertEqual(result.storedMessage.direction, .outgoing)

        let received = try store.receive(result.wireMessage, in: bobConv.id)
        XCTAssertEqual(received.plaintext, Data("hello".utf8))
        XCTAssertEqual(received.direction, .incoming)
    }

    func testMessages_returnsPlaintextInChronologicalOrder() throws {
        let (alice, bob) = try makeRatchetPair()
        let aliceConv = try store.create(
            peerIdentity: try makeIdentity(),
            displayName: "Bob",
            ratchetSession: alice
        )
        let bobConv = try store.create(
            peerIdentity: try makeIdentity(),
            displayName: "Alice",
            ratchetSession: bob
        )

        // Alice sends three messages, Bob receives all three
        let bodies = ["one", "two", "three"].map { Data($0.utf8) }
        var deliveries: [RatchetMessage] = []
        for body in bodies {
            let r = try store.send(plaintext: body, in: aliceConv.id)
            deliveries.append(r.wireMessage)
        }
        for delivery in deliveries {
            _ = try store.receive(delivery, in: bobConv.id)
        }

        // Alice's view: three outgoing
        let aliceMessages = try store.messages(in: aliceConv.id)
        XCTAssertEqual(aliceMessages.map(\.plaintext), bodies)
        XCTAssertTrue(aliceMessages.allSatisfy { $0.direction == .outgoing })

        // Bob's view: three incoming
        let bobMessages = try store.messages(in: bobConv.id)
        XCTAssertEqual(bobMessages.map(\.plaintext), bodies)
        XCTAssertTrue(bobMessages.allSatisfy { $0.direction == .incoming })
    }

    func testSend_advancesTheRatchetSessionInDB() throws {
        let (alice, _) = try makeRatchetPair()
        let conv = try store.create(
            peerIdentity: try makeIdentity(),
            displayName: "Bob",
            ratchetSession: alice
        )

        let preState = try XCTUnwrap(try sessionStore.load(forConversation: conv.id.data))
        _ = try store.send(plaintext: Data("a".utf8), in: conv.id)
        let postState = try XCTUnwrap(try sessionStore.load(forConversation: conv.id.data))

        XCTAssertNotEqual(preState.sendingChainKey, postState.sendingChainKey,
                          "send must advance and persist the sending chain")
        XCTAssertEqual(preState.nSend, 0)
        XCTAssertEqual(postState.nSend, 1)
    }

    func testSend_failsCleanlyWhenStorageKeyMissing() throws {
        let (alice, _) = try makeRatchetPair()
        let conv = try store.create(
            peerIdentity: try makeIdentity(),
            displayName: "Bob",
            ratchetSession: alice
        )

        // Wipe the storage key out of band — simulates Keychain
        // corruption / accidental removal.
        try ConversationStorageKey.delete(for: conv.id)

        XCTAssertThrowsError(
            try store.send(plaintext: Data("x".utf8), in: conv.id)
        ) { error in
            guard case ConversationStoreError.storageKeyMissing = error else {
                return XCTFail("expected .storageKeyMissing, got \(error)")
            }
        }
    }

    // MARK: - At-rest AAD binding

    func testMessages_failIfBlobIsSwappedAcrossRows() throws {
        let (alice, _) = try makeRatchetPair()
        let aliceConv = try store.create(
            peerIdentity: try makeIdentity(),
            displayName: "Bob",
            ratchetSession: alice
        )

        _ = try store.send(plaintext: Data("first".utf8), in: aliceConv.id)
        _ = try store.send(plaintext: Data("second".utf8), in: aliceConv.id)

        // Swap the two messages' ciphertext blobs in SQL.
        try db.execute("""
            UPDATE messages
            SET ciphertext = (
                SELECT ciphertext FROM messages AS m2
                WHERE m2.conversation_id = messages.conversation_id
                  AND m2.id != messages.id
                LIMIT 1
            )
            WHERE conversation_id = X'\(aliceConv.id.data.map { String(format: "%02X", $0) }.joined())';
            """)

        // After the swap, decryption MUST fail (AAD includes the
        // message_id, and the swapped blob's AAD won't match).
        XCTAssertThrowsError(
            try store.messages(in: aliceConv.id)
        )
    }

    // MARK: - Empty conversation

    func testMessages_emptyConversationReturnsEmptyArray() throws {
        let (alice, _) = try makeRatchetPair()
        let conv = try store.create(
            peerIdentity: try makeIdentity(),
            displayName: "Bob",
            ratchetSession: alice
        )

        XCTAssertEqual(try store.messages(in: conv.id).count, 0)
    }
}
