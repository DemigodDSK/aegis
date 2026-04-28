// PQXDH.swift
// Post-Quantum Extended Diffie-Hellman key-exchange handshake.
//
// PQXDH is a one-shot key-establishment protocol modeled on
// Signal's X3DH, hardened with a post-quantum KEM (ML-KEM-1024
// in our case) so that a future quantum adversary cannot break
// past sessions even if they captured the wire bytes today
// ("harvest now, decrypt later").
//
// References:
//   - Signal's "PQXDH: Post-Quantum Extended Diffie-Hellman"
//     specification (https://signal.org/docs/specifications/pqxdh/)
//
// Protocol shape (Aegis Tier 1 instantiation):
//
//   Bob publishes a PrekeyBundle (separate file):
//     IK_B  = (signing: ML-DSA-65, dh: X25519)
//     SPK_B = X25519, signed by IK_B.signing
//     PQPK_B = ML-KEM-1024, signed by IK_B.signing
//     [OPK_B...] = X25519, each signed by IK_B.signing
//
//   Alice initiates:
//     1. Verify every signature in Bob's bundle using IK_B.signing.
//     2. Generate ephemeral X25519 keypair EK_A.
//     3. Compute four (or three) DH values:
//          DH1 = DH(IK_A.dh, SPK_B)
//          DH2 = DH(EK_A, IK_B.dh)
//          DH3 = DH(EK_A, SPK_B)
//          DH4 = DH(EK_A, OPK_B)        (only if OPK is used)
//     4. Encapsulate against PQPK_B:
//          (PQ_CT, ss_pq) = ML-KEM-Encapsulate(PQPK_B)
//     5. Derive the shared secret:
//          IKM  = F || DH1 || DH2 || DH3 || [DH4] || ss_pq
//          SK   = HKDF-SHA-256(IKM, salt=∅, info="AEGIS_PQXDH_v1", 32)
//        where F is a 32-byte fixed "version hedge"
//        (`Data(repeating: 0xFF, count: 32)`) — same purpose as
//        Signal's X3DH `0xFF...` byte string: domain-separates
//        the IKM from any other HKDF input.
//     6. Send InitialMessage(IK_A, EK_A.pub, key-id refs, PQ_CT,
//        bundleEpoch) to Bob.
//
//   Bob responds:
//     1. Look up his secrets matching the referenced
//        (SPK, PQPK, [OPK]) keyIds. Reject if any are missing
//        or the bundleEpoch does not match what he published.
//     2. Compute the same four (or three) DH values from his
//        side; the asymmetry of DH means each pair agrees.
//     3. Decapsulate ss_pq from PQ_CT using PQPK_B's secret.
//     4. Run the identical HKDF; the resulting SK matches
//        Alice's iff every input matches.
//     5. Retire the OPK (if used) — single-use rule.
//
// SK is the 32-byte seed for the Double Ratchet root key
// (Sprint 5). PQXDH does not provide forward secrecy for
// later messages by itself; that is the ratchet's job.

import CryptoKit
import Foundation

/// PQXDH key-exchange handshake. Stateless namespace —
/// `initiate` and `respond` are pure functions of their
/// inputs (modulo the system CSPRNG used for Alice's
/// ephemeral key + ML-KEM encapsulation randomness).
public enum PQXDH {

    /// HKDF info string. Versioned so that a future
    /// derivation-rule change is loud.
    static let hkdfInfo = Data("AEGIS_PQXDH_v1".utf8)

    /// 32-byte version hedge prepended to the HKDF input. Same
    /// purpose as Signal's X3DH leading `0xFF...` byte string —
    /// adds domain separation against any other primitive that
    /// might also derive a key from concatenated DH outputs.
    static let versionHedge = Data(repeating: 0xFF, count: 32)

    /// Output length of the derived shared secret.
    public static let sharedSecretByteCount = 32

    // MARK: - Alice (initiator)

    /// Initiating Alice produces this.
    public struct InitiateResult: Sendable {

        /// Wire-format message Alice sends to Bob.
        public let initialMessage: InitialMessage

        /// 32-byte derived shared secret. Identical to what
        /// Bob will derive after running `respond` — this is
        /// the seed for any subsequent symmetric session
        /// (Double Ratchet root key in Sprint 5).
        public let sharedSecret: Data

        public init(initialMessage: InitialMessage, sharedSecret: Data) {
            self.initialMessage = initialMessage
            self.sharedSecret = sharedSecret
        }
    }

    /// Alice initiates a session against Bob's prekey bundle.
    ///
    /// - Parameters:
    ///   - alice: Alice's long-term identity. Both her
    ///     signing and DH keys are read; nothing is mutated.
    ///   - bundle: Bob's prekey bundle, fetched from the
    ///     server. Will be verified before any DH operation
    ///     runs — a forged bundle aborts the handshake.
    ///   - useOneTimePrekey: if `true` (default) and the
    ///     bundle has any OPKs, the first one is consumed.
    ///     If `false`, the handshake skips DH4. The OPK is
    ///     security-improving but optional.
    /// - Returns: `InitiateResult` containing the message to
    ///   send to Bob and the 32-byte derived shared secret.
    /// - Throws: `AegisError.authenticationFailed` if the
    ///   bundle's signature chain does not verify.
    ///   `AegisError.invalidKey` for size mismatches.
    public static func initiate(
        as alice: IdentityKeyPair,
        toBundle bundle: PrekeyBundle,
        useOneTimePrekey: Bool = true
    ) throws -> InitiateResult {
        // 1. Verify Bob's bundle. Refuse to derive any keys
        // if the chain does not check out.
        guard try bundle.verify() else {
            throw AegisError.authenticationFailed
        }

        // 2. Alice's ephemeral X25519 keypair.
        let ek = X25519.generateKeyPair()

        // 3. DH values.
        // DH1 = DH(IK_A.dh, SPK_B)
        let dh1 = try X25519.sharedSecret(
            privateKey: alice.dh.privateKey,
            peerPublicKey: bundle.signedPrekey.publicKey
        )
        // DH2 = DH(EK_A, IK_B.dh)
        let dh2 = try X25519.sharedSecret(
            privateKey: ek.privateKey,
            peerPublicKey: bundle.identity.dh
        )
        // DH3 = DH(EK_A, SPK_B)
        let dh3 = try X25519.sharedSecret(
            privateKey: ek.privateKey,
            peerPublicKey: bundle.signedPrekey.publicKey
        )

        // DH4 = DH(EK_A, OPK_B) — only if Alice opts in AND
        // the bundle has an OPK available.
        var dh4: Data? = nil
        var oneTimePrekeyKeyId: UInt32? = nil
        if useOneTimePrekey, let opk = bundle.oneTimePrekeys.first {
            dh4 = try X25519.sharedSecret(
                privateKey: ek.privateKey,
                peerPublicKey: opk.publicKey
            )
            oneTimePrekeyKeyId = opk.keyId
        }

        // 4. PQ encapsulation against PQPK_B.
        let kem = MLKEM1024KEM()
        let encap = try kem.encapsulate(toPublicKey: bundle.signedPQKEMPrekey.publicKey)
        let ssPq = encap.sharedSecret.withUnsafeBytes { Data($0) }

        // 5. Derive SK via HKDF.
        let sk = deriveSharedSecret(
            dh1: dh1, dh2: dh2, dh3: dh3, dh4: dh4, ssPq: ssPq
        )

        // 6. Build the wire message.
        let message = InitialMessage(
            aliceIdentity: alice.publicKey,
            aliceEphemeralPublicKey: ek.publicKey,
            signedPrekeyKeyId: bundle.signedPrekey.keyId,
            pqKEMPrekeyKeyId: bundle.signedPQKEMPrekey.keyId,
            oneTimePrekeyKeyId: oneTimePrekeyKeyId,
            pqKEMCiphertext: encap.ciphertext,
            bundleEpoch: bundle.signedPrekeyEpoch
        )

        return InitiateResult(initialMessage: message, sharedSecret: sk)
    }

    // MARK: - Bob (responder)

    /// Bob processes Alice's initial message and derives the
    /// same shared secret Alice computed.
    ///
    /// - Parameters:
    ///   - bob: Bob's long-term identity.
    ///   - bundleSecrets: the secrets matching the bundle
    ///     Bob previously published. Must contain matching
    ///     keyIds for the (SPK, PQPK, OPK) Alice referenced.
    ///   - bundleEpoch: the SPK epoch Bob's currently-active
    ///     bundle was published with. Must match
    ///     `message.bundleEpoch` to defend against bundle
    ///     replay across rotations.
    ///   - message: Alice's initial message.
    /// - Returns: 32-byte shared secret identical to Alice's.
    /// - Throws: `AegisError.invalidKey` for missing key IDs
    ///   or epoch mismatches; `AegisError.ciphertextCorrupted`
    ///   for malformed PQ ciphertext.
    public static func respond(
        as bob: IdentityKeyPair,
        bundleSecrets: PrekeyBundleSecrets,
        bundleEpoch: UInt32,
        receiving message: InitialMessage
    ) throws -> Data {
        // 1. Replay-window check via SPK epoch.
        guard message.bundleEpoch == bundleEpoch else {
            throw AegisError.invalidKey(
                reason: "PQXDH bundle-epoch mismatch (sender used epoch \(message.bundleEpoch); current is \(bundleEpoch))"
            )
        }

        // 2. Locate the secrets matching the referenced key IDs.
        guard message.signedPrekeyKeyId == bundleSecrets.signedPrekey.keyId else {
            throw AegisError.invalidKey(
                reason: "PQXDH: signedPrekey keyId \(message.signedPrekeyKeyId) not found in our secrets"
            )
        }
        guard message.pqKEMPrekeyKeyId == bundleSecrets.signedPQKEMPrekey.keyId else {
            throw AegisError.invalidKey(
                reason: "PQXDH: pqKEMPrekey keyId \(message.pqKEMPrekeyKeyId) not found in our secrets"
            )
        }
        let opkSecret: PrekeyBundleSecrets.StoredKey?
        if let opkId = message.oneTimePrekeyKeyId {
            guard let found = bundleSecrets.oneTimePrekey(keyId: opkId) else {
                throw AegisError.invalidKey(
                    reason: "PQXDH: oneTimePrekey keyId \(opkId) not found (already retired or never published?)"
                )
            }
            opkSecret = found
        } else {
            opkSecret = nil
        }

        // 3. DH values, mirrored from Alice's.
        // DH1 = DH(SPK_B, IK_A.dh)
        let dh1 = try X25519.sharedSecret(
            privateKey: bundleSecrets.signedPrekey.privateKey,
            peerPublicKey: message.aliceIdentity.dh
        )
        // DH2 = DH(IK_B.dh, EK_A)
        let dh2 = try X25519.sharedSecret(
            privateKey: bob.dh.privateKey,
            peerPublicKey: message.aliceEphemeralPublicKey
        )
        // DH3 = DH(SPK_B, EK_A)
        let dh3 = try X25519.sharedSecret(
            privateKey: bundleSecrets.signedPrekey.privateKey,
            peerPublicKey: message.aliceEphemeralPublicKey
        )
        // DH4 = DH(OPK_B, EK_A) — only if Alice referenced an OPK.
        var dh4: Data? = nil
        if let opkSecret = opkSecret {
            dh4 = try X25519.sharedSecret(
                privateKey: opkSecret.privateKey,
                peerPublicKey: message.aliceEphemeralPublicKey
            )
        }

        // 4. PQ decapsulation.
        let kem = MLKEM1024KEM()
        let recovered = try kem.decapsulate(
            message.pqKEMCiphertext,
            with: bundleSecrets.signedPQKEMPrekey.privateKey
        )
        let ssPq = recovered.withUnsafeBytes { Data($0) }

        // 5. Derive SK.
        return deriveSharedSecret(
            dh1: dh1, dh2: dh2, dh3: dh3, dh4: dh4, ssPq: ssPq
        )
    }

    // MARK: - HKDF combiner

    /// Concatenate the inputs in PQXDH-canonical order and
    /// run them through HKDF-SHA-256. Both Alice and Bob call
    /// this with byte-identical inputs after their respective
    /// DH / KEM operations.
    static func deriveSharedSecret(
        dh1: Data,
        dh2: Data,
        dh3: Data,
        dh4: Data?,
        ssPq: Data
    ) -> Data {
        var ikm = Data()
        ikm.reserveCapacity(
            versionHedge.count + dh1.count + dh2.count + dh3.count
            + (dh4?.count ?? 0) + ssPq.count
        )
        ikm.append(versionHedge)
        ikm.append(dh1)
        ikm.append(dh2)
        ikm.append(dh3)
        if let dh4 = dh4 { ikm.append(dh4) }
        ikm.append(ssPq)

        let derived = HKDF<SHA256>.deriveKey(
            inputKeyMaterial: SymmetricKey(data: ikm),
            salt: Data(),
            info: hkdfInfo,
            outputByteCount: sharedSecretByteCount
        )
        return derived.withUnsafeBytes { Data($0) }
    }
}

/// Wire-format message Alice sends to Bob to bootstrap a
/// session. Codable; JSON for v0.x.
public struct InitialMessage: Sendable, Codable, Equatable {

    /// Alice's identity (signing + DH public keys).
    public let aliceIdentity: IdentityPublicKey

    /// Alice's ephemeral X25519 public key. 32 bytes.
    public let aliceEphemeralPublicKey: Data

    /// keyId of the SPK Alice used (which one of Bob's
    /// rotation epochs).
    public let signedPrekeyKeyId: UInt32

    /// keyId of the PQ-KEM prekey Alice used.
    public let pqKEMPrekeyKeyId: UInt32

    /// keyId of the OPK Alice used; nil if she opted out or
    /// no OPK was available.
    public let oneTimePrekeyKeyId: UInt32?

    /// 1568-byte ML-KEM-1024 ciphertext.
    public let pqKEMCiphertext: Data

    /// Snapshot of `bundle.signedPrekeyEpoch` when Alice ran
    /// the handshake. Bob compares this against his
    /// currently-active epoch to defend against using a
    /// retired bundle.
    public let bundleEpoch: UInt32

    public init(
        aliceIdentity: IdentityPublicKey,
        aliceEphemeralPublicKey: Data,
        signedPrekeyKeyId: UInt32,
        pqKEMPrekeyKeyId: UInt32,
        oneTimePrekeyKeyId: UInt32?,
        pqKEMCiphertext: Data,
        bundleEpoch: UInt32
    ) {
        self.aliceIdentity = aliceIdentity
        self.aliceEphemeralPublicKey = aliceEphemeralPublicKey
        self.signedPrekeyKeyId = signedPrekeyKeyId
        self.pqKEMPrekeyKeyId = pqKEMPrekeyKeyId
        self.oneTimePrekeyKeyId = oneTimePrekeyKeyId
        self.pqKEMCiphertext = pqKEMCiphertext
        self.bundleEpoch = bundleEpoch
    }
}
