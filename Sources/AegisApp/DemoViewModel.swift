// DemoViewModel.swift
// View-model for the encrypt/decrypt demo screen. Pulled out
// of the SwiftUI view so the encryption-side logic is unit-
// testable without rendering a view.
//
// We deliberately use the AEAD primitive (AESGCM) directly
// here rather than going through the full identity / PQXDH /
// ratchet stack — the demo's job is to make the AEAD round-
// trip *visible* on a phone, not to bootstrap a peer session
// (we don't have a peer yet; networking is Sprint 8).

import AegisCrypto
import Foundation
import Observation

@Observable
@MainActor
public final class DemoViewModel {

    /// Plaintext the user wants to encrypt.
    public var plaintext: String = ""

    /// Passphrase used to derive the AEAD key (HKDF over the
    /// passphrase bytes via `AESGCM.deriveKey`). Demo-grade
    /// only — real session keys come from PQXDH + the
    /// Double Ratchet, not from a typed passphrase.
    public var passphrase: String = ""

    /// Latest produced ciphertext envelope, or nil if no
    /// encryption has run yet.
    public private(set) var encryptedPayload: EncryptedPayload?

    /// Recovered plaintext after the most recent decrypt
    /// call, or nil.
    public private(set) var decryptedText: String?

    /// User-facing error message from the most recent
    /// encrypt or decrypt attempt, or nil.
    public private(set) var errorMessage: String?

    public init() {}

    // MARK: - Actions

    /// Encrypt `plaintext` under a key derived from
    /// `passphrase` and AES-256-GCM. No-op if either field
    /// is empty.
    public func encrypt() {
        guard !plaintext.isEmpty, !passphrase.isEmpty else { return }
        do {
            let key = AESGCM.deriveKey(from: Data(passphrase.utf8))
            let aes = AESGCM()
            let payload = try aes.encrypt(Data(plaintext.utf8), key: key)
            encryptedPayload = payload
            decryptedText = nil
            errorMessage = nil
        } catch {
            encryptedPayload = nil
            errorMessage = "Encrypt failed: \(error.localizedDescription)"
        }
    }

    /// Decrypt the most recent payload using the *current*
    /// passphrase. The passphrase change between encrypt and
    /// decrypt is what lets the user observe AEAD's
    /// authentication failure surface honestly.
    public func decrypt() {
        guard let payload = encryptedPayload else { return }
        do {
            let key = AESGCM.deriveKey(from: Data(passphrase.utf8))
            let aes = AESGCM()
            let recovered = try aes.decrypt(payload, key: key)
            decryptedText = String(data: recovered, encoding: .utf8)
                ?? "<\(recovered.count) bytes of non-UTF-8>"
            errorMessage = nil
        } catch AegisError.authenticationFailed {
            decryptedText = nil
            errorMessage = "Decrypt failed: wrong passphrase or tampered ciphertext."
        } catch {
            decryptedText = nil
            errorMessage = "Decrypt failed: \(error.localizedDescription)"
        }
    }

    /// Clear the demo state — drops the payload, recovered
    /// text, and any error.
    public func reset() {
        encryptedPayload = nil
        decryptedText = nil
        errorMessage = nil
    }
}
