// AppStateTests.swift
// View-model logic tests for AppState. Covers the routing
// state transitions RootView depends on, persistence into
// the injected UserDefaults, and the Keychain handoff for
// the identity.
//
// SwiftUI views themselves are deliberately not tested here
// — that's "snapshot infrastructure" scope, deferred per
// Sprint 6 settled choices.

import AegisCrypto
import AegisStorage
@testable import AegisApp
import XCTest

@MainActor
final class AppStateTests: XCTestCase {

    private var testDefaults: UserDefaults!
    private var testSuite: String = ""

    private var savedAegisService: String = ""
    private var testKeychainService: String = ""

    override func setUp() async throws {
        try await super.setUp()
        // Per-test UserDefaults suite so concurrent runs and
        // replays don't cross-pollute the user's defaults.
        testSuite = "io.github.demigoddsk.aegis.tests.\(UUID().uuidString)"
        testDefaults = UserDefaults(suiteName: testSuite)!

        // Per-test Keychain service.
        savedAegisService = AegisStorage.serviceIdentifier
        testKeychainService =
            "io.github.demigoddsk.aegis.tests.\(UUID().uuidString)"
        AegisStorage.serviceIdentifier = testKeychainService
    }

    override func tearDown() async throws {
        // Defaults
        UserDefaults().removePersistentDomain(forName: testSuite)
        // Keychain
        try? AegisStorage.purgeAll(serviceIdentifier: testKeychainService)
        AegisStorage.serviceIdentifier = savedAegisService
        try await super.tearDown()
    }

    // MARK: - Initial state

    func testInit_freshInstall_reportsPreOnboarding() {
        let state = AppState(defaults: testDefaults)
        XCTAssertFalse(state.onboardingCompleted)
        XCTAssertNil(state.identity)
        XCTAssertNil(state.displayName)
    }

    func testInit_loadsPersistedOnboardingFlag() {
        testDefaults.set(true, forKey: "io.github.demigoddsk.aegis.onboardingCompleted")
        let state = AppState(defaults: testDefaults)
        XCTAssertTrue(state.onboardingCompleted)
    }

    func testInit_loadsPersistedDisplayName() {
        testDefaults.set("Datta", forKey: "io.github.demigoddsk.aegis.displayName")
        let state = AppState(defaults: testDefaults)
        XCTAssertEqual(state.displayName, "Datta")
    }

    func testInit_loadsPersistedIdentity() throws {
        let prior = try IdentityKeyPair.generate()
        try AegisStorage.saveIdentity(prior)

        let state = AppState(defaults: testDefaults)
        XCTAssertEqual(state.identity?.signing.publicKey, prior.signing.publicKey)
        XCTAssertEqual(state.identity?.dh.publicKey, prior.dh.publicKey)
    }

    // MARK: - Mutations

    func testMarkOnboardingComplete_persists() {
        let state = AppState(defaults: testDefaults)
        XCTAssertFalse(state.onboardingCompleted)

        state.markOnboardingComplete()
        XCTAssertTrue(state.onboardingCompleted)

        // Re-init reads back the persisted flag.
        let reloaded = AppState(defaults: testDefaults)
        XCTAssertTrue(reloaded.onboardingCompleted)
    }

    func testGenerateAndSaveIdentity_persistsAndPopulatesState() throws {
        let state = AppState(defaults: testDefaults)
        XCTAssertNil(state.identity)

        let id = try state.generateAndSaveIdentity()
        XCTAssertNotNil(state.identity)
        XCTAssertEqual(state.identity?.signing.publicKey, id.signing.publicKey)

        // Re-init via Keychain.
        let reloaded = AppState(defaults: testDefaults)
        XCTAssertEqual(reloaded.identity?.signing.publicKey, id.signing.publicKey)
    }

    func testSetDisplayName_storesAndTrims() {
        let state = AppState(defaults: testDefaults)

        state.setDisplayName("  Datta Sai  ")
        XCTAssertEqual(state.displayName, "Datta Sai")

        // Empty / whitespace-only string clears.
        state.setDisplayName("   ")
        XCTAssertNil(state.displayName)

        // Nil also clears.
        state.setDisplayName("Datta")
        XCTAssertEqual(state.displayName, "Datta")
        state.setDisplayName(nil)
        XCTAssertNil(state.displayName)
    }

    // MARK: - Reset

    func testResetEverything_clearsState_andPersistence() throws {
        let state = AppState(defaults: testDefaults)
        state.markOnboardingComplete()
        _ = try state.generateAndSaveIdentity()
        state.setDisplayName("Datta")

        XCTAssertTrue(state.onboardingCompleted)
        XCTAssertNotNil(state.identity)
        XCTAssertEqual(state.displayName, "Datta")

        state.resetEverything()

        XCTAssertFalse(state.onboardingCompleted)
        XCTAssertNil(state.identity)
        XCTAssertNil(state.displayName)

        // And the persistence is rewound.
        let reloaded = AppState(defaults: testDefaults)
        XCTAssertFalse(reloaded.onboardingCompleted)
        XCTAssertNil(reloaded.identity)
        XCTAssertNil(reloaded.displayName)
    }
}
