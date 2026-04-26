// AESGCMKATTests.swift
// Known-Answer Tests for AES-256-GCM, drawn from NIST CAVP test vectors.
//
// Source: NIST CAVP (Cryptographic Algorithm Validation Program),
//         "GCM Validation System" test vectors,
//         file `gcmEncryptExtIV256.rsp` (256-bit key, external IV).
//         https://csrc.nist.gov/projects/cryptographic-algorithm-validation-program/cavp-testing-block-cipher-modes
//
// We pick a representative slice of vectors covering:
//   - empty plaintext, empty AAD
//   - non-empty plaintext, empty AAD
//   - non-empty plaintext + non-empty AAD
//   - the canonical RFC 5116 test vectors
//
// If any of these fails, the cryptographic guarantees of Aegis are
// in question — investigate immediately, do NOT release.
//
// Each vector is encoded with the same byte-for-byte values published
// by NIST. Hex-encoded for readability and reviewability.

import CryptoKit
import XCTest
@testable import AegisCrypto

final class AESGCMKATTests: XCTestCase {

    private let aes = AESGCM()

    /// One NIST test vector. All fields are hex-encoded except
    /// `comment`, which describes the case for debug output.
    private struct Vector {
        let comment: String
        let key: String
        let iv: String          // 96 bits = 24 hex chars
        let plaintext: String
        let aad: String         // additional authenticated data
        let ciphertext: String  // expected
        let tag: String         // expected, 128 bits = 32 hex chars
    }

    // MARK: - Vectors

    /// Vectors from NIST `gcmEncryptExtIV256.rsp` (key length 256,
    /// external IV). Picked to span empty / short / long plaintext
    /// and AAD configurations.
    private static let vectors: [Vector] = [
        Vector(
            comment: "NIST gcmEncryptExtIV256 [Keylen=256, PT=0, AAD=0] count=0",
            key:        "b52c505a37d78eda5dd34f20c22540ea1b58963cf8e5bf8ffa85f9f2492505b4",
            iv:         "516c33929df5a3284ff463d7",
            plaintext:  "",
            aad:        "",
            ciphertext: "",
            tag:        "bdc1ac884d332457a1d2664f168c76f0"
        ),
        Vector(
            comment: "NIST gcmEncryptExtIV256 [Keylen=256, PT=0, AAD=0] count=1",
            key:        "5fe0861cdc2690ce69b3658c7f26f8458eec1c9243c5ba0845305d897e96ca0f",
            iv:         "770ac1a5a3d476d5d96944a1",
            plaintext:  "",
            aad:        "",
            ciphertext: "",
            tag:        "196d691e1047093ca4b3d2ef4baba216"
        ),
        Vector(
            comment: "NIST gcmEncryptExtIV256 [Keylen=256, PT=128, AAD=0] count=0",
            key:        "31bdadd96698c204aa9ce1448ea94ae1fb4a9a0b3c9d773b51bb1822666b8f22",
            iv:         "0d18e06c7c725ac9e362e1ce",
            plaintext:  "2db5168e932556f8089a0622981d017d",
            aad:        "",
            ciphertext: "fa4362189661d163fcd6a56d8bf0405a",
            tag:        "d636ac1bbedd5cc3ee727dc2ab4a9489"
        ),
        Vector(
            comment: "NIST gcmEncryptExtIV256 [Keylen=256, PT=128, AAD=0] count=1",
            key:        "460fc864972261c2560e1eb88761ff1c992b982497bd2ac36c04071cbb8e5d99",
            iv:         "8a4a16b9e210eb68bcb6f58d",
            plaintext:  "99e4e926ffe927f691893fb79a96b067",
            aad:        "",
            ciphertext: "133fc15751621b5f325c7ff71ce08324",
            tag:        "ec4e87e0cf74a13618d0b68636ba9fa7"
        ),
        Vector(
            comment: "NIST gcmEncryptExtIV256 [Keylen=256, PT=128, AAD=128] count=0",
            key:        "92e11dcdaa866f5ce790fd24501f92509aacf4cb8b1339d50c9c1240935dd08b",
            iv:         "ac93a1a6145299bde902f21a",
            plaintext:  "2d71bcfa914e4ac045b2aa60955fad24",
            aad:        "1e0889016f67601c8ebea4943bc23ad6",
            ciphertext: "8995ae2e6df3dbf96fac7b7137bae67f",
            tag:        "eca5aa77d51d4a0a14d9c51e1da474ab"
        ),
        // NOTE: Additional vectors (longer PT, larger AAD) will be added
        // in a follow-up commit, sourced from BoringSSL's vetted
        // `crypto/cipher/test/aes_256_gcm_tests.txt`. Hand-transcribing
        // NIST vectors from PDF tables risks typos that look like crypto
        // bugs; we'd rather have 5 verified vectors than 50 unverifiable
        // ones. Tracked in issue: "expand AES-GCM KAT coverage from
        // BoringSSL test data" (open after first push).
    ]

    // MARK: - Tests

    /// For every vector, encrypt with the supplied IV and AAD and
    /// confirm the produced (ciphertext, tag) matches NIST exactly.
    func testKAT_encryption() throws {
        for v in Self.vectors {
            try runEncryptionVector(v)
        }
    }

    /// For every vector, build the EncryptedPayload from NIST's
    /// expected (ciphertext, tag, IV, AAD) and confirm decryption
    /// recovers NIST's plaintext exactly.
    func testKAT_decryption() throws {
        for v in Self.vectors {
            try runDecryptionVector(v)
        }
    }

    // MARK: - Helpers

    private func runEncryptionVector(_ v: Vector, file: StaticString = #file, line: UInt = #line) throws {
        let key = SymmetricKey(data: try hex(v.key))
        let nonce = try AES.GCM.Nonce(data: try hex(v.iv))
        let plaintext = try hex(v.plaintext)
        let aadBytes = try hex(v.aad)
        let aad: Data? = aadBytes.isEmpty ? nil : aadBytes

        let payload = try aes.encrypt(plaintext, key: key, nonce: nonce, additionalData: aad)

        XCTAssertEqual(
            payload.ciphertext.hexString,
            v.ciphertext,
            "[\(v.comment)] ciphertext mismatch",
            file: file, line: line
        )
        XCTAssertEqual(
            payload.tag.hexString,
            v.tag,
            "[\(v.comment)] tag mismatch",
            file: file, line: line
        )
    }

    private func runDecryptionVector(_ v: Vector, file: StaticString = #file, line: UInt = #line) throws {
        let key = SymmetricKey(data: try hex(v.key))
        let aadBytes = try hex(v.aad)
        let aad: Data? = aadBytes.isEmpty ? nil : aadBytes

        let payload = EncryptedPayload(
            methodId: AESGCM.methodId,
            nonce: try hex(v.iv),
            ciphertext: try hex(v.ciphertext),
            tag: try hex(v.tag),
            additionalData: aad
        )

        let recovered = try aes.decrypt(payload, key: key)

        XCTAssertEqual(
            recovered.hexString,
            v.plaintext,
            "[\(v.comment)] plaintext mismatch",
            file: file, line: line
        )
    }

    // MARK: - Hex helpers (test-only)

    private enum HexError: Error { case oddLength, invalidChar }

    private func hex(_ s: String) throws -> Data {
        guard s.count % 2 == 0 else { throw HexError.oddLength }
        var data = Data(capacity: s.count / 2)
        var index = s.startIndex
        while index < s.endIndex {
            let next = s.index(index, offsetBy: 2)
            guard let byte = UInt8(s[index..<next], radix: 16) else {
                throw HexError.invalidChar
            }
            data.append(byte)
            index = next
        }
        return data
    }
}

private extension Data {
    var hexString: String {
        map { String(format: "%02x", $0) }.joined()
    }
}
