// AegisStorageTests.swift
// CRUD tests for the Keychain-backed identity store.
//
// Each test isolates itself with a unique serviceIdentifier
// (UUID-stamped) so concurrent runs and replays don't
// collide. tearDown purges the test service unconditionally.

import AegisCrypto
@testable import AegisStorage
import XCTest

final class AegisStorageTests: XCTestCase {

    /// Per-test unique service id. Set in setUp; the
    /// underlying AegisStorage.serviceIdentifier is restored
    /// in tearDown.
    private var testService: String = ""
    private var savedDefaultService: String = ""
    private var savedDefaultAccessibility: KeychainAccessibility =
        .afterFirstUnlockThisDeviceOnly

    override func setUp() {
        super.setUp()
        savedDefaultService = AegisStorage.serviceIdentifier
        savedDefaultAccessibility = AegisStorage.defaultAccessibility
        testService = "io.github.demigoddsk.aegis.tests.\(UUID().uuidString)"
        AegisStorage.serviceIdentifier = testService
        AegisStorage.defaultAccessibility = .whenUnlockedThisDeviceOnly
    }

    override func tearDown() {
        try? AegisStorage.purgeAll(serviceIdentifier: testService)
        AegisStorage.serviceIdentifier = savedDefaultService
        AegisStorage.defaultAccessibility = savedDefaultAccessibility
        super.tearDown()
    }

    // MARK: - Identity round-trip

    func testSaveAndLoad_roundTripsExactly() throws {
        let original = try IdentityKeyPair.generate()
        try AegisStorage.saveIdentity(original)

        let loaded = try XCTUnwrap(try AegisStorage.loadIdentity())
        XCTAssertEqual(loaded.signing.publicKey, original.signing.publicKey)
        XCTAssertEqual(loaded.signing.privateKey, original.signing.privateKey)
        XCTAssertEqual(loaded.dh.publicKey, original.dh.publicKey)
        XCTAssertEqual(loaded.dh.privateKey, original.dh.privateKey)
    }

    func testLoadBeforeSave_returnsNil() throws {
        XCTAssertNil(try AegisStorage.loadIdentity(),
                     "no identity has been saved; load must return nil rather than throwing")
    }

    func testSave_overwritesPriorIdentity() throws {
        let first = try IdentityKeyPair.generate()
        try AegisStorage.saveIdentity(first)
        let second = try IdentityKeyPair.generate()
        try AegisStorage.saveIdentity(second)

        let loaded = try XCTUnwrap(try AegisStorage.loadIdentity())
        XCTAssertEqual(loaded.signing.publicKey, second.signing.publicKey,
                       "save must replace, not duplicate")
        XCTAssertNotEqual(loaded.signing.publicKey, first.signing.publicKey)
    }

    // MARK: - Delete

    func testDelete_removesIdentity() throws {
        let id = try IdentityKeyPair.generate()
        try AegisStorage.saveIdentity(id)
        XCTAssertNotNil(try AegisStorage.loadIdentity())

        try AegisStorage.deleteIdentity()
        XCTAssertNil(try AegisStorage.loadIdentity())
    }

    func testDelete_isIdempotent() throws {
        // Calling delete on an empty store must not throw.
        XCTAssertNoThrow(try AegisStorage.deleteIdentity())
        XCTAssertNoThrow(try AegisStorage.deleteIdentity())
    }

    // MARK: - Service-namespace isolation

    func testServiceNamespace_isolatesIdentities() throws {
        let serviceA = "io.github.demigoddsk.aegis.tests.\(UUID().uuidString)"
        let serviceB = "io.github.demigoddsk.aegis.tests.\(UUID().uuidString)"

        AegisStorage.serviceIdentifier = serviceA
        let alice = try IdentityKeyPair.generate()
        try AegisStorage.saveIdentity(alice)

        AegisStorage.serviceIdentifier = serviceB
        XCTAssertNil(try AegisStorage.loadIdentity(),
                     "identity saved under serviceA must be invisible under serviceB")

        // Cleanup
        try AegisStorage.purgeAll(serviceIdentifier: serviceA)
        try AegisStorage.purgeAll(serviceIdentifier: serviceB)
    }

    // MARK: - Round trip preserves cryptographic usefulness

    func testRoundTrippedIdentity_canSignAndAgree() throws {
        let original = try IdentityKeyPair.generate()
        try AegisStorage.saveIdentity(original)
        let loaded = try XCTUnwrap(try AegisStorage.loadIdentity())

        // Signing keypair: a signature made by the loaded
        // private key must verify under the loaded public
        // key.
        let signer = MLDSA65Signature()
        let message = Data("after keychain round-trip".utf8)
        let sig = try signer.sign(message, with: loaded.signing.privateKey)
        XCTAssertTrue(
            try signer.isValidSignature(sig, of: message, by: loaded.signing.publicKey)
        )

        // DH keypair: shared secret with a peer must agree
        // both ways.
        let peer = X25519.generateKeyPair()
        let aliceSide = try X25519.sharedSecret(
            privateKey: loaded.dh.privateKey,
            peerPublicKey: peer.publicKey
        )
        let peerSide = try X25519.sharedSecret(
            privateKey: peer.privateKey,
            peerPublicKey: loaded.dh.publicKey
        )
        XCTAssertEqual(aliceSide, peerSide)
    }

    // MARK: - Accessibility override

    func testSave_acceptsExplicitAccessibilityOverride() throws {
        // The override doesn't have a observable side effect
        // we can assert on without poking deep into the
        // Keychain item attributes — but we at least confirm
        // the API surface exists and the call succeeds.
        let id = try IdentityKeyPair.generate()
        XCTAssertNoThrow(
            try AegisStorage.saveIdentity(id, accessibility: .whenPasscodeSetThisDeviceOnly)
        )
    }
}
