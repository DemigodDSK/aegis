// CapabilityTests.swift
// Sanity tests for the Capability list that drives Settings
// → Security. The list is hand-mirrored from THREAT-MODEL.md;
// these tests catch a subset of drift between the document
// and the in-app rendering.

@testable import AegisApp
import XCTest

final class CapabilityTests: XCTestCase {

    // MARK: - List shape

    func testAll_isNonEmpty() {
        XCTAssertFalse(Capability.all.isEmpty)
    }

    func testAll_idsAreUnique() {
        let ids = Capability.all.map(\.id)
        XCTAssertEqual(
            Set(ids).count, ids.count,
            "duplicate capability id breaks Identifiable; check Capability.all"
        )
    }

    func testAll_titlesAreNonEmpty() {
        for cap in Capability.all {
            XCTAssertFalse(cap.title.isEmpty,
                           "capability \(cap.id) has empty title")
            XCTAssertFalse(cap.detail.isEmpty,
                           "capability \(cap.id) has empty detail")
        }
    }

    // MARK: - Status content

    func testAll_plannedForStatuses_haveNonEmptyTargets() {
        for cap in Capability.all {
            if case .plannedFor(let target) = cap.status {
                XCTAssertFalse(
                    target.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
                    "[\(cap.id)] .plannedFor must name a target version"
                )
            }
        }
    }

    func testAll_partialStatuses_haveNonEmptyNotes() {
        for cap in Capability.all {
            if case .partial(let note) = cap.status {
                XCTAssertFalse(
                    note.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
                    "[\(cap.id)] .partial must explain the limitation"
                )
            }
        }
    }

    // MARK: - Coverage spot-checks (drift detection)

    func testAll_includes_aes256Gcm() {
        XCTAssertTrue(
            Capability.all.contains(where: {
                $0.id == "aead.aes-256-gcm" && $0.status == .shipped
            }),
            "AES-256-GCM is shipped since Sprint 1; missing from capability list"
        )
    }

    func testAll_includes_pqxdh() {
        XCTAssertTrue(
            Capability.all.contains(where: {
                $0.id == "session.pqxdh" && $0.status == .shipped
            }),
            "PQXDH is shipped since Sprint 4; missing from capability list"
        )
    }

    func testAll_includes_doubleRatchet() {
        XCTAssertTrue(
            Capability.all.contains(where: {
                $0.id == "session.forward-secrecy" && $0.status == .shipped
            }),
            "Forward secrecy / Double Ratchet is shipped since Sprint 5; missing from capability list"
        )
    }

    func testAll_includes_networkingPlanned() {
        let found = Capability.all.contains { cap in
            guard cap.id == "transport.network" else { return false }
            if case .plannedFor = cap.status { return true }
            return false
        }
        XCTAssertTrue(
            found,
            "Network transport must appear with .plannedFor status — Sprint 8"
        )
    }
}
