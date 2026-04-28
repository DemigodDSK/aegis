// SafetyNumberTests.swift
// Tests for the SafetyNumber numeric-fingerprint construction.

import CryptoKit
import XCTest
@testable import AegisCrypto

final class SafetyNumberTests: XCTestCase {

    // MARK: - Format

    func testFormat_isTwelveGroupsOfFiveDigits() throws {
        let alice = try IdentityKeyPair.generate()
        let bob = try IdentityKeyPair.generate()
        let n = SafetyNumber.compute(local: alice.publicKey, remote: bob.publicKey)

        let groups = n.split(separator: " ").map(String.init)
        XCTAssertEqual(groups.count, 12, "must have 12 groups")
        for group in groups {
            XCTAssertEqual(group.count, 5, "each group must be 5 digits")
            XCTAssertTrue(group.allSatisfy(\.isNumber),
                          "each group must be all digits, got: \(group)")
        }
    }

    func testFormat_separatedBySingleSpace() throws {
        let alice = try IdentityKeyPair.generate()
        let bob = try IdentityKeyPair.generate()
        let n = SafetyNumber.compute(local: alice.publicKey, remote: bob.publicKey)
        // 12 groups × 5 digits + 11 spaces = 71 characters.
        XCTAssertEqual(n.count, 71)
    }

    // MARK: - Order independence

    func testCompute_isOrderIndependent() throws {
        let alice = try IdentityKeyPair.generate()
        let bob = try IdentityKeyPair.generate()
        let aliceComputes = SafetyNumber.compute(
            local: alice.publicKey,
            remote: bob.publicKey
        )
        let bobComputes = SafetyNumber.compute(
            local: bob.publicKey,
            remote: alice.publicKey
        )
        XCTAssertEqual(aliceComputes, bobComputes,
                       "Alice and Bob must derive the same safety number")
    }

    // MARK: - Determinism

    func testCompute_isDeterministic() throws {
        let alice = try IdentityKeyPair.generate()
        let bob = try IdentityKeyPair.generate()
        let n1 = SafetyNumber.compute(local: alice.publicKey, remote: bob.publicKey)
        let n2 = SafetyNumber.compute(local: alice.publicKey, remote: bob.publicKey)
        XCTAssertEqual(n1, n2)
    }

    // MARK: - Distinctness

    func testCompute_distinctIdentitiesGiveDistinctNumbers() throws {
        let alice = try IdentityKeyPair.generate()
        let bob = try IdentityKeyPair.generate()
        let charlie = try IdentityKeyPair.generate()

        let aliceBob = SafetyNumber.compute(
            local: alice.publicKey, remote: bob.publicKey
        )
        let aliceCharlie = SafetyNumber.compute(
            local: alice.publicKey, remote: charlie.publicKey
        )
        XCTAssertNotEqual(aliceBob, aliceCharlie,
                          "different remote identity must yield different number")
    }

    func testCompute_changesWhenSigningKeyChanges() throws {
        let bob = try IdentityKeyPair.generate()
        let alice1 = try IdentityKeyPair.generate()
        // Forge an "alice2" with the same DH key but a fresh
        // signing key. The safety number must reflect the
        // signing-key change — otherwise an attacker could
        // swap the signing component without detection.
        let alice2 = IdentityKeyPair(
            signing: try MLDSA65Signature().generateKeyPair(),
            dh: alice1.dh
        )
        let n1 = SafetyNumber.compute(local: alice1.publicKey, remote: bob.publicKey)
        let n2 = SafetyNumber.compute(local: alice2.publicKey, remote: bob.publicKey)
        XCTAssertNotEqual(n1, n2)
    }

    func testCompute_changesWhenDHKeyChanges() throws {
        let bob = try IdentityKeyPair.generate()
        let alice1 = try IdentityKeyPair.generate()
        let alice2 = IdentityKeyPair(
            signing: alice1.signing,
            dh: X25519.generateKeyPair()
        )
        let n1 = SafetyNumber.compute(local: alice1.publicKey, remote: bob.publicKey)
        let n2 = SafetyNumber.compute(local: alice2.publicKey, remote: bob.publicKey)
        XCTAssertNotEqual(n1, n2,
                          "DH-key swap must change the safety number")
    }

    // MARK: - Constants pinning

    func testConstants_pinnedFormat() {
        XCTAssertEqual(SafetyNumber.digitCount, 60)
        XCTAssertEqual(SafetyNumber.groupCount, 12)
        XCTAssertEqual(SafetyNumber.digitsPerGroup, 5)
        XCTAssertEqual(SafetyNumber.iterationCount, 5200)
    }
}
