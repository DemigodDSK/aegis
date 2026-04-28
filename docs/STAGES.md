# Aegis — Sprint Roadmap

This document tracks the per-sprint deliverables for Aegis. Each
sprint produces a tagged release (`v0.X.Y-sprint-N`) and a
verifiable artefact (passing `swift test`, runnable demo, or
a signed canary). No sprint is "complete" until its acceptance
criteria are demonstrably met.

For the larger project mission and constraints, see
[MISSION.md](../MISSION.md). For governance of how these sprints
are reviewed and merged, see [GOVERNANCE.md](../GOVERNANCE.md).

---

## Status legend

| Symbol | Meaning |
|---|---|
| ✅ | Shipped (tagged release exists) |
| 🚧 | In progress |
| 📋 | Planned, not started |
| ⏸️ | Blocked or deferred |

---

## v0.0.1 — Foundation ✅

**Tagged:** `v0.0.1-foundation`
**Goal:** establish project identity, governance, and licensing.

Deliverables:
- [x] MISSION.md, THREAT-MODEL.md, GOVERNANCE.md, ALGORITHM-SUBMISSION.md
- [x] README.md, SECURITY.md, CONTRIBUTING.md
- [x] CLA.md (v1.0), CODE_OF_CONDUCT.md (Contributor Covenant 2.1)
- [x] LICENSE (AGPL v3)
- [x] CONTRIBUTORS.md, CONFLICTS.md, audit-history.md
- [x] First warrant canary (`canary/2026-04.txt`)
- [x] Repository created, public, on GitHub

---

## v0.0.2 — AegisCrypto + AES-256-GCM ✅

**Tagged:** `v0.0.2-sprint-1`
**Goal:** ship the first real cryptography. Establish the
algorithm-agnostic seam (`Encryption` protocol) so future
algorithms slot in without architectural changes.

Deliverables:
- [x] `Package.swift` (SwiftPM, no third-party deps)
- [x] `Sources/AegisCrypto/Encryption.swift` (protocol + `EncryptedPayload`)
- [x] `Sources/AegisCrypto/EncryptionMethod.swift` (Tier 1 / Tier 2 metadata)
- [x] `Sources/AegisCrypto/AegisError.swift` (exhaustive error enum)
- [x] `Sources/AegisCrypto/Tier1/AESGCM.swift` (CryptoKit-backed)
- [x] `Tests/AegisCryptoTests/AESGCMTests.swift` (~25 contract tests)
- [x] `Tests/AegisCryptoTests/AESGCMKATTests.swift` (NIST CAVP vectors)
- [x] `swift test` exits 0 with 22 passing / 3 documented skips

Known issue: 3 tests skipped due to a CryptoKit SIGTRAP in
macOS 26.x — see [issue #1](https://github.com/DemigodDSK/aegis/issues/1).

---

## v0.0.2.1 — Polish ✅

**Tagged:** `v0.0.2.1-polish`
**Goal:** make the repo look professional to outside contributors.
No new cryptography.

Deliverables:
- [x] GitHub repo "About" sidebar (description + topics)
- [x] GitHub Actions CI (`build` + `test` on every push)
- [x] `docs/STAGES.md` (this file)
- [x] `.github/ISSUE_TEMPLATE/` (algorithm submission + bug report)
- [x] `.editorconfig`

PGP-key / canary-signing work originally listed here shipped
separately as v0.0.2.2-pgp; see below.

---

## v0.0.2.2 — Maintainer PGP identity ✅

**Tagged:** `v0.0.2.2-pgp`
**Goal:** establish the cryptographic identity used for signing
warrant canaries, releases, and GOVERNANCE-required attestations.

Deliverables:
- [x] Maintainer ed25519 + cv25519 keypair generated
      (fingerprint `E7B6 56B4 D0DD BB07 29ED 462F FF11 64C0 B4D2 8DE4`,
      expires 2028-04-26)
- [x] Public key committed to `.well-known/security.asc`
- [x] Public key published on `keys.openpgp.org`
- [x] Inaugural warrant canary signed (`canary/2026-04.txt.asc`,
      verifies cleanly)
- [x] Fingerprint embedded in `SECURITY.md` with verification steps
- [x] Revocation certificate generated and backed up off-repo

---

## v0.0.3 — Sprint 2: ML-KEM-768 + X25519 hybrid ✅

**Tagged:** `v0.0.3-sprint-2`
**Goal:** post-quantum key encapsulation. This is the headline
feature — what makes Aegis genuinely *post-quantum* rather than
just "AES-GCM in a wrapper".

Tracking issue: [#3](https://github.com/DemigodDSK/aegis/issues/3)

Deliverables:
- [x] Investigate Apple CryptoKit ML-KEM availability — see Conscious
      Deviation below. Apple ships native PQC on macOS 26 / iOS 26.
- [x] Bump `Package.swift` platform minimums to iOS 26 / macOS 26
      (and update CI runners to `macos-26` to match)
- [x] `KeyEncapsulation` protocol (parallel to `Encryption`)
- [x] `Sources/AegisCrypto/Tier1/HybridKEM.swift` — thin wrapper over
      Apple's `XWingMLKEM768X25519`, conforming to `KeyEncapsulation`
- [x] X-Wing KAT vectors passing (3 vectors from
      draft-connolly-cfrg-xwing-kem; KeyGen + Decap × 2 paths)
- [x] Standalone `MLKEM768` KAT against NIST FIPS 203 KeyGen
      (25 vectors mirrored from BoringSSL's NIST-ACVP corpus).
      Decap KATs are shipped for completeness but not consumed:
      Apple's API does not accept raw FIPS 203 `dk` bytes —
      see `Tests/AegisCryptoTests/Vectors/README.md`.
- [x] Tag `v0.0.3-sprint-2`

Test status at tag: 51 tests, 3 skipped (pre-existing AES-GCM
CryptoKit-trap cases — see [issue #1](https://github.com/DemigodDSK/aegis/issues/1)),
0 failures.

Out of scope (deferred to later sprints):
- Key-exchange protocol (X3DH-equivalent) — Sprint 3.
- Identity signatures (ML-DSA-65) — Sprint 3.
- The concat+HKDF combiner as an Aegis Lab Tier 2 experiment —
  Year 2.

### Conscious deviation — X-Wing instead of concat+HKDF

**Original plan (this document, pre-2026-04-27):** build a
hand-rolled hybrid combining standalone `MLKEM768` and X25519 via
the IETF concat+HKDF combiner.

**Revised plan:** wrap Apple's `XWingMLKEM768X25519`, which is a
different but equally IETF-track hybrid construction
(draft-connolly-cfrg-xwing-kem; deployed in Apple's iMessage PQ3).

**Why the change:**

1. **Less crypto-core surface area.** A concat+HKDF combiner is
   ~30 lines of Swift we would own and have to keep audited.
   `XWingMLKEM768X25519` is zero lines we own.
2. **Already deployed and reviewed.** iMessage PQ3 ships X-Wing in
   production; the construction has both a peer-reviewed paper
   (Bernstein, Connolly, Schwabe, Westerbaan, Wiggers, 2024) and an
   active IETF draft.
3. **Secure Enclave integration is free.** Apple exposes
   SE-backed PQ private keys (`SecureEnclave.MLKEM768`); rolling our
   own combiner forfeits that.
4. **Aligns with working principle 4** (no creative cryptography in
   Tier 1): X-Wing is a published primitive used by Apple, not
   something we are inventing.

**What we are giving up:**

- Pinned to Apple's choice of combiner. If the IRTF process
  eventually publishes a different combiner as "the" hybrid
  standard, we will need to reconsider.
- Cannot test this primitive against generic ML-KEM-768 KAT
  vectors directly (those test the underlying KEM, not X-Wing).
  We test via X-Wing's own KAT vectors and via CryptoKit's
  standalone `MLKEM768` against NIST FIPS 203 KATs.

**Where concat+HKDF goes instead:** it ships as the inaugural
**Aegis Lab Tier 2** experiment (Year 2). That is exactly what
Tier 2 is for — clearly-marked alternative constructions that
users can opt into.

**Approval:** `pre-council-approval`, Maintainer (@DemigodDSK),
2026-04-27.

---

## v0.0.4 — Sprint 3: ML-DSA-65 signatures ✅

**Tagged:** `v0.0.4-sprint-3`
**Goal:** ship Aegis's first post-quantum signature primitive.
Standalone signatures unlock identity bootstrap, prekey signing,
and any future protocol that needs authenticated artefacts.

Deliverables:
- [x] `Signature` protocol (parallel to `Encryption` and
      `KeyEncapsulation`)
- [x] `Sources/AegisCrypto/Tier1/MLDSA65.swift` — `MLDSA65Signature`
      wrapping Apple's `CryptoKit.MLDSA65`
- [x] NIST FIPS 204 KeyGen KAT vectors passing — 25 vectors
      mirrored from BoringSSL's NIST-ACVP corpus
- [x] Wycheproof verify-side KAT vectors passing — 160 tests
      across 24 groups including malformed-key, edge-case, and
      FIPS 204 context-extension cases
- [x] Tag `v0.0.4-sprint-3`

Test status at tag: 73 tests, 3 skipped (pre-existing AES-GCM
CryptoKit-trap cases — see [issue #1](https://github.com/DemigodDSK/aegis/issues/1)),
0 failures.

Out of scope (deferred by the split below):
- Identity keypair persistence (Keychain) — Sprint 6, bundled
  with the iOS app shell that exercises it.
- PQXDH key-exchange handshake — Sprint 4.
- Safety-number derivation — Sprint 4.
- FIPS 204 "context" extension at the public Signature
  protocol — held until a concrete user (Sprint 4 PQXDH) shows
  up. The underlying CryptoKit primitive supports it and the
  Wycheproof KATs already exercise it directly.

Out of scope (deferred by the split below):
- Identity keypair persistence (Keychain) — Sprint 6, bundled
  with the iOS app shell that exercises it.
- PQXDH key-exchange handshake — Sprint 4.
- Safety-number derivation — Sprint 4.

### Conscious deviation — split Sprint 3 into 3 (signatures) and 4 (PQXDH)

**Original plan (this document, pre-2026-04-27 second amendment):**
single Sprint 3 (`v0.0.4-sprint-3`) covering signatures, identity
keypair + Keychain, PQXDH-style handshake, and safety numbers.

**Revised plan:** split into two sprints (each subsequent sprint
shifts by one version slot), and bundle Keychain integration with
the iOS app shell that actually exercises it:

  - v0.0.4 / Sprint 3 — ML-DSA-65 signatures only.
  - v0.0.5 / Sprint 4 — PQXDH key exchange + safety numbers
    (NEW; was forward secrecy).
  - v0.0.6 / Sprint 5 — Forward secrecy / Double Ratchet
    (was Sprint 4).
  - v0.0.7 / Sprint 6 — iOS app shell + Keychain identity-key
    persistence (was Sprint 5; Keychain pulled in from old
    Sprint 3).
  - v0.0.8 / Sprint 7 — Persistence (was Sprint 6).
  - v0.0.9 / Sprint 8 — Networking (was Sprint 7).
  - v0.1.0 / Sprint 9 — First public alpha (was Sprint 8).

**Note:** subsequent slots were further amended by the
Sprint 6 → 7 split (see the v0.0.8 deviation below). Current
mapping is: Sprint 7 = iOS distribution, Sprint 8 =
Persistence, Sprint 9 = Networking, Sprint 10 = alpha.

**Why the change:**

1. **Keychain without a runtime is speculative infrastructure.**
   iOS Keychain has policy choices (SE-backed, biometric, iCloud
   sync) that warrant the app context they protect. Sprint 6
   (iOS app shell) is when those choices become concrete.
2. **Signatures are independent.** ML-DSA-65 is useful before any
   protocol layer needs it (tests, future tooling), and is a
   short primitive wrap mirroring Sprint 2's HybridKEM. No
   reason to gate it behind PQXDH design work.
3. **PQXDH design deserves a sprint.** Defining bundle types,
   initial-message wire format, and the DH chain interleaving is
   genuinely a sprint of work, not a same-sprint task.
4. **Forward secrecy logically follows PQXDH** (the ratchet needs
   a session to rotate from), so reordering v0.0.5/v0.0.6
   improves the build order rather than disturbing it.

**What we are giving up:**

- Each downstream sprint's version number shifts by 1 (v0.0.5
  → v0.0.6 etc.). The *content* of each sprint stays the same;
  only the numbering moves.
- v0.1.0 (TestFlight alpha) drifts one sprint later. Aegis
  acknowledged from the outset (MISSION.md) that we will trade
  timeline for correctness, not the reverse.

**Approval:** `pre-council-approval`, Maintainer (@DemigodDSK),
2026-04-27.

---

## v0.0.5 — Sprint 4: PQXDH key exchange + safety numbers ✅

**Tagged:** `v0.0.5-sprint-4`
**Goal:** Aegis can establish a secure session between two
parties who have never communicated before. After this sprint,
end-to-end E2EE bootstrap becomes genuinely real.

Deliverables:
- [x] PQXDH-style key-exchange handshake (`PQXDH.initiate` /
      `PQXDH.respond`). PQ-KEM choice: bare ML-KEM-1024
      (Cat-5), matching Signal's PQXDH spec exactly. The
      X-Wing hybrid is reserved for end-to-end-message KEM
      use; PQXDH already supplies the X25519 component via
      its X3DH chain, so layering X-Wing inside would
      double up.
- [x] Identity, signed-prekey, one-time-prekey, and PQ-KEM
      prekey types (`IdentityPublicKey`, `SignedPrekey`,
      `SignedPQKEMPrekey`, `OneTimePrekey`, `PrekeyBundle`)
      with explicit JSON wire format and per-role
      domain-separated signatures, plus `signedPrekeyEpoch`
      for rotation-aware replay defence.
- [x] Initial-message format (`InitialMessage`) with full
      signature-chain verification on the responder side.
- [x] Per-user identity keypair generation
      (`IdentityKeyPair.generate()`, in-memory only;
      Keychain persistence arrives in Sprint 6).
- [x] Safety-number derivation (`SafetyNumber.compute(local:
      remote:)`) — 12 groups × 5 digits, Signal format
      compatible, order-independent, 5200-iteration SHA-512.
- [x] PQXDH self-consistency tests: 20+ PQXDH cases plus the
      surrounding identity / prekey-bundle / safety-number
      suites covering round-trip with/without OPK, freshness
      across sessions, epoch / keyId / signature-chain
      rejection, JSON round-trip of InitialMessage.
      Optional libsignal interop deferred to
      [#10](https://github.com/DemigodDSK/aegis/issues/10).
- [x] Tag `v0.0.5-sprint-4`

New Tier 1 surface added in this sprint:
- `MLKEM1024KEM` — bare ML-KEM-1024 (FIPS 203 Cat-5),
  intended for protocol-internal use alongside ECDH (vs
  HybridKEM, which is for AEAD-bootstrap end-to-end use).
- `X25519` namespace + `DHKeyPair` envelope.

Test status at tag: 148 tests, 3 skipped (pre-existing
AES-GCM CryptoKit-trap cases — see [issue #1](https://github.com/DemigodDSK/aegis/issues/1)),
0 failures.

Out of scope:
- Forward secrecy ratcheting — Sprint 5.
- Network transport — Sprint 9.

---

## v0.0.6 — Sprint 5: Forward secrecy ✅

**Tagged:** `v0.0.6-sprint-5`
**Goal:** Double Ratchet. After this, compromising one session
key does not compromise past or future sessions.

Deliverables:
- [x] `RatchetSession` type — bidirectional state, encrypt /
      decrypt, DH-ratchet step orchestration, seeded from a
      PQXDH-derived 32-byte shared secret.
- [x] Out-of-order message handling — late arrivals decrypt
      via the skipped-keys cache, including across DH
      rotations (a straggler from a long-since-retired chain
      still decrypts cleanly).
- [x] Skipped-message keys cache with bounded retention —
      LRU eviction at 1000 entries (`maxSkippedKeysCache`),
      per-message catch-up budget of 1000
      (`maxSkipPerInboundMessage`) so a forged
      far-future-messageNumber cannot pin CPU.
- [x] Migration test: `PQXDHRatchetIntegrationTests` runs the
      full Sprint 4 → Sprint 5 stack on every assertion —
      bootstrap from PrekeyBundle + PQXDH, hand off SK to
      `initiateAsAlice` / `initiateAsBob`, exchange real
      bidirectional ratchet messages with DH rotations and
      out-of-order arrivals.
- [x] Tag `v0.0.6-sprint-5`

New surface added in this sprint:
- `ChainKey` / `MessageKey` / `DerivedMessageKeys` —
  symmetric-ratchet primitives (HMAC-based advancement +
  HKDF expansion to AES-256-GCM keys/nonces).
- `RootKey` — outer-ratchet root key with `KDF_RK`-style
  HKDF derivation step.
- `RatchetSession` + `RatchetMessage` + `RatchetMessageHeader` —
  the user-facing Double Ratchet with header AAD binding.

Construction labels (versioned for loud future scheme changes):
  symmetric-ratchet HMAC tags `0x01` / `0x02`,
  message-key HKDF info `"AEGIS_RATCHET_MK_v1"`,
  root-key HKDF info `"AEGIS_RATCHET_RK_v1"`.

Test status at tag: 191 tests, 3 skipped (pre-existing
AES-GCM CryptoKit-trap cases — see [issue #1](https://github.com/DemigodDSK/aegis/issues/1)),
0 failures.

Out of scope (deferred):
- Header encryption (HE) — Signal's encrypted-header variant;
  surfaces noted as future enhancement in the file headers.
- Keychain / Secure Enclave persistence of ratchet state —
  Sprint 6 (combined with the iOS app shell).
- Post-compromise security beyond the per-DH-step scope —
  inherent to the Double Ratchet; nothing to add.

---

## v0.0.7 — Sprint 6: iOS app shell + Keychain identity ✅

**Tagged:** `v0.0.7-sprint-6`
**Goal:** first visible Aegis. A SwiftUI app target that
demonstrates the cryptographic stack in a UI, AND introduces
persistent identity keys backed by the iOS Keychain.

Deliverables:
- [x] `Sources/AegisApp/` SwiftUI target — `AegisTheme`,
      `AppState`, `RootView`, `OnboardingFlow`,
      `IdentitySetupScreen`, `DemoScreen` + `DemoViewModel`,
      `SettingsScreen`, `Capability`, `MainTabView`. Same
      surface targets iOS today; Sprint 7 wraps it in an
      Xcode project for distribution.
- [x] Demo screen: passphrase → encrypt → display the
      AES-256-GCM ciphertext envelope (methodId, nonce,
      ciphertext, tag in monospaced base64) → decrypt.
      Wrong-passphrase path surfaces AEAD authentication
      failure cleanly.
- [x] Settings → Security view rendering the live capability
      table — 14 rows pulled from `Capability.all`, mirroring
      THREAT-MODEL.md §"Cryptographic guarantees by version".
      Drift is partially caught by `CapabilityTests`.
- [x] Onboarding flow per THREAT-MODEL.md §"In-app honesty"
      §"First-launch onboarding (mandatory, cannot be
      skipped)". Three screens, no skip, including the
      Screen-3 "Use Signal instead" disclosure for
      life-or-liberty threat models.
- [x] AegisStorage module — Keychain wrapper for identity
      keypairs. Defaults to
      `kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly`,
      never sets `kSecAttrSynchronizable` (no iCloud
      Keychain sync of private keys). Explicit
      `KeychainAccessibility` enum lets callers opt into
      `whenUnlockedThisDeviceOnly` /
      `whenPasscodeSetThisDeviceOnly` per write. Signed
      prekeys and SE-backed `SecureEnclave.MLKEM768/1024 /
      MLDSA65` storage paths are scoped for Sprint 7+ when
      a real persistent peer session needs them.
- [x] `aegis-demo` macOS executable target — `swift run
      aegis-demo` opens a real SwiftUI window today.
- [x] Tag `v0.0.7-sprint-6`

New surface in this sprint:
- `AegisStorage` library target (Keychain CRUD,
  `KeychainAccessibility`, `KeychainStorageError`).
- `AegisApp` library target (SwiftUI views, AppState,
  Capability, theme).
- `aegis-demo` executable target.

Conscious deferrals (now their own follow-up issues):
- iOS Xcode project + TestFlight distribution → Sprint 7.
  The SwiftUI views work on iOS today; Sprint 7 just adds
  the .xcodeproj wrapper, signing, and IPA pipeline.
- SE-backed `SecureEnclave.MLKEM768/1024` and
  `SecureEnclave.MLDSA65` persistence paths → Sprint 7+ as
  per-peer ratchet/prekey-bundle persistence is added.
- Code-gen between THREAT-MODEL.md's capability table and
  `Capability.all` so the two cannot drift → polish.

Test status at tag: 224 tests, 3 skipped (pre-existing
AES-GCM CryptoKit-trap cases — see [issue #1](https://github.com/DemigodDSK/aegis/issues/1)),
0 failures.

Out of scope:
- Persistent message storage — Sprint 8 (after the
  Sprint 6 → 7 split below).
- Network transport — Sprint 9.

---

## v0.0.8 — Sprint 7: iOS distribution (Xcode + IPA + TestFlight) 📋

**Goal:** package the SwiftUI surface that Sprint 6 shipped as
an installable iOS app — Xcode project, signing, App Icon,
entitlements, App Store Connect setup, and a TestFlight
build the maintainer can install on their own device.

Deliverables:
- [ ] `Aegis.xcodeproj` wrapping the AegisApp + AegisStorage
      + AegisCrypto SwiftPM products
- [ ] App Icon (1024×1024 + iOS asset-catalog set), splash
      screen, basic Info.plist
- [ ] Entitlements: Keychain access group, push-notification
      capability (no UI consumer yet but provisioned for the
      Sprint 9 networking sprint)
- [ ] Code-signing certificate + provisioning profile via
      App Store Connect (maintainer-only at this stage)
- [ ] First TestFlight build pushed to internal testers
      (just the maintainer)
- [ ] Smoke-test: install on a real iPhone, complete
      onboarding, generate identity, run encrypt/decrypt
      demo
- [ ] Tag `v0.0.8-sprint-7`

### Conscious deviation — split iOS distribution from Sprint 6

**Original plan (this document, pre-2026-04-28 third
amendment):** Sprint 6 was supposed to deliver "iOS app
shell + Keychain identity persistence", implicitly via an
iOS Xcode project + TestFlight pipeline. The Sprint 3 split
deferred Keychain integration into Sprint 6; iOS
distribution rode along.

**Revised plan:** the user-visible-app concern is split
from the IPA-distribution concern.

  - v0.0.7 / Sprint 6 (already shipped): SwiftUI surface
    (`AegisApp` library + `aegis-demo` macOS executable) +
    `AegisStorage` Keychain wrapper. Visible app today via
    `swift run aegis-demo`.
  - v0.0.8 / Sprint 7 (this entry, NEW): iOS Xcode project
    + IPA + TestFlight. The SwiftUI views compile for iOS
    today; this sprint adds the wrapper.
  - v0.0.9 / Sprint 8: Persistence (was Sprint 7).
  - v0.0.10 / Sprint 9: Networking (was Sprint 8).
  - v0.1.0 / Sprint 10: First public alpha (was Sprint 9);
    "TestFlight build available" deliverable moves to
    Sprint 7 here.

**Why the change:**

1. **iOS distribution is a sprint of work on its own.**
   Code-signing, App Store Connect setup, App Icon, splash
   screen, privacy nutrition labels, screenshots,
   provisioning profiles — none of these are SwiftUI or
   cryptography work. Bundling them into Sprint 6 would
   have made it too big and would have delayed "see the
   app working".
2. **A runnable artefact today beats a wrapped IPA later.**
   The macOS executable shipped in Sprint 6 *is* real
   Aegis, visible right now. The iOS IPA is the same
   SwiftUI surface wrapped for the App Store; not a
   different app.
3. **"TestFlight build available" was already a v0.1.0
   deliverable.** Promoting it to Sprint 7 means the alpha
   sprint can focus on polish, external testers, and the
   bootstrap-status update — rather than getting the IPA
   pipeline working.

**What we are giving up:**

- Each downstream sprint's version number shifts by 1
  (v0.0.9 → v0.0.10, etc). v0.1.0 (alpha) lands at
  Sprint 10 instead of Sprint 9.
- `v0.0.10` is a slightly awkward version number. We
  accept it; the alternative (bundling iOS distribution
  into the alpha) would dilute both sprints.

**Approval:** `pre-council-approval`, Maintainer
(@DemigodDSK), 2026-04-28.

---

## v0.0.9 — Sprint 8: Persistence and local conversations ✅

**Tagged:** `v0.0.9-sprint-8`
**Goal:** persist encrypted messages between two locally-defined
users. Still no networking.

Tracking issue: [#12](https://github.com/DemigodDSK/aegis/issues/12)

Deliverables:
- [x] Storage schema for conversations and messages — chosen
      tooling is **raw SQLite** via the system `sqlite3`
      C-API (no third-party deps). Schema lives at
      `Sources/AegisStorage/SQLite/Migrations.swift` and is
      versioned through `PRAGMA user_version`. Append-only
      migration list: v1 (conversations + messages), v2
      (ratchet_sessions).
- [x] All on-disk message bodies are AEAD-protected — see
      "Sprint 8 settled choices" below for the at-rest
      design.
- [x] AegisStorage extended to persist `RatchetSession` per
      peer (`RatchetSessionStore` — JSON-encoded session blob
      with FK CASCADE to its conversation row).
- [x] Per-conversation algorithm metadata (Tier 1 only at
      this stage; Tier 2 / Aegis Lab is later) — three
      `_method` text columns on `conversations` carry the
      AEAD / KEM / signature method ids.
- [x] Migration test: a session bootstrapped pre-persistence
      still decrypts after persistence lands
      (`SchemaMigrationIntegrationTests`).
- [x] All new crypto-core code labelled `pre-council-approval`.
- [x] Tag `v0.0.9-sprint-8`

New surface in this sprint:
- `AegisStorage.SQLiteDatabase` + `SQLiteStatement` — thin
  Swift wrapper over the system sqlite3 C-API. Foreign keys
  ON, WAL journaling, transaction helper.
- `Migrations` — append-only schema migration runner driven
  by PRAGMA user_version.
- `RatchetSessionStore` — UPSERT / load / delete keyed by
  `conversation_id`.
- `ConversationStorageKey` — per-conversation 256-bit
  AES-GCM key in the Keychain (afterFirstUnlockThisDeviceOnly,
  never iCloud).
- `ConversationStore` — conversation CRUD + the send /
  receive flow that drives the Double Ratchet plus
  AEAD-at-rest persistence. Returns `SendResult { stored,
  wire }`; the wire message is what a future transport
  (Sprint 9) will actually send.
- `Conversation`, `StoredMessage`, `MessageDirection`,
  `SendResult`, `ConversationStoreError` — value types for
  the API.
- `RatchetSession`, `RootKey`, `ChainKey`, `MessageKey`,
  `SkippedKeyIdentity` are now `Codable`. Manual Codable on
  the byte-wrapped types re-validates the 32-byte length on
  decode (auto-synthesis would skip the precondition).
- `AegisApp.TwoUserDemo` — `@Observable` `@MainActor`
  bootstrappable Alice/Bob pair: full PQXDH handshake,
  paired ratchet sessions, paired conversation rows, persona
  toggle, send routes through `ConversationStore.send` then
  `ConversationStore.receive` so both sides land in the same
  device-local DB.
- `AegisApp.ConversationsListView` + `ConversationThreadView`
  — Conversations tab on the main TabView.
- `AppState.setupDatabase()`, `bootstrapTwoUserDemo()`,
  `sendFromActivePersona(_:)`, plus the
  `conversations` / `twoUserDemo` accessors.

Test status at tag: 292 tests, 3 skipped (pre-existing
AES.GCM CryptoKit-trap cases — see [issue #1](https://github.com/DemigodDSK/aegis/issues/1)),
0 failures. Sprint 8 added 68 new tests across
AegisCryptoTests, AegisStorageTests, and AegisAppTests.

### Sprint 8 settled choices

The planning round (per the project pattern) surfaced three
decisions before any code was written. The user picked all
three recommendations.

**1. Storage layer: raw SQLite via system `sqlite3`.**
Considered: SwiftData, CoreData, GRDB, flat encrypted files.
SwiftData has had iOS 17/18 migration sharp edges that we
don't want this early in a security-sensitive project.
CoreData would add NSManagedObject ergonomics for no
expressivity gain. GRDB would require a third-party-deviation
note we don't need at this stage. Raw SQLite is
audit-friendly (anyone can `.dump` the DB), zero
transitive surface, and the wrapper is small and ours.

**2. On-disk encryption posture: ratchet ciphertext as-is
(no second AEAD over the wire ciphertext) PLUS a separate
per-conversation Keychain storage key for at-rest plaintext
(decided mid-sprint, before commit 3).** The original
planning-round phrasing of decision 2 was about whether to
double-encrypt the wire ciphertext to defend against
ratchet-state leak — answer: no, the ratchet AEAD is
already strong. But the Double Ratchet is forward-secure,
so storing wire ciphertext verbatim means past messages
cannot be decrypted again for thread display. The
conversation between commits 2 and 3 split the question:
wire ciphertext is the ratchet AEAD output (decision 2,
unchanged); at-rest blobs are AES-GCM-protected with a
per-conversation Keychain-resident key (a different threat
model than decision 2 was about, namely defending against
the SQLite file being exfiltrated separately from the
Keychain). AAD on each at-rest blob binds it to its
`(conversation_id, message_id, direction)` so a row swap
is detected on read.

**3. UI scope: option B — two-user toggle ("I am Alice / I
am Bob") on a single device.** A segmented persona picker
on the Conversations tab routes send through whichever
persona is active; the wire message is then delivered to
the OTHER persona's conversation in the same DB.
Conversations are bootstrapped through a real PQXDH
handshake — the same Sprint 4 path a real two-device
session will use when networking arrives in Sprint 9 — so
the demo isn't a shortcut around the protocol.

---

## v0.0.10 — Sprint 9: Networking 📋

**Goal:** two real iPhones can exchange messages. The transport
layer arrives.

Backend decision pending:
- Option A: CloudKit (Apple-native, no third-party trust)
- Option B: Self-hosted Matrix-flavoured relay
- Option C: Stay-with-Firestore for MVP, migrate later

Deliverables:
- [ ] Wire-format spec (JSON for v0.x, binary for v1.0)
- [ ] Transport layer with retries and backoff
- [ ] Server-side: stores ciphertext only, never sees plaintext
- [ ] Acknowledged delivery
- [ ] Tag `v0.0.10-sprint-9`

---

## v0.1.0 — Sprint 10: First public alpha 📋

**Goal:** something a user can install via TestFlight and use to
chat with one other person. The TestFlight build itself is
already available from Sprint 7; this sprint is about polish
and the first external user.

Deliverables:
- [ ] Onboarding flow polished
- [ ] At least one external person has used it
- [ ] First "bootstrap status" public update published
- [ ] Tag `v0.1.0`

---

## Bigger milestones (years, not sprints)

These are the architecture's larger commitments from
[MISSION.md](../MISSION.md), broken out for scheduling.

### Year 1
- Recruit Security Council (3 members)
- v0.1.0 alpha shipped
- First grant application (Open Tech Fund / NLnet / Sovereign Tech Fund)
- 1k+ GitHub stars (a measure of community interest, not a goal in itself)

### Year 2
- Sealed-sender / metadata protection (the v2.0 feature)
- First external security audit completed and published in `audit-history.md`
- Aegis Lab (Tier 2 sandbox) ships with its first 3 community algorithms

### Year 3
- v1.0 release
- Used by at least one journalist, one lawyer, one academic group
- Sustainable funding for one full-time maintainer

### Year 5
- Reference implementation cited by other projects
- Aegis Crypto sub-package extracted under Apache 2.0 for embedding

### Year 10
- Either: acquired by a mission-aligned steward
- Or: self-sustaining as an independent project
- Either way: the cryptography we shipped has helped real people
  in real situations.

---

## How this document changes

Routine updates (marking sprint deliverables as done, adding
follow-on sprints) are made by the Maintainer in regular commits.

Re-scoping a sprint (changing what it includes), removing a
deliverable from the architecture, or altering the order of
sprints follows the same review process as a change to
[GOVERNANCE.md](../GOVERNANCE.md): Council super-majority + 30-day
public comment, once the Council is formed. During the bootstrap
period the Maintainer may make these changes, tagged
`pre-council-approval`.

This document MUST stay aligned with the version-by-version
capability table in [THREAT-MODEL.md](../THREAT-MODEL.md). When the
two diverge, THREAT-MODEL is the source of truth for what we
*promise users*; this document is the source of truth for what we
*plan to build*.
