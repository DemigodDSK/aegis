// MLKEM768KATTests.swift
// NIST FIPS 203 known-answer tests for ML-KEM-768.
//
// Source: vetted NIST ACVP vectors, mirrored verbatim from
// BoringSSL's `crypto/mlkem/mlkem768_nist_keygen_tests.txt`. See
// `Tests/AegisCryptoTests/Vectors/README.md` for pinned commit
// hashes and SHA-256 checksums.
//
// What we verify here: KeyGen — given the FIPS 203 seed
// `(d, z)`, Apple's CryptoKit `MLKEM768.PrivateKey` derives the
// same encapsulation key (`ek`) that NIST publishes.
//
// What we deliberately skip:
//   - Decap KATs: the NIST decap files publish raw 2400-byte
//     `dk` representations. CryptoKit's
//     `MLKEM768.PrivateKey.init(integrityCheckedRepresentation:)`
//     expects a 96-byte seed+HMAC form, not the raw dk, so we
//     cannot load NIST's dk into Apple's API. The KeyGen KAT is
//     however necessary-and-sufficient evidence that the
//     underlying KEM agrees with the standard: a divergent
//     KeyGen would invalidate every subsequent operation.
//   - Encap KATs: Apple does not expose a randomness-injection
//     interface on `encapsulate()`, so deterministic encap
//     KATs are not runnable.
//
// If a future macOS / Xcode update changes ML-KEM-768 behaviour
// in any way that alters the (d, z) → ek derivation, these tests
// fail and the maintainer is alerted before HybridKEM can
// silently drift.

import CryptoKit
import XCTest
@testable import AegisCrypto

final class MLKEM768KATTests: XCTestCase {

    /// One NIST KeyGen KAT vector. Bytes are stored as raw `Data`
    /// after parsing the BoringSSL hex format.
    private struct KeyGenVector {
        let index: Int   // 0-based, for diagnostics
        let z: Data      // 32 bytes
        let d: Data      // 32 bytes
        let ek: Data     // 1184 bytes — expected encapsulation key
        let dk: Data     // 2400 bytes — expected decapsulation key (unused; see file header)
    }

    // MARK: - Tests

    func testKAT_keyGen_allVectors() throws {
        let vectors = try loadKeyGenVectors()
        XCTAssertEqual(vectors.count, 25,
                       "BoringSSL pin should ship 25 KeyGen vectors; if this drifts, update the pin and the README")

        for v in vectors {
            // FIPS 203 seed format is d || z. CryptoKit's
            // seedRepresentation accepts the same layout (probed
            // empirically against vector 0 during Sprint 2).
            let seed = v.d + v.z
            let priv: MLKEM768.PrivateKey
            do {
                priv = try MLKEM768.PrivateKey(seedRepresentation: seed, publicKey: nil)
            } catch {
                XCTFail("[vector \(v.index)] PrivateKey(seedRepresentation:) threw: \(error)")
                continue
            }

            XCTAssertEqual(
                priv.publicKey.rawRepresentation,
                v.ek,
                "[vector \(v.index)] derived ek does not match NIST"
            )
        }
    }

    // MARK: - Parsing

    /// Parse BoringSSL's flat-key/value KAT file format:
    ///
    /// ```
    /// z: HEX
    /// d: HEX
    /// ek: HEX
    /// dk: HEX
    ///
    /// z: HEX
    /// ...
    /// ```
    ///
    /// Blank lines separate vectors. Comment lines starting with
    /// `#` (if any) are ignored.
    private func loadKeyGenVectors() throws -> [KeyGenVector] {
        let url = try XCTUnwrap(
            Bundle.module.url(
                forResource: "mlkem768_nist_keygen_tests",
                withExtension: "txt",
                subdirectory: "Vectors"
            ),
            "Vectors/mlkem768_nist_keygen_tests.txt is missing from the test bundle"
        )
        let text = try String(contentsOf: url, encoding: .utf8)

        var vectors: [KeyGenVector] = []
        var fields: [String: String] = [:]
        var index = 0

        func flush() throws {
            guard !fields.isEmpty else { return }
            guard
                let zHex = fields["z"],
                let dHex = fields["d"],
                let ekHex = fields["ek"],
                let dkHex = fields["dk"]
            else {
                throw KATError.missingField(at: index)
            }
            let z = try Self.hex(zHex)
            let d = try Self.hex(dHex)
            let ek = try Self.hex(ekHex)
            let dk = try Self.hex(dkHex)
            XCTAssertEqual(z.count, 32,  "[vector \(index)] z must be 32 bytes")
            XCTAssertEqual(d.count, 32,  "[vector \(index)] d must be 32 bytes")
            XCTAssertEqual(ek.count, 1184, "[vector \(index)] ek must be 1184 bytes")
            XCTAssertEqual(dk.count, 2400, "[vector \(index)] dk must be 2400 bytes")
            vectors.append(KeyGenVector(index: index, z: z, d: d, ek: ek, dk: dk))
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
                // Comment or group header; ignore.
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
}
