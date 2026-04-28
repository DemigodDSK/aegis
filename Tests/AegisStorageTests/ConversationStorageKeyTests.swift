// ConversationStorageKeyTests.swift
// Per-test service-namespace isolation; each test reserves a
// UUID-stamped serviceIdentifier so concurrent runs don't
// collide. Cleanup purges the per-test service in tearDown.

import AegisCrypto
@testable import AegisStorage
import CryptoKit
import Foundation
import XCTest

final class ConversationStorageKeyTests: XCTestCase {

    private var testService: String = ""
    private var savedService: String = ""

    override func setUp() {
        super.setUp()
        savedService = AegisStorage.serviceIdentifier
        testService = "io.github.demigoddsk.aegis.tests.\(UUID().uuidString)"
        AegisStorage.serviceIdentifier = testService
    }

    override func tearDown() {
        try? AegisStorage.purgeAll(serviceIdentifier: testService)
        AegisStorage.serviceIdentifier = savedService
        super.tearDown()
    }

    // MARK: - Provision / load

    func testProvision_returnsAUsableKey() throws {
        let id = UUID()
        let key = try ConversationStorageKey.provision(for: id)
        XCTAssertEqual(key.bitCount, 256)
        // Round-trip via AES-GCM as a sanity check that the
        // bytes are usable as a 256-bit key.
        let payload = try AESGCM().encrypt(Data("ping".utf8), key: key)
        XCTAssertEqual(try AESGCM().decrypt(payload, key: key), Data("ping".utf8))
    }

    func testLoad_returnsTheProvisionedKey() throws {
        let id = UUID()
        let provisioned = try ConversationStorageKey.provision(for: id)
        let loaded = try XCTUnwrap(try ConversationStorageKey.load(for: id))

        let provBytes = provisioned.withUnsafeBytes { Data($0) }
        let loadBytes = loaded.withUnsafeBytes { Data($0) }
        XCTAssertEqual(provBytes, loadBytes)
    }

    func testLoadBeforeProvision_returnsNil() throws {
        let id = UUID()
        XCTAssertNil(try ConversationStorageKey.load(for: id))
    }

    // MARK: - Delete

    func testDelete_removesTheKey() throws {
        let id = UUID()
        _ = try ConversationStorageKey.provision(for: id)
        XCTAssertNotNil(try ConversationStorageKey.load(for: id))

        try ConversationStorageKey.delete(for: id)
        XCTAssertNil(try ConversationStorageKey.load(for: id))
    }

    func testDelete_isIdempotent() throws {
        let id = UUID()
        XCTAssertNoThrow(try ConversationStorageKey.delete(for: id))
        XCTAssertNoThrow(try ConversationStorageKey.delete(for: id))
    }

    // MARK: - Per-conversation isolation

    func testProvision_eachConversationGetsADistinctKey() throws {
        let a = UUID()
        let b = UUID()
        let keyA = try ConversationStorageKey.provision(for: a)
        let keyB = try ConversationStorageKey.provision(for: b)

        let bytesA = keyA.withUnsafeBytes { Data($0) }
        let bytesB = keyB.withUnsafeBytes { Data($0) }
        XCTAssertNotEqual(bytesA, bytesB,
                          "two fresh provision calls must produce distinct keys")
    }

    func testProvision_overwritesPriorKeyForSameConversation() throws {
        let id = UUID()
        let first = try ConversationStorageKey.provision(for: id)
        let second = try ConversationStorageKey.provision(for: id)

        let firstBytes = first.withUnsafeBytes { Data($0) }
        let secondBytes = second.withUnsafeBytes { Data($0) }
        XCTAssertNotEqual(firstBytes, secondBytes,
                          "re-provision must rotate the key, not return the old one")

        let loaded = try XCTUnwrap(try ConversationStorageKey.load(for: id))
        let loadedBytes = loaded.withUnsafeBytes { Data($0) }
        XCTAssertEqual(loadedBytes, secondBytes,
                       "load after re-provision must return the most recent key")
    }
}
