// TwoUserDemo.swift
// Sprint 8 commit 5 — the "I am Alice / I am Bob" toggle that
// turns Aegis into a working messenger on a single device with
// no networking.
//
// Bootstrap: generate two synthetic identities (Alice, Bob),
// run a full PQXDH handshake between them, seed two ratchet
// sessions from the same shared secret, and create two
// ConversationStore conversations (one row per persona's view
// of the other). Persisted: the conversations, the ratchet
// sessions, the per-conversation Keychain storage keys. NOT
// persisted across launches: Alice's and Bob's identity
// keypairs (the demo regenerates them at every bootstrap;
// that's a deliberate "this is a demo, not your real
// identity" affordance).
//
// Send / receive: TwoUserDemo.send routes the plaintext
// through ConversationStore.send on the active persona's
// conversation (advancing that ratchet) and then immediately
// hands the resulting wire message to ConversationStore
// .receive on the passive persona's conversation (advancing
// the other ratchet, persisting the at-rest plaintext on the
// other side). Two database conversations, one logical chat.

import AegisCrypto
import AegisStorage
import Foundation
import Observation

/// Which synthetic persona is the "local user" in this
/// two-user demo session.
public enum TwoUserPersona: String, Sendable, Equatable {
    case alice
    case bob

    public var displayName: String {
        switch self {
        case .alice: return "Alice"
        case .bob: return "Bob"
        }
    }

    public var other: TwoUserPersona {
        switch self {
        case .alice: return .bob
        case .bob: return .alice
        }
    }
}

/// Errors specific to the two-user demo wiring.
public enum TwoUserDemoError: Error, Equatable {
    /// `send` / `togglePersona` was called before
    /// `bootstrap()` completed.
    case notBootstrapped
}

/// Bootstrappable / observable wrapper around a working
/// Alice<->Bob messaging pair on one device.
@Observable
@MainActor
public final class TwoUserDemo {

    // MARK: - Public state

    public private(set) var activePersona: TwoUserPersona = .alice

    /// Alice's view of the conversation (peer = Bob).
    public private(set) var aliceConversation: Conversation?

    /// Bob's view of the conversation (peer = Alice).
    public private(set) var bobConversation: Conversation?

    /// True after `bootstrap()` has succeeded.
    public var isBootstrapped: Bool {
        aliceConversation != nil && bobConversation != nil
    }

    /// The conversation owned by the current active persona.
    public var activeConversation: Conversation? {
        switch activePersona {
        case .alice: return aliceConversation
        case .bob: return bobConversation
        }
    }

    // MARK: - Internals

    private let store: ConversationStore

    public init(store: ConversationStore) {
        self.store = store
    }

    // MARK: - Bootstrap

    /// Generate fresh Alice + Bob identities, run PQXDH, seed
    /// two ratchet sessions, and create two `Conversation`
    /// rows. Idempotent — calling twice is a no-op once
    /// bootstrap has succeeded.
    public func bootstrap() throws {
        guard !isBootstrapped else { return }

        let alice = try IdentityKeyPair.generate()
        let bob = try IdentityKeyPair.generate()

        // Bob publishes a prekey bundle. We don't need any
        // OPKs for the local demo — one Alice initiating
        // exactly once doesn't gain replay-defence value from
        // OPKs in this single-device context.
        let (bobBundle, bobSecrets) = try PrekeyBundle.generate(
            identity: bob,
            oneTimePrekeyCount: 0
        )

        // Alice initiates against Bob's bundle.
        let initiate = try PQXDH.initiate(
            as: alice,
            toBundle: bobBundle,
            useOneTimePrekey: false
        )

        // Bob responds, deriving the same shared secret.
        let bobSharedSecret = try PQXDH.respond(
            as: bob,
            bundleSecrets: bobSecrets,
            bundleEpoch: bobBundle.signedPrekeyEpoch,
            receiving: initiate.initialMessage
        )
        // Sanity: the two sides agreed.
        precondition(
            bobSharedSecret == initiate.sharedSecret,
            "PQXDH shared secrets diverged between Alice and Bob — bug in the bootstrap"
        )

        // Seed both ratchet sessions from the same secret.
        let bobSPKPublic = bobBundle.signedPrekey.publicKey
        let bobSPKKeyPair = DHKeyPair(
            publicKey: bobBundle.signedPrekey.publicKey,
            privateKey: bobSecrets.signedPrekey.privateKey
        )
        let aliceSession = try RatchetSession.initiateAsAlice(
            sharedSecret: initiate.sharedSecret,
            bobSignedPrekeyPublic: bobSPKPublic
        )
        let bobSession = try RatchetSession.initiateAsBob(
            sharedSecret: bobSharedSecret,
            signedPrekeyKeyPair: bobSPKKeyPair
        )

        // Create both conversations. Display names are the
        // OTHER persona's name — Alice's row is "Bob" because
        // that's whom she's chatting with.
        let aliceConv = try store.create(
            peerIdentity: bob.publicKey,
            displayName: TwoUserPersona.bob.displayName,
            ratchetSession: aliceSession
        )
        let bobConv = try store.create(
            peerIdentity: alice.publicKey,
            displayName: TwoUserPersona.alice.displayName,
            ratchetSession: bobSession
        )

        self.aliceConversation = aliceConv
        self.bobConversation = bobConv
    }

    // MARK: - Persona toggle

    public func setActivePersona(_ persona: TwoUserPersona) {
        activePersona = persona
    }

    public func togglePersona() {
        activePersona = activePersona.other
    }

    // MARK: - Send / receive

    /// Send `plaintext` from the active persona to the other
    /// persona. Advances both ratchet sessions, persists both
    /// at-rest plaintexts (one on each side), and returns the
    /// active-side stored record.
    @discardableResult
    public func send(plaintext: Data) throws -> StoredMessage {
        guard let active = activeConversation,
              let passive = passiveConversation()
        else { throw TwoUserDemoError.notBootstrapped }

        let result = try store.send(plaintext: plaintext, in: active.id)
        _ = try store.receive(result.wireMessage, in: passive.id)
        return result.storedMessage
    }

    /// The conversation owned by the persona that is NOT
    /// active right now.
    public func passiveConversation() -> Conversation? {
        switch activePersona {
        case .alice: return bobConversation
        case .bob: return aliceConversation
        }
    }
}
