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

## v0.0.4 — Sprint 3: Identity, signatures, and key exchange 📋

**Goal:** Aegis can establish a secure session between two parties
who have never communicated before. End-to-end E2EE becomes
genuinely real.

Deliverables:
- [ ] `Signature` protocol + `Sources/AegisCrypto/Tier1/MLDSA65.swift`
- [ ] Per-user identity keypair generation, stored in iOS Keychain
- [ ] PQXDH-style key-exchange handshake (or a custom equivalent
      reviewed by the Council if the literature is thin)
- [ ] Safety-number derivation (Signal-compatible format)
- [ ] Tag `v0.0.4-sprint-3`

---

## v0.0.5 — Sprint 4: Forward secrecy 📋

**Goal:** Double Ratchet (or equivalent). After this, compromising
one session key does not compromise past or future sessions.

Deliverables:
- [ ] `RatchetSession` type (X3DH chain key + symmetric ratchet)
- [ ] Out-of-order message handling
- [ ] Skipped-message keys cache with bounded retention
- [ ] Migration test: messages sealed pre-ratchet still decrypt
- [ ] Tag `v0.0.5-sprint-4`

---

## v0.0.6 — Sprint 5: iOS app shell 📋

**Goal:** first visible Aegis. A SwiftUI app target that lets a
user enter a passphrase, encrypt a string, and decrypt it back.
No networking yet — purely demonstrating the cryptographic stack
in a UI.

Deliverables:
- [ ] `Sources/AegisApp/` SwiftUI target
- [ ] One screen: input passphrase → encrypt → display payload → decrypt
- [ ] Settings → Security view rendering the live capability table
      from THREAT-MODEL.md
- [ ] Onboarding flow per THREAT-MODEL.md "In-app honesty" section
      (3 mandatory screens)
- [ ] Tag `v0.0.6-sprint-5`

---

## v0.0.7 — Sprint 6: Persistence and local conversations 📋

**Goal:** persist encrypted messages between two locally-defined
users. Still no networking.

Deliverables:
- [ ] CoreData (or equivalent) schema for conversations and messages
- [ ] All on-disk message bodies are AEAD-protected
- [ ] Per-conversation algorithm selector (Tier 1 only at this stage)
- [ ] Tag `v0.0.7-sprint-6`

---

## v0.0.8 — Sprint 7: Networking 📋

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
- [ ] Tag `v0.0.8-sprint-7`

---

## v0.1.0 — Sprint 8: First public alpha 📋

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
