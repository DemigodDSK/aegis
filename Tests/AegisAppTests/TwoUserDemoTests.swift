// TwoUserDemoTests.swift
// Sprint 8 commit 5 — verifies the bootstrap flow and the
// send round-trip across the persona toggle.

import AegisCrypto
@testable import AegisApp
@testable import AegisStorage
import Foundation
import XCTest

@MainActor
final class TwoUserDemoTests: XCTestCase {

    private var dbURL: URL!
    private var db: SQLiteDatabase!
    private var sessionStore: RatchetSessionStore!
    private var conversationStore: ConversationStore!

    private var savedAegisService: String = ""
    private var testKeychainService: String = ""

    override func setUp() async throws {
        try await super.setUp()
        savedAegisService = AegisStorage.serviceIdentifier
        testKeychainService = "io.github.demigoddsk.aegis.tests.\(UUID().uuidString)"
        AegisStorage.serviceIdentifier = testKeychainService

        dbURL = URL(fileURLWithPath: NSTemporaryDirectory())
            .appendingPathComponent("aegis-demo-\(UUID().uuidString).sqlite")
        db = try SQLiteDatabase(url: dbURL)
        _ = try Migrations.apply(to: db)
        sessionStore = RatchetSessionStore(database: db)
        conversationStore = ConversationStore(database: db, sessionStore: sessionStore)
    }

    override func tearDown() async throws {
        conversationStore = nil
        sessionStore = nil
        db = nil
        if let dbURL {
            try? FileManager.default.removeItem(at: dbURL)
            try? FileManager.default.removeItem(at: dbURL.appendingPathExtension("-wal"))
            try? FileManager.default.removeItem(at: dbURL.appendingPathExtension("-shm"))
        }
        try? AegisStorage.purgeAll(serviceIdentifier: testKeychainService)
        AegisStorage.serviceIdentifier = savedAegisService
        try await super.tearDown()
    }

    // MARK: - Bootstrap

    func testBootstrap_createsTwoConversations() throws {
        let demo = TwoUserDemo(store: conversationStore)
        XCTAssertFalse(demo.isBootstrapped)
        try demo.bootstrap()
        XCTAssertTrue(demo.isBootstrapped)
        XCTAssertNotNil(demo.aliceConversation)
        XCTAssertNotNil(demo.bobConversation)
        XCTAssertNotEqual(demo.aliceConversation?.id, demo.bobConversation?.id)
    }

    func testBootstrap_isIdempotent() throws {
        let demo = TwoUserDemo(store: conversationStore)
        try demo.bootstrap()
        let aliceId = demo.aliceConversation?.id
        let bobId = demo.bobConversation?.id

        try demo.bootstrap()
        XCTAssertEqual(demo.aliceConversation?.id, aliceId,
                       "second bootstrap must NOT overwrite existing conversations")
        XCTAssertEqual(demo.bobConversation?.id, bobId)
    }

    func testBootstrap_displayNamesReflectThePeer() throws {
        let demo = TwoUserDemo(store: conversationStore)
        try demo.bootstrap()
        XCTAssertEqual(demo.aliceConversation?.displayName, "Bob",
                       "Alice's row in her view shows whom she's chatting with")
        XCTAssertEqual(demo.bobConversation?.displayName, "Alice")
    }

    // MARK: - Persona toggle

    func testActivePersona_defaultsToAlice() throws {
        let demo = TwoUserDemo(store: conversationStore)
        XCTAssertEqual(demo.activePersona, .alice)
    }

    func testToggle_swapsPersonaAndActiveConversation() throws {
        let demo = TwoUserDemo(store: conversationStore)
        try demo.bootstrap()
        XCTAssertEqual(demo.activeConversation?.id, demo.aliceConversation?.id)

        demo.togglePersona()
        XCTAssertEqual(demo.activePersona, .bob)
        XCTAssertEqual(demo.activeConversation?.id, demo.bobConversation?.id)

        demo.togglePersona()
        XCTAssertEqual(demo.activePersona, .alice)
        XCTAssertEqual(demo.activeConversation?.id, demo.aliceConversation?.id)
    }

    func testSetActivePersona_explicitlySwitches() throws {
        let demo = TwoUserDemo(store: conversationStore)
        try demo.bootstrap()
        demo.setActivePersona(.bob)
        XCTAssertEqual(demo.activePersona, .bob)
        demo.setActivePersona(.alice)
        XCTAssertEqual(demo.activePersona, .alice)
    }

    // MARK: - Send round-trip

    func testSendFromAlice_appearsInBothViews() throws {
        let demo = TwoUserDemo(store: conversationStore)
        try demo.bootstrap()

        // Alice is active by default
        let stored = try demo.send(plaintext: Data("hi bob".utf8))
        XCTAssertEqual(stored.plaintext, Data("hi bob".utf8))
        XCTAssertEqual(stored.direction, .outgoing,
                       "from Alice's perspective the message is outgoing")

        // Alice's view: one outgoing message
        let aliceMessages = try conversationStore.messages(in: demo.aliceConversation!.id)
        XCTAssertEqual(aliceMessages.count, 1)
        XCTAssertEqual(aliceMessages.first?.direction, .outgoing)
        XCTAssertEqual(aliceMessages.first?.plaintext, Data("hi bob".utf8))

        // Bob's view: one incoming message with the same plaintext
        let bobMessages = try conversationStore.messages(in: demo.bobConversation!.id)
        XCTAssertEqual(bobMessages.count, 1)
        XCTAssertEqual(bobMessages.first?.direction, .incoming)
        XCTAssertEqual(bobMessages.first?.plaintext, Data("hi bob".utf8))
    }

    func testSendFromBob_appearsInBothViews() throws {
        let demo = TwoUserDemo(store: conversationStore)
        try demo.bootstrap()

        // Alice has to send first — Bob's ratchet has no
        // sending chain until inbound triggers it. Mirrors
        // the real Double Ratchet handshake.
        _ = try demo.send(plaintext: Data("hi bob".utf8))

        // Now Bob can reply.
        demo.setActivePersona(.bob)
        let stored = try demo.send(plaintext: Data("hi alice".utf8))
        XCTAssertEqual(stored.direction, .outgoing,
                       "from Bob's perspective his message is outgoing")

        let aliceMessages = try conversationStore.messages(in: demo.aliceConversation!.id)
        XCTAssertEqual(aliceMessages.count, 2)
        XCTAssertEqual(aliceMessages[0].direction, .outgoing)  // her own "hi bob"
        XCTAssertEqual(aliceMessages[1].direction, .incoming)  // bob's reply
        XCTAssertEqual(aliceMessages[1].plaintext, Data("hi alice".utf8))

        let bobMessages = try conversationStore.messages(in: demo.bobConversation!.id)
        XCTAssertEqual(bobMessages.count, 2)
        XCTAssertEqual(bobMessages[0].direction, .incoming)
        XCTAssertEqual(bobMessages[1].direction, .outgoing)
    }

    func testManyMessages_roundTripWithDhRotations() throws {
        let demo = TwoUserDemo(store: conversationStore)
        try demo.bootstrap()

        // Five-message back-and-forth — exercises a DH ratchet
        // step on every direction change.
        let exchanges: [(persona: TwoUserPersona, body: String)] = [
            (.alice, "1"),
            (.bob, "2"),
            (.alice, "3"),
            (.bob, "4"),
            (.alice, "5"),
        ]
        for (persona, body) in exchanges {
            demo.setActivePersona(persona)
            _ = try demo.send(plaintext: Data(body.utf8))
        }

        let aliceMessages = try conversationStore.messages(in: demo.aliceConversation!.id)
        let bobMessages = try conversationStore.messages(in: demo.bobConversation!.id)
        XCTAssertEqual(aliceMessages.count, 5)
        XCTAssertEqual(bobMessages.count, 5)
        XCTAssertEqual(aliceMessages.map(\.plaintext),
                       exchanges.map { Data($0.body.utf8) })
        XCTAssertEqual(bobMessages.map(\.plaintext),
                       exchanges.map { Data($0.body.utf8) })
    }

    // MARK: - Errors

    func testSend_beforeBootstrap_throwsNotBootstrapped() throws {
        let demo = TwoUserDemo(store: conversationStore)
        XCTAssertThrowsError(
            try demo.send(plaintext: Data("x".utf8))
        ) { error in
            guard case TwoUserDemoError.notBootstrapped = error else {
                return XCTFail("expected .notBootstrapped, got \(error)")
            }
        }
    }
}
