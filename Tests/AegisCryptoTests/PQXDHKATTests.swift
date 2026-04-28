// PQXDHKATTests.swift
// Frozen-input snapshot tests for the PQXDH HKDF combiner.
//
// `deriveSharedSecret(dh1:dh2:dh3:dh4:ssPq:)` is a pure
// function of its inputs (HKDF-SHA-256 over a deterministic
// concatenation). This file pins the output for known inputs.
// If Apple's HKDF-SHA-256 implementation, our 32-byte version
// hedge, the canonical concatenation order, the empty salt, or
// the `AEGIS_PQXDH_v1` info string ever drifts, these tests
// fail and the maintainer is alerted before any session would
// silently derive a different SK.
//
// We do NOT pin the output of an end-to-end `PQXDH.initiate /
// respond` cycle: ML-KEM-1024 encapsulation does not accept
// caller-supplied randomness through Apple's API, so each
// initiate produces a fresh ciphertext + shared-secret pair
// even from fixed identity / ephemeral seeds. The HKDF
// combiner is the largest deterministic surface we can pin
// without libsignal interop (see issue #10).

import CryptoKit
import XCTest
@testable import AegisCrypto

final class PQXDHKATTests: XCTestCase {

    // 32 bytes of distinct constant bytes per input — a
    // transposition bug (e.g. `dh1` and `dh2` swapped in the
    // concatenation) would change the output even though all
    // inputs are the "same" length.
    private static let dh1  = Data(repeating: 0x11, count: 32)
    private static let dh2  = Data(repeating: 0x22, count: 32)
    private static let dh3  = Data(repeating: 0x33, count: 32)
    private static let dh4  = Data(repeating: 0x44, count: 32)
    private static let ssPq = Data(repeating: 0x55, count: 32)

    /// Pinned SK for the (dh1, dh2, dh3, dh4, ssPq) inputs above.
    /// Captured on macOS 26.4 / Xcode 26.4.1 / Swift 6.3.1.
    /// If this constant ever needs to change, the comment block
    /// at the top of this file explains what that drift means.
    private static let expectedSK_withDH4 =
        "7a69c5d42389da9df4fc3376d4ee701ffee7be7b46db7025fb8c7396726a7417"

    /// Pinned SK for the (dh1, dh2, dh3, ssPq) inputs above
    /// (no DH4). Distinct from the with-DH4 case.
    private static let expectedSK_withoutDH4 =
        "5e50be0f93a6dd79017e6a79d371ef982de1cfabd20203013098b7c4230e535e"

    // MARK: - Snapshot tests

    func testPinnedSnapshot_withDH4() {
        let sk = PQXDH.deriveSharedSecret(
            dh1: Self.dh1, dh2: Self.dh2, dh3: Self.dh3,
            dh4: Self.dh4, ssPq: Self.ssPq
        )
        let hex = sk.map { String(format: "%02x", $0) }.joined()
        XCTAssertEqual(hex, Self.expectedSK_withDH4,
                       "PQXDH HKDF output drift (with DH4)")
    }

    func testPinnedSnapshot_withoutDH4() {
        let sk = PQXDH.deriveSharedSecret(
            dh1: Self.dh1, dh2: Self.dh2, dh3: Self.dh3,
            dh4: nil, ssPq: Self.ssPq
        )
        let hex = sk.map { String(format: "%02x", $0) }.joined()
        XCTAssertEqual(hex, Self.expectedSK_withoutDH4,
                       "PQXDH HKDF output drift (without DH4)")
    }

    // MARK: - Side-checks (sanity)

    func testSnapshotShape() {
        let sk = PQXDH.deriveSharedSecret(
            dh1: Self.dh1, dh2: Self.dh2, dh3: Self.dh3,
            dh4: Self.dh4, ssPq: Self.ssPq
        )
        XCTAssertEqual(sk.count, 32, "PQXDH SK is always 32 bytes")
    }

    func testSnapshot_isInputOrderSensitive() {
        // Swapping dh1 and dh2 must change the output, even
        // though both are "the same length and shape" inputs.
        // Catches a class of refactor bug where the
        // concatenation order accidentally changes.
        let canonical = PQXDH.deriveSharedSecret(
            dh1: Self.dh1, dh2: Self.dh2, dh3: Self.dh3,
            dh4: Self.dh4, ssPq: Self.ssPq
        )
        let swapped = PQXDH.deriveSharedSecret(
            dh1: Self.dh2, dh2: Self.dh1, dh3: Self.dh3,
            dh4: Self.dh4, ssPq: Self.ssPq
        )
        XCTAssertNotEqual(canonical, swapped)
    }
}
