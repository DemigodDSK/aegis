// AppStateDatabaseTests.swift
// Tests for the SQLite-backed surface AppState added in
// Sprint 8 commit 4 — `setupDatabase()`, `refreshConversations()`,
// and the `conversationStore` accessor.

import AegisCrypto
@testable import AegisApp
@testable import AegisStorage
import Foundation
import XCTest

@MainActor
final class AppStateDatabaseTests: XCTestCase {

    private var testDefaults: UserDefaults!
    private var testSuite: String = ""
    private var dbURL: URL!

    private var savedAegisService: String = ""
    private var testKeychainService: String = ""

    override func setUp() async throws {
        try await super.setUp()
        testSuite = "io.github.demigoddsk.aegis.tests.\(UUID().uuidString)"
        testDefaults = UserDefaults(suiteName: testSuite)!

        savedAegisService = AegisStorage.serviceIdentifier
        testKeychainService = "io.github.demigoddsk.aegis.tests.\(UUID().uuidString)"
        AegisStorage.serviceIdentifier = testKeychainService

        dbURL = URL(fileURLWithPath: NSTemporaryDirectory())
            .appendingPathComponent("aegis-app-\(UUID().uuidString).sqlite")
    }

    override func tearDown() async throws {
        UserDefaults().removePersistentDomain(forName: testSuite)
        try? AegisStorage.purgeAll(serviceIdentifier: testKeychainService)
        AegisStorage.serviceIdentifier = savedAegisService

        if let dbURL {
            try? FileManager.default.removeItem(at: dbURL)
            try? FileManager.default.removeItem(at: dbURL.appendingPathExtension("-wal"))
            try? FileManager.default.removeItem(at: dbURL.appendingPathExtension("-shm"))
        }
        try await super.tearDown()
    }

    // MARK: - setupDatabase

    func testSetupDatabase_initialState_hasNoStore() {
        let state = AppState(defaults: testDefaults, databaseURL: dbURL)
        XCTAssertNil(state.conversationStore)
        XCTAssertEqual(state.conversations.count, 0)
        XCTAssertNil(state.databaseError)
    }

    func testSetupDatabase_opensTheDatabaseAndStore() {
        let state = AppState(defaults: testDefaults, databaseURL: dbURL)
        state.setupDatabase()
        XCTAssertNotNil(state.conversationStore,
                        "setupDatabase must wire up the conversation store")
        XCTAssertNil(state.databaseError)
    }

    func testSetupDatabase_isIdempotent() {
        let state = AppState(defaults: testDefaults, databaseURL: dbURL)
        state.setupDatabase()
        let firstStore = state.conversationStore
        state.setupDatabase()
        XCTAssertTrue(firstStore === state.conversationStore,
                      "second setupDatabase call must keep the same store handle")
    }

    func testSetupDatabase_failsCleanlyOnUnwritablePath() {
        // /dev/null exists and is special — opening a SQLite
        // file there will fail.
        let badURL = URL(fileURLWithPath: "/dev/null/no-such-aegis.sqlite")
        let state = AppState(defaults: testDefaults, databaseURL: badURL)
        state.setupDatabase()
        XCTAssertNil(state.conversationStore)
        XCTAssertNotNil(state.databaseError,
                        "setupDatabase must surface failure via databaseError")
    }

    // MARK: - refreshConversations

    func testRefreshConversations_freshDB_isEmpty() throws {
        let state = AppState(defaults: testDefaults, databaseURL: dbURL)
        state.setupDatabase()
        try state.refreshConversations()
        XCTAssertEqual(state.conversations.count, 0)
    }

    func testRefreshConversations_picksUpNewlyCreatedConversations() throws {
        let state = AppState(defaults: testDefaults, databaseURL: dbURL)
        state.setupDatabase()
        let store = try XCTUnwrap(state.conversationStore)

        // Bootstrap a fake conversation directly via the store
        let bobSPK = X25519.generateKeyPair()
        let session = try RatchetSession.initiateAsAlice(
            sharedSecret: Data(repeating: 0xC5, count: 32),
            bobSignedPrekeyPublic: bobSPK.publicKey
        )
        _ = try store.create(
            peerIdentity: try IdentityKeyPair.generate().publicKey,
            displayName: "Test Peer",
            ratchetSession: session
        )

        try state.refreshConversations()
        XCTAssertEqual(state.conversations.count, 1)
        XCTAssertEqual(state.conversations.first?.displayName, "Test Peer")
    }

    func testRefreshConversations_beforeSetup_isNoOp() throws {
        let state = AppState(defaults: testDefaults, databaseURL: dbURL)
        try state.refreshConversations()
        XCTAssertEqual(state.conversations.count, 0,
                       "refresh before setupDatabase should be a quiet no-op")
    }
}
