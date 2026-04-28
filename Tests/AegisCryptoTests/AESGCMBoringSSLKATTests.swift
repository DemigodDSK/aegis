// AESGCMBoringSSLKATTests.swift
// Extended AES-256-GCM known-answer-test coverage from
// BoringSSL's AEAD test corpus.
//
// `AESGCMKATTests.swift` ships 5 hand-transcribed NIST CAVP
// vectors as a fast-feedback safety net (no file I/O, runs in
// microseconds). This file augments that with 66 vectors
// pulled verbatim from BoringSSL's `aes_256_gcm_tests.txt`,
// covering a much wider range of plaintext / AAD shapes
// (empty, short, long, mixed). See
// `Tests/AegisCryptoTests/Vectors/README.md` for the pinned
// commit hash and SHA-256.
//
// Resolves issue #2 (expand AES-GCM KAT coverage from
// BoringSSL test data).

import CryptoKit
import XCTest
@testable import AegisCrypto

final class AESGCMBoringSSLKATTests: XCTestCase {

    private let aes = AESGCM()

    private struct Vector {
        let lineNumber: Int   // location in the source file, for diagnostics
        let key: Data         // 32 bytes (AES-256)
        let nonce: Data       // 12 bytes
        let plaintext: Data
        let ad: Data
        let ciphertext: Data
        let tag: Data         // 16 bytes
    }

    // MARK: - Tests

    func testKAT_encryption_allVectors() throws {
        let vectors = try loadVectors()
        XCTAssertGreaterThanOrEqual(
            vectors.count, 60,
            "BoringSSL pin should ship at least 60 vectors; got \(vectors.count)"
        )

        for v in vectors {
            let key = SymmetricKey(data: v.key)
            let nonce: AES.GCM.Nonce
            do {
                nonce = try AES.GCM.Nonce(data: v.nonce)
            } catch {
                XCTFail("[line \(v.lineNumber)] could not parse nonce: \(error)")
                continue
            }

            let aad: Data? = v.ad.isEmpty ? nil : v.ad
            let payload: EncryptedPayload
            do {
                payload = try aes.encrypt(
                    v.plaintext, key: key, nonce: nonce, additionalData: aad
                )
            } catch {
                XCTFail("[line \(v.lineNumber)] encrypt threw: \(error)")
                continue
            }

            XCTAssertEqual(
                payload.ciphertext, v.ciphertext,
                "[line \(v.lineNumber)] ciphertext mismatch"
            )
            XCTAssertEqual(
                payload.tag, v.tag,
                "[line \(v.lineNumber)] tag mismatch"
            )
        }
    }

    func testKAT_decryption_allVectors() throws {
        let vectors = try loadVectors()
        for v in vectors {
            let key = SymmetricKey(data: v.key)
            let aad: Data? = v.ad.isEmpty ? nil : v.ad
            let payload = EncryptedPayload(
                methodId: AESGCM.methodId,
                nonce: v.nonce,
                ciphertext: v.ciphertext,
                tag: v.tag,
                additionalData: aad
            )

            let recovered: Data
            do {
                recovered = try aes.decrypt(payload, key: key)
            } catch {
                XCTFail("[line \(v.lineNumber)] decrypt threw: \(error)")
                continue
            }

            XCTAssertEqual(
                recovered, v.plaintext,
                "[line \(v.lineNumber)] decrypted plaintext mismatch"
            )
        }
    }

    // MARK: - Parsing
    //
    // BoringSSL's `aes_256_gcm_tests.txt` format:
    //
    //   # Comment lines start with `#` and are ignored.
    //
    //   KEY: hex
    //   NONCE: hex
    //   IN: hex
    //   AD: hex
    //   CT: hex
    //   TAG: hex
    //
    //   KEY: hex
    //   ...
    //
    // Empty lines separate vectors; empty hex values (e.g.
    // `IN: `) are valid and represent zero-byte fields.

    private func loadVectors() throws -> [Vector] {
        let url = try XCTUnwrap(
            Bundle.module.url(
                forResource: "aes_256_gcm_tests",
                withExtension: "txt",
                subdirectory: "Vectors"
            ),
            "Vectors/aes_256_gcm_tests.txt is missing from the test bundle"
        )
        let text = try String(contentsOf: url, encoding: .utf8)

        var vectors: [Vector] = []
        var fields: [String: String] = [:]
        var anchorLine = 1
        var lineNum = 0

        func flush() throws {
            guard !fields.isEmpty else { return }
            guard
                let keyHex = fields["KEY"],
                let nonceHex = fields["NONCE"],
                let inHex = fields["IN"],
                let adHex = fields["AD"],
                let ctHex = fields["CT"],
                let tagHex = fields["TAG"]
            else {
                throw KATError.missingField(at: anchorLine)
            }
            let key = try Self.hex(keyHex)
            let nonce = try Self.hex(nonceHex)
            let plaintext = try Self.hex(inHex)
            let ad = try Self.hex(adHex)
            let ciphertext = try Self.hex(ctHex)
            let tag = try Self.hex(tagHex)

            // BoringSSL's corpus includes one vector at the
            // bottom that exercises AES-GCM with a non-standard
            // 92-byte nonce — testing GHASH-based nonce
            // derivation, which our wrapper deliberately does
            // not support (we pin nonces to 96 bits per RFC
            // 5116). Skip such vectors quietly rather than
            // failing the suite.
            guard nonce.count == 12 else { return }

            XCTAssertEqual(key.count, 32, "[line \(anchorLine)] AES-256 key must be 32 bytes")
            XCTAssertEqual(tag.count, 16, "[line \(anchorLine)] AES-GCM tag must be 16 bytes")
            XCTAssertEqual(
                ciphertext.count, plaintext.count,
                "[line \(anchorLine)] CT and IN must match in length"
            )

            vectors.append(Vector(
                lineNumber: anchorLine,
                key: key, nonce: nonce, plaintext: plaintext,
                ad: ad, ciphertext: ciphertext, tag: tag
            ))
            fields.removeAll(keepingCapacity: true)
        }

        for rawLine in text.split(separator: "\n", omittingEmptySubsequences: false) {
            lineNum += 1
            let line = rawLine.trimmingCharacters(in: .whitespaces)
            if line.isEmpty {
                try flush()
                continue
            }
            if line.hasPrefix("#") {
                continue
            }
            guard let colon = line.firstIndex(of: ":") else { continue }
            let key = String(line[..<colon]).trimmingCharacters(in: .whitespaces)
            let value = line[line.index(after: colon)...]
                .trimmingCharacters(in: .whitespaces)
            if fields.isEmpty {
                anchorLine = lineNum
            }
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
        // BoringSSL's NIST-derived test entries at the bottom
        // of the file express empty values as the literal
        // double-quoted string `""` rather than a bare blank.
        // Treat both spellings as zero bytes.
        if s.isEmpty || s == "\"\"" { return Data() }
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
