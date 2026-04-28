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
- Network transport — Sprint 8.

---

## v0.0.6 — Sprint 5: Forward secrecy 📋

**Goal:** Double Ratchet (or equivalent). After this, compromising
one session key does not compromise past or future sessions.

Deliverables:
- [ ] `RatchetSession` type (X3DH-style chain key + symmetric
      ratchet, seeded from PQXDH output)
- [ ] Out-of-order message handling
- [ ] Skipped-message keys cache with bounded retention
- [ ] Migration test: messages sealed pre-ratchet still decrypt
- [ ] Tag `v0.0.6-sprint-5`

---

## v0.0.7 — Sprint 6: iOS app shell + Keychain identity 📋

**Goal:** first visible Aegis. A SwiftUI app target that
demonstrates the full cryptographic stack in a UI, AND
introduces persistent identity keys backed by the iOS Keychain
(or Secure Enclave where applicable).

Deliverables:
- [ ] `Sources/AegisApp/` SwiftUI target (iOS + macOS Catalyst)
- [ ] Demo screen: passphrase → encrypt → display payload →
      decrypt
- [ ] Settings → Security view rendering the live capability
      table from THREAT-MODEL.md
- [ ] Onboarding flow per THREAT-MODEL.md "In-app honesty"
      section (3 mandatory screens)
- [ ] AegisStorage module: Keychain wrapper for identity
      keypairs and signed prekeys; SE-backed
      `SecureEnclave.MLKEM768` and `SecureEnclave.MLKEM1024`
      where supported; explicit access-control choices
- [ ] Tag `v0.0.7-sprint-6`

---

## v0.0.8 — Sprint 7: Persistence and local conversations 📋

**Goal:** persist encrypted messages between two locally-defined
users. Still no networking.

Deliverables:
- [ ] CoreData (or equivalent) schema for conversations and messages
- [ ] All on-disk message bodies are AEAD-protected
- [ ] Per-conversation algorithm selector (Tier 1 only at this stage)
- [ ] Tag `v0.0.8-sprint-7`

---

## v0.0.9 — Sprint 8: Networking 📋

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
- [ ] Tag `v0.0.9-sprint-8`

---

## v0.1.0 — Sprint 9: First public alpha 📋

**Goal:** something a user can install via TestFlight and use to
chat with one other person.

Deliverables:
- [ ] TestFlight build available
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
