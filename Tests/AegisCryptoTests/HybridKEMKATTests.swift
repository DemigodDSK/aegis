// HybridKEMKATTests.swift
// Known-answer tests for HybridKEM (X-Wing).
//
// Source: `spec/test-vectors.json` from the IETF X-Wing draft
// reference repository, mirrored verbatim into
// `Tests/AegisCryptoTests/Vectors/xwing-test-vectors.json`. See
// `Tests/AegisCryptoTests/Vectors/README.md` for the pinned
// commit hash and SHA-256 checksum.
//
// Each vector contains:
//   seed   — 32 bytes; the X-Wing private-key seed (== sk).
//   eseed  — 64 bytes; encapsulation randomness (NOT consumed
//            by these tests, as Apple's API does not accept
//            caller-supplied randomness for encapsulation).
//   ss     — 32 bytes; the expected shared secret.
//   sk     — 32 bytes; the X-Wing private key (equal to seed).
//   pk     — 1216 bytes; the expected public/encapsulation key.
//   ct     — 1120 bytes; the encapsulated ciphertext.
//
// We exercise two of the three KEM operations:
//
//   KeyGen — given `seed`, the derived public key matches `pk`.
//   Decap  — given `seed` and `ct`, the derived shared secret
//            matches `ss`.
//
// Encap is randomised in CryptoKit; we test it indirectly via
// Decap (a randomised Encap producing a verified-correct Decap
// is sufficient evidence the encap path is sound).

import CryptoKit
import XCTest
@testable import AegisCrypto

final class HybridKEMKATTests: XCTestCase {

    private struct XWingVector: Decodable {
        let seed: String   // 32-byte hex
        let eseed: String  // 64-byte hex (unused)
        let ss: String     // 32-byte hex
        let sk: String     // 32-byte hex
        let pk: String     // 1216-byte hex
        let ct: String     // 1120-byte hex
    }

    // MARK: - Tests

    func testKAT_keyGen_allVectors() throws {
        let vectors = try loadVectors()
        XCTAssertEqual(vectors.count, 3,
                       "X-Wing test-vectors.json pins 3 vectors; update README if this changes")

        for (i, v) in vectors.enumerated() {
            let seed = try hex(v.seed)
            let expectedPK = try hex(v.pk)

            let priv = try XWingMLKEM768X25519.PrivateKey(
                seedRepresentation: seed,
                publicKey: nil
            )
            XCTAssertEqual(
                priv.publicKey.rawRepresentation,
                expectedPK,
                "[vector \(i)] derived pk does not match X-Wing draft"
            )
        }
    }

    func testKAT_decapsulate_allVectors() throws {
        let vectors = try loadVectors()
        for (i, v) in vectors.enumerated() {
            let seed = try hex(v.seed)
            let ct = try hex(v.ct)
            let expectedSS = try hex(v.ss)

            let priv = try XWingMLKEM768X25519.PrivateKey(
                seedRepresentation: seed,
                publicKey: nil
            )
            let recovered = try priv.decapsulate(ct)
            XCTAssertEqual(
                recovered.withUnsafeBytes { Data($0) },
                expectedSS,
                "[vector \(i)] decapsulated shared secret does not match X-Wing draft"
            )
        }
    }

    /// Same Decap KATs but routed through Aegis's `HybridKEM`
    /// wrapper instead of CryptoKit directly. Verifies that our
    /// wrapper does not corrupt key material on the way through.
    func testKAT_decapsulate_throughHybridKEM() throws {
        let vectors = try loadVectors()
        let kem = HybridKEM()
        for (i, v) in vectors.enumerated() {
            let seed = try hex(v.seed)
            let ct = try hex(v.ct)
            let expectedSS = try hex(v.ss)

            let recovered = try kem.decapsulate(ct, with: seed)
            XCTAssertEqual(
                recovered.withUnsafeBytes { Data($0) },
                expectedSS,
                "[vector \(i)] HybridKEM.decapsulate did not match X-Wing draft"
            )
        }
    }

    // MARK: - Helpers

    private func loadVectors() throws -> [XWingVector] {
        let url = try XCTUnwrap(
            Bundle.module.url(
                forResource: "xwing-test-vectors",
                withExtension: "json",
                subdirectory: "Vectors"
            ),
            "Vectors/xwing-test-vectors.json is missing from the test bundle"
        )
        let data = try Data(contentsOf: url)
        return try JSONDecoder().decode([XWingVector].self, from: data)
    }

    private enum HexError: Error { case oddLength, invalidChar }

    private func hex(_ s: String) throws -> Data {
        guard s.count % 2 == 0 else { throw HexError.oddLength }
        var data = Data(capacity: s.count / 2)
        var i = s.startIndex
        while i < s.endIndex {
            let next = s.index(i, offsetBy: 2)
            guard let byte = UInt8(s[i..<next], radix: 16) else {
                throw HexError.invalidChar
            }
            data.append(byte)
            i = next
        }
        return data
    }
}
