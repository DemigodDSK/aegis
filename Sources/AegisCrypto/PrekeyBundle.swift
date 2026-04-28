// PrekeyBundle.swift
// Bob's published prekey bundle — the artefact Alice fetches
// from the server before initiating a PQXDH handshake.
//
// A prekey bundle is structured the way Signal's PQXDH spec
// structures it, with one local refinement:
//
//   - Identity (IK)              long-term, signing + DH (this is
//                                already `IdentityPublicKey`).
//   - Signed prekey (SPK)        medium-term X25519 key, signed
//                                by IK_signing.
//   - Signed PQ-KEM prekey (PQPK) medium-term ML-KEM-1024 key,
//                                signed by IK_signing.
//   - One-time prekeys (OPKs)    short-lived X25519 keys; we
//                                sign EACH one individually (some
//                                Signal implementations rely on
//                                bundle-level freshness instead).
//
// Each signature covers `DOMAIN_SEPARATOR || uint32BE(keyId) ||
// publicKey`. The domain separator differs per role — an SPK
// signature must not be replayable as an OPK or PQPK signature.
//
// Wire format: JSON via `Codable` for v0.x. Binary framing is a
// v1.0 task. The on-the-wire structure is documented by the
// public properties of the structs in this file.

import Foundation

/// Bob's prekey bundle — the public, server-publishable record
/// Alice fetches before sending her first message.
public struct PrekeyBundle: Sendable, Codable, Equatable {

    /// Bob's long-term identity (signing + DH public keys).
    public let identity: IdentityPublicKey

    /// Bob's medium-term X25519 prekey. Signed by IK_signing.
    public let signedPrekey: SignedPrekey

    /// Bob's medium-term ML-KEM-1024 prekey. Signed by
    /// IK_signing. Used as the post-quantum component in
    /// PQXDH.
    public let signedPQKEMPrekey: SignedPQKEMPrekey

    /// Optional one-time X25519 prekeys. Each is signed by
    /// IK_signing. Alice picks one, references it by keyId in
    /// her initial message, and Bob's server retires it.
    public let oneTimePrekeys: [OneTimePrekey]

    /// Server-side bundle identifier. Useful for rotation
    /// tracking and replay detection on the server, optional
    /// for direct (server-less) use.
    public let bundleId: UUID

    /// When this bundle was generated. Encoded as ISO-8601 in
    /// the JSON form. Bob's clients use this to decide when to
    /// publish a fresh bundle.
    public let createdAt: Date

    /// Monotonically-increasing epoch for SPK rotation. A peer
    /// who already knows SPK epoch N can refuse to accept a
    /// later bundle with epoch < N (replay defence at the
    /// session-cache level).
    public let signedPrekeyEpoch: UInt32

    public init(
        identity: IdentityPublicKey,
        signedPrekey: SignedPrekey,
        signedPQKEMPrekey: SignedPQKEMPrekey,
        oneTimePrekeys: [OneTimePrekey],
        bundleId: UUID,
        createdAt: Date,
        signedPrekeyEpoch: UInt32
    ) {
        self.identity = identity
        self.signedPrekey = signedPrekey
        self.signedPQKEMPrekey = signedPQKEMPrekey
        self.oneTimePrekeys = oneTimePrekeys
        self.bundleId = bundleId
        self.createdAt = createdAt
        self.signedPrekeyEpoch = signedPrekeyEpoch
    }
}

/// X25519 medium-term prekey + ML-DSA-65 signature.
public struct SignedPrekey: Sendable, Codable, Equatable {
    public let keyId: UInt32
    public let publicKey: Data    // 32-byte X25519
    public let signature: Data    // ML-DSA-65
    public let createdAt: Date

    public init(keyId: UInt32, publicKey: Data, signature: Data, createdAt: Date) {
        self.keyId = keyId
        self.publicKey = publicKey
        self.signature = signature
        self.createdAt = createdAt
    }
}

/// ML-KEM-1024 medium-term PQ prekey + ML-DSA-65 signature.
public struct SignedPQKEMPrekey: Sendable, Codable, Equatable {
    public let keyId: UInt32
    public let publicKey: Data    // 1568-byte ML-KEM-1024
    public let signature: Data    // ML-DSA-65
    public let createdAt: Date

    public init(keyId: UInt32, publicKey: Data, signature: Data, createdAt: Date) {
        self.keyId = keyId
        self.publicKey = publicKey
        self.signature = signature
        self.createdAt = createdAt
    }
}

/// One-time X25519 prekey + ML-DSA-65 signature.
public struct OneTimePrekey: Sendable, Codable, Equatable {
    public let keyId: UInt32
    public let publicKey: Data    // 32-byte X25519
    public let signature: Data    // ML-DSA-65

    public init(keyId: UInt32, publicKey: Data, signature: Data) {
        self.keyId = keyId
        self.publicKey = publicKey
        self.signature = signature
    }
}

/// The private side of a PrekeyBundle that Bob retains to
/// answer Alice's initial message. NOT serialised to the wire.
public struct PrekeyBundleSecrets: Sendable {

    public struct StoredKey: Sendable {
        public let keyId: UInt32
        public let privateKey: Data

        public init(keyId: UInt32, privateKey: Data) {
            self.keyId = keyId
            self.privateKey = privateKey
        }
    }

    public let signedPrekey: StoredKey
    public let signedPQKEMPrekey: StoredKey
    public let oneTimePrekeys: [StoredKey]

    public init(
        signedPrekey: StoredKey,
        signedPQKEMPrekey: StoredKey,
        oneTimePrekeys: [StoredKey]
    ) {
        self.signedPrekey = signedPrekey
        self.signedPQKEMPrekey = signedPQKEMPrekey
        self.oneTimePrekeys = oneTimePrekeys
    }

    /// Find the OPK secret matching `keyId`, if Alice picked
    /// one. Returns nil if Alice's initial message did not use
    /// an OPK or the OPK has already been retired.
    public func oneTimePrekey(keyId: UInt32) -> StoredKey? {
        oneTimePrekeys.first { $0.keyId == keyId }
    }
}

// MARK: - Generation + verification

extension PrekeyBundle {

    /// Domain separators for prekey signatures. Each role gets
    /// a distinct prefix so that an SPK signature cannot be
    /// replayed as an OPK or PQPK signature, and vice versa.
    /// Versioned (`_v1`) so a future scheme change is loud.
    enum SignContext {
        static let signedPrekey = Data("AEGIS_SPK_v1".utf8)
        static let signedPQKEMPrekey = Data("AEGIS_PQPK_v1".utf8)
        static let oneTimePrekey = Data("AEGIS_OPK_v1".utf8)
    }

    /// Construct the canonical bytes that get signed for a
    /// given prekey role. Caller-side and verifier-side MUST
    /// produce the identical byte string.
    static func signedBytes(
        context: Data,
        keyId: UInt32,
        publicKey: Data
    ) -> Data {
        var buffer = Data()
        buffer.reserveCapacity(context.count + 4 + publicKey.count)
        buffer.append(context)
        var be = keyId.bigEndian
        withUnsafeBytes(of: &be) { buffer.append(contentsOf: $0) }
        buffer.append(publicKey)
        return buffer
    }

    /// Generate a fresh prekey bundle for `identity`. Returns
    /// the publishable bundle and the secrets Bob retains.
    ///
    /// - Parameters:
    ///   - identity: Bob's long-term identity.
    ///   - oneTimePrekeyCount: how many OPKs to generate. The
    ///     server will retire them as Alice consumes them; the
    ///     default 100 covers a typical refresh interval.
    ///   - signedPrekeyEpoch: monotonic counter for SPK
    ///     rotation; pass the previous epoch + 1.
    ///   - now: clock injection (defaults to `Date()`). The
    ///     value is truncated to integer second precision so
    ///     it round-trips exactly through the JSON wire format
    ///     (ISO-8601 default precision). Sub-second precision
    ///     is unnecessary for prekey-bundle freshness.
    public static func generate(
        identity: IdentityKeyPair,
        oneTimePrekeyCount: Int = 100,
        signedPrekeyEpoch: UInt32 = 1,
        now: Date = Date()
    ) throws -> (bundle: PrekeyBundle, secrets: PrekeyBundleSecrets) {
        precondition(oneTimePrekeyCount >= 0, "oneTimePrekeyCount cannot be negative")

        // Truncate to integer second precision — see docstring.
        let now = Date(timeIntervalSince1970: floor(now.timeIntervalSince1970))

        let signer = MLDSA65Signature()
        let pqkem = MLKEM1024KEM()

        // SPK — X25519, signed.
        let spkKeyId = randomNonzeroUInt32()
        let spkPair = X25519.generateKeyPair()
        let spkBytes = signedBytes(
            context: SignContext.signedPrekey,
            keyId: spkKeyId,
            publicKey: spkPair.publicKey
        )
        let spkSig = try signer.sign(spkBytes, with: identity.signing.privateKey)
        let signedSpk = SignedPrekey(
            keyId: spkKeyId,
            publicKey: spkPair.publicKey,
            signature: spkSig,
            createdAt: now
        )

        // PQPK — ML-KEM-1024, signed.
        let pqpkKeyId = randomNonzeroUInt32()
        let pqpkPair = try pqkem.generateKeyPair()
        let pqpkBytes = signedBytes(
            context: SignContext.signedPQKEMPrekey,
            keyId: pqpkKeyId,
            publicKey: pqpkPair.publicKey
        )
        let pqpkSig = try signer.sign(pqpkBytes, with: identity.signing.privateKey)
        let signedPqpk = SignedPQKEMPrekey(
            keyId: pqpkKeyId,
            publicKey: pqpkPair.publicKey,
            signature: pqpkSig,
            createdAt: now
        )

        // OPKs — N × X25519, each signed.
        var opks: [OneTimePrekey] = []
        var opkSecrets: [PrekeyBundleSecrets.StoredKey] = []
        opks.reserveCapacity(oneTimePrekeyCount)
        opkSecrets.reserveCapacity(oneTimePrekeyCount)
        for _ in 0..<oneTimePrekeyCount {
            let id = randomNonzeroUInt32()
            let pair = X25519.generateKeyPair()
            let bytes = signedBytes(
                context: SignContext.oneTimePrekey,
                keyId: id,
                publicKey: pair.publicKey
            )
            let sig = try signer.sign(bytes, with: identity.signing.privateKey)
            opks.append(OneTimePrekey(
                keyId: id, publicKey: pair.publicKey, signature: sig
            ))
            opkSecrets.append(.init(keyId: id, privateKey: pair.privateKey))
        }

        let bundle = PrekeyBundle(
            identity: identity.publicKey,
            signedPrekey: signedSpk,
            signedPQKEMPrekey: signedPqpk,
            oneTimePrekeys: opks,
            bundleId: UUID(),
            createdAt: now,
            signedPrekeyEpoch: signedPrekeyEpoch
        )
        let secrets = PrekeyBundleSecrets(
            signedPrekey: .init(keyId: spkKeyId, privateKey: spkPair.privateKey),
            signedPQKEMPrekey: .init(keyId: pqpkKeyId, privateKey: pqpkPair.privateKey),
            oneTimePrekeys: opkSecrets
        )
        return (bundle, secrets)
    }

    /// Verify every signature in this bundle against the
    /// embedded identity. Returns `true` iff every prekey is a
    /// valid signature by `identity.signing`.
    ///
    /// - Throws: `AegisError.invalidKey` if any embedded public
    ///   key is structurally malformed (size mismatch).
    public func verify() throws -> Bool {
        let signer = MLDSA65Signature()

        // Structural size checks first — Apple's CryptoKit can
        // trap on too-short keys for some primitives. We
        // surface a clean error before reaching the verify
        // path.
        guard identity.signing.count == 1952 else {
            throw AegisError.invalidKey(reason: "identity signing key wrong size")
        }
        guard signedPrekey.publicKey.count == X25519.publicKeyByteCount else {
            throw AegisError.invalidKey(reason: "signed prekey wrong size")
        }
        guard signedPQKEMPrekey.publicKey.count == MLKEM1024KEM.publicKeyByteCount else {
            throw AegisError.invalidKey(reason: "PQ-KEM prekey wrong size")
        }
        for opk in oneTimePrekeys {
            guard opk.publicKey.count == X25519.publicKeyByteCount else {
                throw AegisError.invalidKey(reason: "one-time prekey wrong size")
            }
        }

        let spkBytes = Self.signedBytes(
            context: SignContext.signedPrekey,
            keyId: signedPrekey.keyId,
            publicKey: signedPrekey.publicKey
        )
        guard try signer.isValidSignature(
            signedPrekey.signature,
            of: spkBytes,
            by: identity.signing
        ) else { return false }

        let pqpkBytes = Self.signedBytes(
            context: SignContext.signedPQKEMPrekey,
            keyId: signedPQKEMPrekey.keyId,
            publicKey: signedPQKEMPrekey.publicKey
        )
        guard try signer.isValidSignature(
            signedPQKEMPrekey.signature,
            of: pqpkBytes,
            by: identity.signing
        ) else { return false }

        for opk in oneTimePrekeys {
            let bytes = Self.signedBytes(
                context: SignContext.oneTimePrekey,
                keyId: opk.keyId,
                publicKey: opk.publicKey
            )
            guard try signer.isValidSignature(
                opk.signature,
                of: bytes,
                by: identity.signing
            ) else { return false }
        }

        return true
    }
}

/// Sample a 32-bit non-zero key id from the system CSPRNG.
/// Zero is reserved for "no key" sentinel use elsewhere.
private func randomNonzeroUInt32() -> UInt32 {
    while true {
        var bytes = [UInt8](repeating: 0, count: 4)
        let status = bytes.withUnsafeMutableBytes { buf in
            SecRandomCopyBytes(kSecRandomDefault, buf.count, buf.baseAddress!)
        }
        precondition(status == errSecSuccess, "SecRandomCopyBytes failed")
        let id = bytes.withUnsafeBytes { $0.load(as: UInt32.self) }
        if id != 0 { return id }
    }
}
