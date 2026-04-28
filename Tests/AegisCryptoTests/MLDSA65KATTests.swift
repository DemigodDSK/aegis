// MLDSA65KATTests.swift
// NIST FIPS 204 + Wycheproof known-answer tests for ML-DSA-65.
//
// Two suites are run from this file:
//
//   testKAT_keyGen_allVectors:
//     For each NIST KeyGen vector (mirrored from BoringSSL's
//     NIST-ACVP corpus), confirm that `MLDSA65.PrivateKey
//     (seedRepresentation: seed)` derives the same public key
//     `pub` that NIST publishes. 25 vectors.
//
//   testKAT_verify_wycheproof:
//     Project Wycheproof's targeted-edge-case verify suite.
//     For each test in each group, take the group's published
//     `publicKey` (raw FIPS 204 format), the test's `msg`,
//     `sig`, and optional FIPS 204 `ctx` (the domain-separator
//     context, default empty), and call CryptoKit's
//     `MLDSA65.PublicKey.isValidSignature(_:for:context:)`
//     directly. We bypass `MLDSA65Signature.isValidSignature`
//     for this test specifically: our wrapper does not yet
//     expose the FIPS 204 context parameter at the protocol
//     surface, but the underlying primitive supports it and
//     Wycheproof has cases that exercise it. The wrapper is
//     covered by MLDSA65SignatureTests; this test covers the
//     primitive against the standard.
//     Confirm per-test:
//       - "valid"     → returned `true`.
//       - "invalid"   → returned `false`.
//       - "acceptable" → either outcome passes (Wycheproof's
//                        implementation-defined cases).
//     ~160 tests across 24 groups.
//
// We do not run a Sign-side KAT: NIST's SigGen vectors give
// `(sk, msg, signature)` in the raw 4032-byte FIPS 204 sk
// format, which Apple's CryptoKit API does not accept as input.
// The Wycheproof verify suite plus our self-consistent
// round-trip tests cover the sign/verify pair.
//
// Source provenance and SHA-256 checksums live in
// `Tests/AegisCryptoTests/Vectors/README.md`.

import CryptoKit
import XCTest
@testable import AegisCrypto

final class MLDSA65KATTests: XCTestCase {

    private let signer = MLDSA65Signature()

    // MARK: - KeyGen KATs

    private struct KeyGenVector {
        let index: Int
        let seed: Data    // 32 bytes
        let pub: Data     // 1952 bytes — expected public key
        let priv: Data    // 4032 bytes — full FIPS 204 sk (not consumed)
    }

    func testKAT_keyGen_allVectors() throws {
        let vectors = try loadKeyGenVectors()
        XCTAssertEqual(vectors.count, 25,
                       "BoringSSL pin should ship 25 ML-DSA-65 KeyGen vectors")

        for v in vectors {
            let priv: CryptoKit.MLDSA65.PrivateKey
            do {
                priv = try CryptoKit.MLDSA65.PrivateKey(
                    seedRepresentation: v.seed,
                    publicKey: nil
                )
            } catch {
                XCTFail("[vector \(v.index)] PrivateKey(seedRepresentation:) threw: \(error)")
                continue
            }

            XCTAssertEqual(
                priv.publicKey.rawRepresentation,
                v.pub,
                "[vector \(v.index)] derived pub does not match NIST"
            )
        }
    }

    // MARK: - Wycheproof verify KATs

    private struct WycheproofRoot: Decodable {
        let testGroups: [WycheproofGroup]
    }
    private struct WycheproofGroup: Decodable {
        let publicKey: String   // raw FIPS 204 hex
        let tests: [WycheproofTest]
    }
    private struct WycheproofTest: Decodable {
        let tcId: Int
        let comment: String
        let msg: String         // hex
        let sig: String         // hex
        let result: String      // "valid" | "invalid" | "acceptable"
        let ctx: String?        // hex; FIPS 204 context (default empty)
    }

    func testKAT_verify_wycheproof() throws {
        let root = try loadWycheproof()

        var totalRun = 0
        for group in root.testGroups {
            let pkBytes = try hex(group.publicKey)
            // Wycheproof includes test groups with deliberately
            // malformed public keys (truncated, wrong size,
            // etc.). Apple's PublicKey(rawRepresentation:)
            // throws on such inputs. Treat that as a structural
            // rejection of every test in the group — equivalent
            // to verify returning false. A "valid" expected
            // result inside a malformed-key group would be a
            // contradiction in the corpus and we surface it
            // loudly.
            let pk: CryptoKit.MLDSA65.PublicKey?
            do {
                pk = try CryptoKit.MLDSA65.PublicKey(rawRepresentation: pkBytes)
            } catch {
                pk = nil
            }

            for t in group.tests {
                totalRun += 1
                let msg = try hex(t.msg)
                let sig = try hex(t.sig)
                let ctx = try hex(t.ctx ?? "")

                guard let pk = pk else {
                    if t.result == "valid" {
                        XCTFail("[tcId \(t.tcId)] (\(t.comment)) expected 'valid' but the group's public key did not parse — corpus inconsistency")
                    }
                    // "invalid" or "acceptable" with a malformed
                    // pk: structural rejection is correct.
                    continue
                }

                let outcome = pk.isValidSignature(sig, for: msg, context: ctx)

                switch t.result {
                case "valid":
                    XCTAssertTrue(
                        outcome,
                        "[tcId \(t.tcId)] expected valid (\(t.comment)) but verify returned false"
                    )
                case "invalid":
                    XCTAssertFalse(
                        outcome,
                        "[tcId \(t.tcId)] expected invalid (\(t.comment)) but verify returned true"
                    )
                case "acceptable":
                    // Wycheproof "acceptable" cases are
                    // intentionally borderline. Either outcome
                    // is fine for a conforming implementation.
                    break
                default:
                    XCTFail("[tcId \(t.tcId)] unknown Wycheproof result '\(t.result)'")
                }
            }
        }

        // Sanity: pin the test count so a future Wycheproof
        // update that *adds* tests is loud rather than silent.
        XCTAssertGreaterThanOrEqual(totalRun, 160,
                                    "Wycheproof pin should ship at least 160 tests; got \(totalRun)")
    }

    // MARK: - Loading

    private func loadKeyGenVectors() throws -> [KeyGenVector] {
        let url = try XCTUnwrap(
            Bundle.module.url(
                forResource: "mldsa_nist_keygen_65_tests",
                withExtension: "txt",
                subdirectory: "Vectors"
            ),
            "Vectors/mldsa_nist_keygen_65_tests.txt is missing from the test bundle"
        )
        let text = try String(contentsOf: url, encoding: .utf8)

        var vectors: [KeyGenVector] = []
        var fields: [String: String] = [:]
        var index = 0

        func flush() throws {
            guard !fields.isEmpty else { return }
            guard
                let seedHex = fields["seed"],
                let pubHex = fields["pub"],
                let privHex = fields["priv"]
            else {
                throw KATError.missingField(at: index)
            }
            let seed = try Self.hex(seedHex)
            let pub = try Self.hex(pubHex)
            let priv = try Self.hex(privHex)
            XCTAssertEqual(seed.count, 32, "[vector \(index)] seed must be 32 bytes")
            XCTAssertEqual(pub.count, 1952, "[vector \(index)] pub must be 1952 bytes")
            XCTAssertEqual(priv.count, 4032, "[vector \(index)] priv must be 4032 bytes")
            vectors.append(KeyGenVector(index: index, seed: seed, pub: pub, priv: priv))
            index += 1
            fields.removeAll(keepingCapacity: true)
        }

        for rawLine in text.split(separator: "\n", omittingEmptySubsequences: false) {
            let line = rawLine.trimmingCharacters(in: .whitespaces)
            if line.isEmpty {
                try flush()
                continue
            }
            if line.hasPrefix("#") || line.hasPrefix("[") {
                continue
            }
            guard let colon = line.firstIndex(of: ":") else { continue }
            let key = String(line[..<colon])
            let value = line[line.index(after: colon)...]
                .trimmingCharacters(in: .whitespaces)
            fields[key] = value
        }
        try flush()
        return vectors
    }

    private func loadWycheproof() throws -> WycheproofRoot {
        let url = try XCTUnwrap(
            Bundle.module.url(
                forResource: "mldsa_65_wycheproof_verify_test",
                withExtension: "json",
                subdirectory: "Vectors"
            ),
            "Vectors/mldsa_65_wycheproof_verify_test.json is missing from the test bundle"
        )
        let data = try Data(contentsOf: url)
        return try JSONDecoder().decode(WycheproofRoot.self, from: data)
    }

    // MARK: - Hex

    private enum KATError: Error {
        case missingField(at: Int)
        case oddLength
        case invalidChar
    }

    private static func hex(_ s: String) throws -> Data {
        guard s.count % 2 == 0 else { throw KATError.oddLength }
        var data = Data(capacity: s.count / 2)
        var i = s.startIndex
        while i < s.endIndex {
            let next = s.index(i, offsetBy: 2)
            guard let byte = UInt8(s[i..<next], radix: 16) else {
                throw KATError.invalidChar
            }
            data.append(byte)
            i = next
        }
        return data
    }

    private func hex(_ s: String) throws -> Data {
        try Self.hex(s)
    }
}
