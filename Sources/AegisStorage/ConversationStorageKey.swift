// ConversationStorageKey.swift
// Per-conversation 256-bit AES-GCM key, kept in the Keychain.
//
// Why a per-conversation key (Sprint 8 commit 3): the Double
// Ratchet is forward-secure on the wire — every message's
// AEAD key is consumed and discarded after use — so we cannot
// re-derive a past message's ratchet key for display. To
// satisfy Sprint 8's "ciphertext only on disk" discipline
// while still being able to render the thread view, the
// ConversationStore encrypts each message's plaintext with
// this storage key before writing it to the messages table.
//
// This is a different threat model from Decision 2 of the
// Sprint 8 planning round (which was about NOT adding a
// second AEAD layer over the wire ciphertext to defend
// against ratchet-state leak). The storage key defends
// against a different concern: at-rest plaintext exposure if
// the SQLite file is exfiltrated separately from the
// Keychain.
//
// Lifecycle:
//   - Provisioned at conversation creation, never rotates
//     while the conversation exists. (Rotation could be added
//     later as a "scrub" feature — would require re-encrypting
//     every stored message under the new key.)
//   - Deleted when the conversation is deleted.
//   - Same Keychain accessibility class as identity keys
//     (`afterFirstUnlockThisDeviceOnly`); never syncs to
//     iCloud.

import CryptoKit
import Foundation
import Security

/// Per-conversation Keychain-backed AES-256-GCM storage key.
public enum ConversationStorageKey {

    /// 256-bit key length.
    public static let keyByteCount = 32

    /// Generate a fresh storage key, persist it in the
    /// Keychain under the AegisStorage service namespace, and
    /// return the in-memory `SymmetricKey`. If a key already
    /// existed for this conversation, it is overwritten.
    public static func provision(for conversationId: UUID) throws -> SymmetricKey {
        let key = SymmetricKey(size: .bits256)
        let bytes = key.withUnsafeBytes { Data($0) }
        try Keychain.set(
            data: bytes,
            service: AegisStorage.serviceIdentifier,
            account: account(for: conversationId),
            accessibility: AegisStorage.defaultAccessibility
        )
        return key
    }

    /// Load the storage key for `conversationId`, or nil if
    /// none has been provisioned.
    public static func load(for conversationId: UUID) throws -> SymmetricKey? {
        guard let bytes = try Keychain.get(
            service: AegisStorage.serviceIdentifier,
            account: account(for: conversationId)
        ) else { return nil }
        guard bytes.count == keyByteCount else {
            // Treat malformed keychain data as "absent". We
            // cannot continue with a wrong-sized key.
            return nil
        }
        return SymmetricKey(data: bytes)
    }

    /// Delete the storage key for `conversationId`. Idempotent
    /// — no error if no key was stored.
    public static func delete(for conversationId: UUID) throws {
        try Keychain.delete(
            service: AegisStorage.serviceIdentifier,
            account: account(for: conversationId)
        )
    }

    /// Keychain account string used for a given conversation.
    /// Kept stable so a conversation's key survives app
    /// updates as long as the service identifier stays the
    /// same. Versioned (`-v1`) so a future format change is
    /// loud.
    static func account(for conversationId: UUID) -> String {
        "conversation-storage-key-v1-\(conversationId.uuidString)"
    }
}
