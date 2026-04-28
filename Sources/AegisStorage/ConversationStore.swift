// ConversationStore.swift
// SQLite-backed CRUD for conversations and messages, plus
// the send/receive flow that drives the Double Ratchet
// underneath.
//
// On-disk discipline (Sprint 8 settled choice B): every
// message's plaintext is AES-256-GCM-encrypted under a
// per-conversation `ConversationStorageKey` (Keychain-resident)
// before it is written to the `messages.ciphertext` column.
// Nothing in the SQLite file is plaintext message body. The
// wire-format ratchet message produced by `send` is NOT
// persisted in this commit — it is the artefact a future
// transport (Sprint 9 networking) hands over to the peer.
// Until then, the two-user toggle (Sprint 8 commit 5) calls
// `receive` on the OTHER local user's view to deliver the
// same message in-process.
//
// Atomicity: send/receive run inside a SQLite transaction —
// the updated ratchet session and the new message row commit
// or roll back together. The Keychain access for the storage
// key happens outside the transaction (Keychain has no
// transactional join with SQLite); since the storage key
// doesn't change per send/receive, this is acceptable.

import AegisCrypto
import CryptoKit
import Foundation

// MARK: - Public types

/// A conversation with one peer. Two-user demo on a single
/// device has one row per side (Alice→Bob and Bob→Alice).
public struct Conversation: Sendable, Equatable {
    public let id: UUID
    public let peerIdentity: IdentityPublicKey
    public let displayName: String
    public let aeadMethod: String
    public let kemMethod: String
    public let signatureMethod: String
    public let createdAt: Int64
    public let updatedAt: Int64

    public init(
        id: UUID,
        peerIdentity: IdentityPublicKey,
        displayName: String,
        aeadMethod: String,
        kemMethod: String,
        signatureMethod: String,
        createdAt: Int64,
        updatedAt: Int64
    ) {
        self.id = id
        self.peerIdentity = peerIdentity
        self.displayName = displayName
        self.aeadMethod = aeadMethod
        self.kemMethod = kemMethod
        self.signatureMethod = signatureMethod
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }
}

/// Direction of a message relative to the local conversation
/// owner. Stored as INTEGER in SQLite.
public enum MessageDirection: Int, Sendable, Equatable {
    case outgoing = 0
    case incoming = 1
}

/// A persisted message after at-rest decryption. `plaintext`
/// is the recovered message body — never on disk in this
/// form, only in memory after a `messages(in:)` load.
public struct StoredMessage: Sendable, Equatable {
    public let id: UUID
    public let conversationId: UUID
    public let direction: MessageDirection
    public let plaintext: Data
    public let sentAt: Int64
    public let messageNumber: UInt32

    public init(
        id: UUID,
        conversationId: UUID,
        direction: MessageDirection,
        plaintext: Data,
        sentAt: Int64,
        messageNumber: UInt32
    ) {
        self.id = id
        self.conversationId = conversationId
        self.direction = direction
        self.plaintext = plaintext
        self.sentAt = sentAt
        self.messageNumber = messageNumber
    }
}

/// Result of a `send` call: the persisted local record AND
/// the wire-format ratchet message the caller should deliver
/// to the peer.
public struct SendResult: Sendable, Equatable {
    public let storedMessage: StoredMessage
    public let wireMessage: RatchetMessage
}

/// Errors specific to the ConversationStore.
public enum ConversationStoreError: Error, Equatable {
    case conversationNotFound(id: UUID)
    case ratchetSessionMissing(conversationId: UUID)
    case storageKeyMissing(conversationId: UUID)
    case malformedRow(reason: String)
    case encodeFailed(reason: String)
    case decodeFailed(reason: String)
}

// MARK: - Defaults

/// Canonical Tier 1 method identifiers used as defaults for
/// new conversations. Match the `methodId` strings exposed by
/// each AegisCrypto wrapper.
public enum ConversationDefaults {
    public static let aead = "tier1.aes-256-gcm"
    public static let kem = "tier1.xwing-mlkem768-x25519"
    public static let signature = "tier1.ml-dsa-65"
}

// MARK: - Store

public final class ConversationStore {

    private let db: SQLiteDatabase
    private let sessionStore: RatchetSessionStore
    private let now: @Sendable () -> Int64

    public init(
        database: SQLiteDatabase,
        sessionStore: RatchetSessionStore,
        now: @escaping @Sendable () -> Int64 = ConversationStore.defaultClock
    ) {
        self.db = database
        self.sessionStore = sessionStore
        self.now = now
    }

    public static let defaultClock: @Sendable () -> Int64 = {
        Int64(Date().timeIntervalSince1970)
    }

    // MARK: - Conversation CRUD

    /// Create a fresh conversation: record, ratchet session,
    /// and per-conversation storage key. Returns the
    /// `Conversation` row.
    public func create(
        peerIdentity: IdentityPublicKey,
        displayName: String,
        ratchetSession: RatchetSession,
        aeadMethod: String = ConversationDefaults.aead,
        kemMethod: String = ConversationDefaults.kem,
        signatureMethod: String = ConversationDefaults.signature
    ) throws -> Conversation {
        let id = UUID()
        let timestamp = now()
        let peerJSON: Data
        do {
            peerJSON = try JSONEncoder().encode(peerIdentity)
        } catch {
            throw ConversationStoreError.encodeFailed(reason: "peerIdentity: \(error)")
        }

        // Provision the storage key BEFORE the SQL writes —
        // if Keychain provisioning fails we don't want a
        // half-created conversation row. (Provisioning failure
        // is rare; Keychain unavailability typically only
        // happens before first device unlock.)
        _ = try ConversationStorageKey.provision(for: id)

        do {
            try db.transaction {
                let stmt = try db.prepare("""
                    INSERT INTO conversations
                        (id, peer_identity, display_name,
                         aead_method, kem_method, signature_method,
                         created_at, updated_at)
                    VALUES (?, ?, ?, ?, ?, ?, ?, ?);
                    """)
                defer { stmt.finalize() }
                try stmt.bind(id.data, at: 1)
                try stmt.bind(peerJSON, at: 2)
                try stmt.bind(displayName, at: 3)
                try stmt.bind(aeadMethod, at: 4)
                try stmt.bind(kemMethod, at: 5)
                try stmt.bind(signatureMethod, at: 6)
                try stmt.bind(timestamp, at: 7)
                try stmt.bind(timestamp, at: 8)
                _ = try stmt.step()

                try sessionStore.save(ratchetSession, forConversation: id.data)
            }
        } catch {
            // Roll back the Keychain item so we don't leak a
            // dangling storage key.
            try? ConversationStorageKey.delete(for: id)
            throw error
        }

        return Conversation(
            id: id,
            peerIdentity: peerIdentity,
            displayName: displayName,
            aeadMethod: aeadMethod,
            kemMethod: kemMethod,
            signatureMethod: signatureMethod,
            createdAt: timestamp,
            updatedAt: timestamp
        )
    }

    /// All conversations, sorted by most recently updated
    /// first.
    public func list() throws -> [Conversation] {
        let stmt = try db.prepare("""
            SELECT id, peer_identity, display_name,
                   aead_method, kem_method, signature_method,
                   created_at, updated_at
            FROM conversations
            ORDER BY updated_at DESC;
            """)
        defer { stmt.finalize() }
        var out: [Conversation] = []
        while try stmt.step() {
            out.append(try Self.row(from: stmt))
        }
        return out
    }

    /// Single conversation by id, or nil if absent.
    public func load(id: UUID) throws -> Conversation? {
        let stmt = try db.prepare("""
            SELECT id, peer_identity, display_name,
                   aead_method, kem_method, signature_method,
                   created_at, updated_at
            FROM conversations
            WHERE id = ?;
            """)
        defer { stmt.finalize() }
        try stmt.bind(id.data, at: 1)
        guard try stmt.step() else { return nil }
        return try Self.row(from: stmt)
    }

    /// Delete conversation, its session (FK CASCADE in
    /// schema), all messages (FK CASCADE), and its Keychain
    /// storage key.
    public func delete(id: UUID) throws {
        let del = try db.prepare("DELETE FROM conversations WHERE id = ?;")
        defer { del.finalize() }
        try del.bind(id.data, at: 1)
        _ = try del.step()
        try ConversationStorageKey.delete(for: id)
    }

    // MARK: - Send / receive

    /// Encrypt `plaintext` via the conversation's ratchet
    /// session (advancing it), persist the message at-rest,
    /// and return the persisted record plus the wire-format
    /// `RatchetMessage` the caller should deliver to the peer.
    public func send(
        plaintext: Data,
        in conversationId: UUID
    ) throws -> SendResult {
        guard let storageKey = try ConversationStorageKey.load(for: conversationId) else {
            throw ConversationStoreError.storageKeyMissing(conversationId: conversationId)
        }
        guard var session = try sessionStore.load(forConversation: conversationId.data) else {
            throw ConversationStoreError.ratchetSessionMissing(conversationId: conversationId)
        }

        // Advance the ratchet to produce the wire envelope.
        // This mutates `session`; we save the post-advance
        // state below atomically.
        let wireMessage = try session.encrypt(plaintext)

        // At-rest encrypt: AES-GCM under the per-conversation
        // storage key, with AAD binding the blob to its
        // (conversation, message, direction) identity so a
        // blob can't be silently swapped between rows.
        let messageId = UUID()
        let timestamp = now()
        let aad = Self.atRestAAD(
            conversationId: conversationId,
            messageId: messageId,
            direction: .outgoing
        )
        let blob = try Self.atRestSeal(
            plaintext: plaintext,
            key: storageKey,
            aad: aad
        )

        let messageNumber = wireMessage.header.messageNumber

        try db.transaction {
            try sessionStore.save(session, forConversation: conversationId.data)
            try insertMessageRow(
                id: messageId,
                conversationId: conversationId,
                direction: .outgoing,
                blob: blob,
                sentAt: timestamp,
                messageNumber: messageNumber
            )
            try touchConversation(id: conversationId, at: timestamp)
        }

        let storedMessage = StoredMessage(
            id: messageId,
            conversationId: conversationId,
            direction: .outgoing,
            plaintext: plaintext,
            sentAt: timestamp,
            messageNumber: messageNumber
        )
        return SendResult(storedMessage: storedMessage, wireMessage: wireMessage)
    }

    /// Decrypt a wire-format ratchet message via the
    /// conversation's session (advancing it), persist the
    /// recovered plaintext at-rest, and return the persisted
    /// record.
    public func receive(
        _ wireMessage: RatchetMessage,
        in conversationId: UUID
    ) throws -> StoredMessage {
        guard let storageKey = try ConversationStorageKey.load(for: conversationId) else {
            throw ConversationStoreError.storageKeyMissing(conversationId: conversationId)
        }
        guard var session = try sessionStore.load(forConversation: conversationId.data) else {
            throw ConversationStoreError.ratchetSessionMissing(conversationId: conversationId)
        }

        let plaintext = try session.decrypt(wireMessage)

        let messageId = UUID()
        let timestamp = now()
        let aad = Self.atRestAAD(
            conversationId: conversationId,
            messageId: messageId,
            direction: .incoming
        )
        let blob = try Self.atRestSeal(
            plaintext: plaintext,
            key: storageKey,
            aad: aad
        )

        let messageNumber = wireMessage.header.messageNumber

        try db.transaction {
            try sessionStore.save(session, forConversation: conversationId.data)
            try insertMessageRow(
                id: messageId,
                conversationId: conversationId,
                direction: .incoming,
                blob: blob,
                sentAt: timestamp,
                messageNumber: messageNumber
            )
            try touchConversation(id: conversationId, at: timestamp)
        }

        return StoredMessage(
            id: messageId,
            conversationId: conversationId,
            direction: .incoming,
            plaintext: plaintext,
            sentAt: timestamp,
            messageNumber: messageNumber
        )
    }

    // MARK: - Read messages

    /// All messages in a conversation, sorted oldest first
    /// (sentAt ASC). Each row is decrypted at load time using
    /// the conversation's storage key.
    public func messages(in conversationId: UUID) throws -> [StoredMessage] {
        guard let storageKey = try ConversationStorageKey.load(for: conversationId) else {
            throw ConversationStoreError.storageKeyMissing(conversationId: conversationId)
        }

        let stmt = try db.prepare("""
            SELECT id, direction, ciphertext, sent_at, message_number
            FROM messages
            WHERE conversation_id = ?
            ORDER BY sent_at ASC, message_number ASC;
            """)
        defer { stmt.finalize() }
        try stmt.bind(conversationId.data, at: 1)

        var out: [StoredMessage] = []
        while try stmt.step() {
            guard let idData = stmt.data(at: 0),
                  let id = UUID(data: idData) else {
                throw ConversationStoreError.malformedRow(reason: "messages.id not a UUID")
            }
            let directionRaw = Int(stmt.int64(at: 1))
            guard let direction = MessageDirection(rawValue: directionRaw) else {
                throw ConversationStoreError.malformedRow(
                    reason: "messages.direction invalid value \(directionRaw)"
                )
            }
            guard let blob = stmt.data(at: 2) else {
                throw ConversationStoreError.malformedRow(reason: "messages.ciphertext nil")
            }
            let sentAt = stmt.int64(at: 3)
            let messageNumber = UInt32(stmt.int64(at: 4))

            let plaintext = try Self.atRestOpen(
                blob: blob,
                key: storageKey,
                conversationId: conversationId,
                messageId: id,
                direction: direction
            )

            out.append(StoredMessage(
                id: id,
                conversationId: conversationId,
                direction: direction,
                plaintext: plaintext,
                sentAt: sentAt,
                messageNumber: messageNumber
            ))
        }
        return out
    }

    // MARK: - Internals

    private func insertMessageRow(
        id: UUID,
        conversationId: UUID,
        direction: MessageDirection,
        blob: Data,
        sentAt: Int64,
        messageNumber: UInt32
    ) throws {
        let stmt = try db.prepare("""
            INSERT INTO messages
                (id, conversation_id, direction, ciphertext, sent_at, message_number)
            VALUES (?, ?, ?, ?, ?, ?);
            """)
        defer { stmt.finalize() }
        try stmt.bind(id.data, at: 1)
        try stmt.bind(conversationId.data, at: 2)
        try stmt.bind(Int64(direction.rawValue), at: 3)
        try stmt.bind(blob, at: 4)
        try stmt.bind(sentAt, at: 5)
        try stmt.bind(Int64(messageNumber), at: 6)
        _ = try stmt.step()
    }

    private func touchConversation(id: UUID, at timestamp: Int64) throws {
        let stmt = try db.prepare(
            "UPDATE conversations SET updated_at = ? WHERE id = ?;"
        )
        defer { stmt.finalize() }
        try stmt.bind(timestamp, at: 1)
        try stmt.bind(id.data, at: 2)
        _ = try stmt.step()
    }

    private static func row(from stmt: SQLiteStatement) throws -> Conversation {
        guard let idData = stmt.data(at: 0),
              let id = UUID(data: idData) else {
            throw ConversationStoreError.malformedRow(reason: "conversations.id not a UUID")
        }
        guard let peerJSON = stmt.data(at: 1) else {
            throw ConversationStoreError.malformedRow(reason: "conversations.peer_identity nil")
        }
        let peerIdentity: IdentityPublicKey
        do {
            peerIdentity = try JSONDecoder().decode(IdentityPublicKey.self, from: peerJSON)
        } catch {
            throw ConversationStoreError.decodeFailed(reason: "peer_identity: \(error)")
        }
        guard let displayName = stmt.text(at: 2) else {
            throw ConversationStoreError.malformedRow(reason: "conversations.display_name nil")
        }
        guard let aead = stmt.text(at: 3),
              let kem = stmt.text(at: 4),
              let sig = stmt.text(at: 5) else {
            throw ConversationStoreError.malformedRow(reason: "conversations.method id nil")
        }
        let createdAt = stmt.int64(at: 6)
        let updatedAt = stmt.int64(at: 7)

        return Conversation(
            id: id,
            peerIdentity: peerIdentity,
            displayName: displayName,
            aeadMethod: aead,
            kemMethod: kem,
            signatureMethod: sig,
            createdAt: createdAt,
            updatedAt: updatedAt
        )
    }

    /// AAD bound to a single (conversation, message,
    /// direction). Authenticated but not encrypted by AES-GCM,
    /// so swapping a blob from row A into row B fails the
    /// AEAD on read.
    fileprivate static func atRestAAD(
        conversationId: UUID,
        messageId: UUID,
        direction: MessageDirection
    ) -> Data {
        var bytes = Data()
        bytes.append("aegis.at-rest.v1|".data(using: .utf8)!)
        bytes.append(conversationId.data)
        bytes.append(messageId.data)
        bytes.append(UInt8(direction.rawValue))
        return bytes
    }

    /// AEAD-seal `plaintext` under the storage key with `aad`
    /// authenticated, return JSON-encoded `EncryptedPayload`
    /// bytes ready to write into `messages.ciphertext`.
    fileprivate static func atRestSeal(
        plaintext: Data,
        key: SymmetricKey,
        aad: Data
    ) throws -> Data {
        let sealed = try AESGCM().encrypt(
            plaintext,
            key: key,
            nonce: AES.GCM.Nonce(),
            additionalData: aad
        )
        do {
            return try JSONEncoder().encode(sealed)
        } catch {
            throw ConversationStoreError.encodeFailed(reason: "EncryptedPayload: \(error)")
        }
    }

    /// Decode and AEAD-open an at-rest message blob.
    fileprivate static func atRestOpen(
        blob: Data,
        key: SymmetricKey,
        conversationId: UUID,
        messageId: UUID,
        direction: MessageDirection
    ) throws -> Data {
        let payload: EncryptedPayload
        do {
            payload = try JSONDecoder().decode(EncryptedPayload.self, from: blob)
        } catch {
            throw ConversationStoreError.decodeFailed(reason: "messages.ciphertext: \(error)")
        }
        let aad = atRestAAD(
            conversationId: conversationId,
            messageId: messageId,
            direction: direction
        )
        let withAAD = EncryptedPayload(
            methodId: payload.methodId,
            nonce: payload.nonce,
            ciphertext: payload.ciphertext,
            tag: payload.tag,
            additionalData: aad
        )
        return try AESGCM().decrypt(withAAD, key: key)
    }
}

// MARK: - UUID <-> Data helper

extension UUID {

    /// 16-byte big-endian representation suitable for a SQLite
    /// BLOB primary key.
    var data: Data {
        withUnsafeBytes(of: uuid) { Data($0) }
    }

    /// Parse a 16-byte representation. Returns nil if `data`
    /// is the wrong length.
    init?(data: Data) {
        guard data.count == 16 else { return nil }
        var bytes: uuid_t = (0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0)
        _ = withUnsafeMutableBytes(of: &bytes) { dest in
            data.copyBytes(to: dest.bindMemory(to: UInt8.self))
        }
        self = UUID(uuid: bytes)
    }
}
