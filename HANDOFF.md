# Aegis — Session Handoff

**Purpose:** complete context for a new Claude Code session so it
can continue this project without losing any decisions,
conventions, or credentials.

**How to use:** in a new Claude Code session, paste the contents
of this file as your first message AND open the session in
`~/Documents/aegis` so the agent has direct file access. The new
agent will have full context.

**Last updated:** 2026-04-28 evening, after Sprint 8 (v0.0.9 —
Persistence + local two-user demo) shipped and was pushed +
tagged. Sprint 9 (Networking) planning is mid-round — the user
has answered the backend choice (Option B, self-hosted relay,
with polling instead of push because no Apple Developer Program
enrolment yet) and owes one final sub-decision (server runtime).
The previous handoff (end of Sprint 7 Phase A, before Sprint 8)
is preserved in git history at commit `fa7d1a8` if you need to
read it cold.

---

## What you (the new agent) are walking into

The user is **Datta Sai Krishna N** (`@DemigodDSK`), maintainer
of the Aegis post-quantum messenger. He's mid-conversation with
the previous Claude Code session about Sprint 9 (Networking).

**Status of Sprint 9 planning round:**

The previous session surfaced the backend decision (A — CloudKit,
B — self-hosted relay, C — federated/p2p) and several
sub-decisions. The user answered:

- Backend: **A is blocked** because he does not yet have an
  Apple Developer Program enrolment (CloudKit needs the paid
  account). C is premature. So **Option B (self-hosted relay)**
  with **polling instead of push notifications** is the
  effective choice.
- Wire format: **JSON for v0.x** (already pinned in STAGES.md).
- Server scope: **minimal HTTP API** (~300 lines): POST
  /prekeys, GET /prekeys/{userId}, POST /messages, GET
  /messages/since.
- Server repo: **separate repo** `aegis-relay` (keeps audit
  surface separate from the client).
- Push notifications: **deferred to a "Sprint 9b"** once Apple
  enrolment lands — write a "Conscious deviation" note in
  STAGES.md when you tag v0.0.10.

**Still open — ask for one answer before commit 1:**

> **Server runtime choice:** Swift Vapor (one language across
> client+server, easy auditing, share Codable types via a tiny
> shared package) vs Go (smaller binary, lower memory, easier
> ops on tiny VPS) vs Plain Swift NIO (less framework, more
> code).
>
> Mild rec: **Vapor** — keeps the project Swift-only, the DX
> win (sharing types) is real if we keep the API surface small.

When he answers, you start Sprint 9 commit 1 (wire format
types — pure client-side Swift, no networking yet, so this
commit is safe to ship regardless of any later backend
question). Plan and rationale are below under "Sprint 9 —
what's next".

**Side task pending:** May 2026 warrant canary, due on or
after **2026-05-01** (3 days from this handoff). Recipe is in
this file's `canary/` section comment. The user has agreed to
draft + sign on May 1; you can offer to do it then.

---

## TL;DR — the verification checklist to run FIRST

Before doing anything else, run this and confirm everything
matches:

```bash
cd ~/Documents/aegis

# 1. Repo health
git status                                           # clean working tree
git log --oneline --decorate -10
git remote -v                                        # DemigodDSK/aegis

# 2. Tools
which gh swift gpg xcodegen                          # all should print paths
gh auth status                                       # DemigodDSK logged in
gpg --list-secret-keys --keyid-format LONG          # ed25519 maintainer key

# 3. PGP signature on April canary still verifies
gpg --verify canary/2026-04.txt.asc canary/2026-04.txt
# expected: "Good signature from Datta sai krishna N..."

# 4. Tests pass
swift test 2>&1 | grep "Executed.*tests.*failures" | tail -1
# expected: "Executed 292 tests, with 3 tests skipped and 0 failures"

# 5. CI is green on origin/main
gh run list --limit 3

# 6. Open issues
gh issue list
# expected open: #1, #9, #10, #11, #13, #14 (and that's it)
# (#12 closed at v0.0.9-sprint-8)

# 7. iOS smoke-test artefacts present
ls Aegis.xcodeproj && ls iOS/Sources iOS/Resources project.yml
# all should exist

# 8. The Aegis app is installed on the iPhone 17 Pro simulator
xcrun simctl listapps 145620FA-CBF9-4617-B698-7449A19CE517 \
    | grep -A 1 demigoddsk
# expected: shows io.github.demigoddsk.Aegis bundle path

# 9. v0.0.9-sprint-8 tag exists locally and is pushed
git tag --points-at HEAD~0 2>/dev/null   # may be empty if ahead of HEAD
git tag | grep sprint-8
# expected: v0.0.9-sprint-8
```

If any of those fail, fix it before starting Sprint 9.

---

## Project identity

| | |
|---|---|
| **Name** | Aegis |
| **One-liner** | "Post-quantum messaging, in the open." |
| **Repository** | https://github.com/DemigodDSK/aegis (public) |
| **Local path** | `~/Documents/aegis` |
| **Maintainer** | Datta Sai Krishna N (`@DemigodDSK`, `dsk7699@gmail.com`) |
| **License** | AGPL v3 (Apache 2.0 dual-license planned for crypto core in Year 2) |
| **Current version** | `v0.0.9-sprint-8` shipped + tagged + pushed (Sprint 7 Phase B / TestFlight still HELD on Apple Developer Program enrolment) |

## Why this project exists (the ONE thing you must internalise)

Datta is building an **iOS messenger** with two distinguishing
properties:

1. **NIST-standardised post-quantum cryptography by default**
   (ML-KEM-768 hybridised with X25519 in X-Wing for the
   message-AEAD bootstrap; bare ML-KEM-1024 inside PQXDH;
   AES-256-GCM for messages; ML-DSA-65 for signatures).
2. **A sandboxed cryptography "laboratory" tier** (Aegis Lab,
   Tier 2) where community contributors can submit experimental
   algorithms — clearly marked, never the default, never used
   for real conversations without explicit informed user opt-in.

Audience: journalists, lawyers, academics, security researchers,
and privacy-conscious individuals who want auditable, swappable
cryptography rather than a black box.

Datta is willing to take 5+ years on this. The mission is the
constraint, not revenue.

---

## Working principles (DO NOT VIOLATE)

These were established across many hours of conversation. They
are non-negotiable:

1. **No drift from architecture.** Every code/governance change
   must honour MISSION.md, THREAT-MODEL.md, GOVERNANCE.md, and
   ALGORITHM-SUBMISSION.md. If a sprint requires a deviation,
   write a "Conscious deviation" entry in the relevant document
   FIRST, get user approval, then change code. Four deviations
   exist so far (Sprint 2 X-Wing, Sprint 3 split, Sprint 6→7
   split, Sprint 9 push-notif deferred). See `docs/STAGES.md`
   for the format.

2. **Cryptographic core changes are special.** During the
   bootstrap period (until a Security Council exists, target
   end of Year 1) the maintainer can merge them alone, but
   every such commit must be tagged `pre-council-approval` in
   the commit message body and a tracking issue should be
   opened.

3. **Honesty over marketing.** The user has explicitly chosen
   to tell users in onboarding "do NOT use this app for
   life-or-liberty situations until v2.0; use Signal instead."
   This is a feature, not a bug. Never soften it.

4. **No "creative" cryptography in Tier 1.** Tier 1 = NIST/IETF
   standards only via Apple's CryptoKit. Tier 2 sandbox =
   community algorithms with a giant "EXPERIMENTAL" warning.
   The two tiers MUST NOT mix in the default user path.

5. **No backdoors, ever.** GOVERNANCE.md commits the project to
   shutting down rather than complying with a backdoor demand.
   The warrant canary is the public surfacing mechanism.

6. **Don't promise more than you ship.** The version-by-version
   capability table in THREAT-MODEL.md is the source of truth
   for user-facing claims. The in-app `Capability.all` mirrors
   it; `CapabilityTests` catches partial drift. Cross-checked
   at every release.

7. **Defer "creative" work that the user keeps wanting to add.**
   The user has a habit of jumping to fancy features
   (post-quantum + blockchain + AI, etc.). Politely refocus on
   the next sprint's documented goal. He has agreed to
   phase-by-phase discipline; hold him to it.

8. **The user is not a cryptographer (and neither are you).**
   Tier 1 approvals require unanimous Security Council vote.
   Until the Council exists, the user is doing approvals
   himself with the `pre-council-approval` tag. Do not
   green-light novel algorithms.

---

## Tone preferences (the user has been consistent about these)

The user has consistently rewarded:

- **Honest about limitations.** When something is broken or you
  don't know, say so. Don't try to wave it away.
- **Concrete next steps.** Tell the user the next 2–3 commands
  or decisions, not abstract advice.
- **Brutally direct when stakes are high.** The user has
  thanked the prior agent for being uncomfortable-but-correct
  ("you have a habit of redesigning instead of building", "you
  should not call this quantum-secure"). Maintain that.
- **No hype.** No "Amazing!", no rocket emojis in every
  message, no congratulating on trivialities. The user has
  shipped real work and knows it.
- **Use the user's ambition without indulging it.** When he
  says "let's build the next Signal", say "let's build
  something better than trying to be Signal — here's the
  realistic path." Then ground in the next-sprint deliverable.
- **Status snapshots when transitioning.** End big chunks of
  work with a table of what's done and what's next. The user
  reads tables.
- **Settled-choices tables before any code in a new sprint.**
  Each sprint has a planning round where you surface
  decisions, user picks A/B/C, you start. This pattern works;
  preserve it.
- **Surface mid-sprint forks.** If a real architectural fork
  appears mid-sprint that wasn't in the original planning
  round (Sprint 8 hit the "ratchet ciphertext is forward-
  secure so you can't decrypt past messages" tension), pause,
  surface the trade-offs as a table, let him pick. Do NOT
  guess.

The user does NOT want:

- Excessive cheerleading
- Long explanatory paragraphs when bullet points suffice
- Re-explaining things he's already shown he understands
- Asking permission for tiny obvious actions (just do them)
- "Let me know if..." closers without a specific next question

---

## Repository state — what's shipped (chronological)

### Tags

| Tag | Commit | What it shipped |
|---|---|---|
| `v0.0.1-foundation` | `20613f0` | 13 governance/policy MD docs + LICENSE + first canary |
| `v0.0.2-sprint-1` | `ca622f8` | AegisCrypto SwiftPM target with AES-256-GCM (CryptoKit) + 5 NIST KATs |
| `v0.0.2.1-polish` | `b1782b9` | CI, STAGES.md, issue templates, .editorconfig, About sidebar |
| `v0.0.2.2-pgp` | `147afcb` | PGP key (`E7B6…8DE4`) + signed inaugural canary + SECURITY.md fingerprint |
| `v0.0.3-sprint-2` | `bd8938b` | X-Wing (ML-KEM-768 + X25519) hybrid PQ-KEM via Apple CryptoKit (`HybridKEM`) + 25 NIST KAT vectors + 3 X-Wing draft KATs |
| `v0.0.4-sprint-3` | `2650431` | ML-DSA-65 PQ signatures (`MLDSA65Signature`) + 25 NIST KeyGen + 160 Wycheproof verify-side KATs |
| `v0.0.5-sprint-4` | `c325324` | PQXDH key exchange (`PQXDH`, `InitialMessage`) + identity types (`IdentityKeyPair`) + prekey bundles (`PrekeyBundle`) + safety numbers + bare `MLKEM1024KEM` + `X25519` namespace |
| `v0.0.6-sprint-5` | `16caf55` | Double Ratchet — `ChainKey`, `MessageKey`, `RootKey`, `RatchetSession`, bounded skipped-keys cache for out-of-order delivery, full PQXDH→Ratchet integration test |
| `v0.0.7-sprint-6` | `3fc0539` | iOS app shell as SwiftPM library + Keychain-backed identity persistence (`AegisStorage`) + macOS demo executable |
| **(no tag)** | `02cd59e` → `2984409` | **Sprint 7 Phase A** landed on `main`: Xcode project via XcodeGen, iOS app target, runs on iPhone 17 Pro simulator with correct dark theme. Tag `v0.0.8-sprint-7` HELD until Phase B (Apple Developer Program + TestFlight) |
| **`v0.0.9-sprint-8`** | `75a5d10` | **Sprint 8 (Persistence + local two-user demo)** — SQLite via system `sqlite3` (schema v1 + v2), `RatchetSession` persistence (Codable + `RatchetSessionStore`), `ConversationStore` API, per-conversation Keychain-backed AES-256-GCM at-rest storage key, Conversations tab with list + thread view, two-user toggle (Alice ⇄ Bob with real PQXDH handshake on a single device), all green on CI + smoke-tested on iPhone 17 Pro simulator |

### Sprint numbering history

The sprint numbers have been adjusted twice. Final mapping:

| Sprint | Version | Topic | Status |
|---|---|---|---|
| 1–6 | v0.0.2 → v0.0.7 | Foundations + crypto + ratchet + iOS shell | ✅ all shipped |
| 7 | v0.0.8 | iOS distribution (Xcode + IPA + TestFlight) | 🚧 Phase A landed (`02cd59e` → `2984409`); Phase B HELD on Apple Developer Program enrolment |
| 8 | v0.0.9 | Persistence + local two-user demo | ✅ shipped (`v0.0.9-sprint-8`, `75a5d10`) |
| 9 | v0.0.10 | Networking | 📋 next (this session's work) |
| 10 | v0.1.0 | First public alpha — external testers | 📋 |

### Sprint 8 — what landed (commits since v0.0.7)

| Commit | Scope |
|---|---|
| `4f36347` | crypto-core(storage): SQLite layer + schema v1 (conversations + messages tables) + migrations runner. Wrapper around the system `sqlite3` C-API; wraps in foreign-keys-on, WAL-on; `Migration.apply(to:)` is user_version-driven and append-only |
| `8c765e7` | crypto-core(storage): RatchetSession persistence — Codable on `RootKey`/`ChainKey`/`MessageKey` (manual, validates 32-byte length on decode) + Codable on `RatchetSession` + `SkippedKeyIdentity` (auto-synthesized) + schema v2 migration adding `ratchet_sessions` table + `RatchetSessionStore` |
| `d8127e3` | crypto-core(storage): `ConversationStore` API + per-conversation `ConversationStorageKey` in Keychain. AES-256-GCM at-rest encryption for plaintext (since ratchet ciphertext is forward-secure and can't be decrypted later for thread display). AAD on the at-rest blob binds (conversation_id, message_id, direction) so a row swap fails the AEAD |
| `8c65a48` | feat(app): Conversations tab + `ConversationsListView` + `ConversationThreadView`. `AppState` extended with SQLite + stores. The tab landed but conversation creation still needed wiring (commit 5) |
| `9a71a0e` | feat(app): two-user toggle — `TwoUserDemo` runs a full PQXDH handshake between synthetic Alice + Bob identities on one device, seeds both ratchet sessions, creates two `ConversationStore` conversations. The Conversations tab gains an "Acting as: Alice / Bob" segmented control |
| `75a5d10` | docs(stages): STAGES.md v0.0.9 marked ✅ + closeout `SchemaMigrationIntegrationTests` (fresh-DB end-to-end check that the migration → bootstrap → send/receive → read-back path works through the real PQXDH). Tag `v0.0.9-sprint-8` |

### Test status

`swift test` → **292 tests, 3 skipped (issue #1), 0 failures**.

Breakdown of the 68 new tests added in Sprint 8:

- 10 `SQLiteDatabaseTests` (open / round-trips / transactions / user-version)
- 6 `MigrationsTests` (runner correctness + schema v1)
- 7 `RatchetSessionCodableTests` (bytes round-trip + crypto round-trip across restore + skipped-keys cache survives + length validation)
- 9 `RatchetSessionStoreTests` (CRUD + multi-conversation isolation + FK cascade + clock injection)
- 7 `ConversationStorageKeyTests` (provision/load/delete + per-conversation isolation)
- 10 `ConversationStoreTests` (create persists three pieces + list ordering + delete cascade + send/receive + AAD binding rejects swap)
- 7 `AppStateDatabaseTests` (setupDatabase idempotent + error surfacing)
- 10 `TwoUserDemoTests` (bootstrap + persona toggle + send round-trip + many-message DH rotations)
- 1 `SchemaMigrationIntegrationTests` (closeout end-to-end through real PQXDH)
- a couple of small additions inside the existing files (mixed in)

The 3 skipped tests are still `testDecrypt_wrongKey_*`,
`testDecrypt_tamperedCiphertext_*`, `testDecrypt_tamperedTag_*`
— Apple-side CryptoKit AES.GCM SIGTRAP on macOS 26.x (issue
#1). The auth-failure path is verified via
`testDecrypt_tamperedAAD_throwsAuthenticationFailed` which
passes.

### KAT coverage across the suite

Unchanged from Sprint 7 Phase A (Sprint 8 added storage code, no
new cryptographic primitives so no new KAT vectors):

236 distinct known-answer-test verifications across the existing
files (NIST CAVP AES-GCM, BoringSSL-mirrored AES-GCM, NIST FIPS
203 ML-KEM-768/1024 KeyGen, IETF X-Wing draft, NIST FIPS 204
ML-DSA-65 KeyGen, Wycheproof ML-DSA-65 verify, pinned PQXDH
HKDF combiner, pinned ChainKey + RootKey snapshots).

All KAT vector files live in `Tests/AegisCryptoTests/Vectors/`
with provenance + SHA-256 in that directory's `README.md`. CI
re-verifies every checksum before tests run.

---

## Repository module layout

```
Package.swift                          # SwiftPM manifest, swift-tools-version 6.2,
                                       # iOS 26 / macOS 26 minimums (PQ CryptoKit gate)
project.yml                            # XcodeGen spec for the iOS app target
Aegis.xcodeproj/                       # Generated by `xcodegen`; both spec and project committed

Sources/
  AegisCrypto/                         # Tier 1 primitives + protocols
    Encryption.swift                   # AEAD seam
    KeyEncapsulation.swift             # KEM seam
    Signature.swift                    # Signature seam
    EncryptionMethod.swift             # Method metadata (reused across all three seams)
    AegisError.swift                   # Single error taxonomy
    Identity.swift                     # IdentityKeyPair + IdentityPublicKey
    PrekeyBundle.swift                 # Bob's published bundle + secrets
    PQXDH.swift                        # Post-quantum extended Diffie-Hellman handshake
    SafetyNumber.swift                 # Signal-format-compatible 12×5-digit fingerprint
    Ratchet.swift                      # Symmetric ratchet (ChainKey + MessageKey) + RootKey
                                       # — ALL Codable (added Sprint 8)
    RatchetSession.swift               # Bidirectional Double Ratchet state + encrypt/decrypt
                                       # — Codable as a single object (added Sprint 8)
    Tier1/
      AESGCM.swift                     # AES-256-GCM (only Tier 1 AEAD)
      HybridKEM.swift                  # X-Wing PQ-hybrid KEM (CryptoKit XWingMLKEM768X25519)
      MLKEM1024.swift                  # Bare ML-KEM-1024 (CryptoKit MLKEM1024) for PQXDH
      MLDSA65.swift                    # ML-DSA-65 signatures (CryptoKit MLDSA65)
      X25519.swift                     # X25519 namespace + DHKeyPair envelope

  AegisStorage/                        # Persistence layer
    AegisStorage.swift                 # Keychain-backed identity persistence (Sprint 6)
    Keychain.swift                     # Internal SecItem* wrapper
    KeychainAccessibility.swift        # Type-safe enum for kSecAttrAccessible* attrs
    SQLite/                            # Sprint 8 — system sqlite3 wrapper + migrations
      SQLiteDatabase.swift             # Open / execute / prepare / transaction
      Migrations.swift                 # User-version-driven runner; schema v1 (conversations +
                                       # messages) and v2 (ratchet_sessions)
    RatchetSessionStore.swift          # Sprint 8 — save/load/delete RatchetSession by conversation
    ConversationStorageKey.swift       # Sprint 8 — per-conversation 256-bit AES-GCM key in Keychain
    ConversationStore.swift            # Sprint 8 — Conversation + StoredMessage CRUD + send / receive

  AegisApp/                            # SwiftUI surface (consumed by both macOS demo and iOS app)
    Theme.swift                        # AegisTheme — palette, typography, layout
    AppState.swift                     # @Observable @MainActor view-model state
                                       # — extended Sprint 8 with SQLite + ConversationStore + TwoUserDemo
    RootView.swift                     # Top-level routing (onboarding → identity → main)
    OnboardingFlow.swift               # 3-screen mandatory honesty flow
    IdentitySetupScreen.swift          # Display-name input + key generation
    DemoViewModel.swift                # Encrypt/decrypt logic for demo screen
    DemoScreen.swift                   # Encrypt/decrypt UI
    SettingsScreen.swift               # About card + Security capability list
    Capability.swift                   # 14-row capability list mirroring THREAT-MODEL.md
    MainTabView.swift                  # Demo + Conversations + Settings tab view
                                       # — Conversations tab added Sprint 8
    ConversationsListView.swift        # Sprint 8 — persona toggle + active-conversation row
    ConversationThreadView.swift       # Sprint 8 — message bubbles + composer
    TwoUserDemo.swift                  # Sprint 8 — Alice + Bob bootstrap + send routing

  aegis-demo/                          # macOS executable host
    AegisDemoApp.swift                 # @main App for macOS — `swift run aegis-demo`

iOS/                                   # iOS-target-specific files (consumed by Aegis.xcodeproj)
  Sources/
    AegisIOSApp.swift                  # @main App for iOS
  Resources/
    Assets.xcassets/                   # AppIcon + AccentColor
  Info.plist                           # Generated by XcodeGen from project.yml
  Aegis.entitlements                   # Generated; Keychain access group + APNs (provisioned)

Tests/
  AegisCryptoTests/                    # ~200+ tests
    AESGCM*.swift                      # AES-GCM contract + KAT tests
    HybridKEM*.swift                   # X-Wing wrapper tests
    MLKEM768/1024 SmokeTests.swift     # Apple-API tripwires for KEMs
    MLDSA65*.swift                     # Signature wrapper + KAT tests
    Ratchet*.swift                     # Double Ratchet primitive + session tests
    RatchetSessionCodableTests.swift   # Sprint 8 — Codable round-trip + crypto round-trip across restore
    PQXDH*.swift                       # Handshake tests + pinned HKDF KAT
    PrekeyBundle*.swift                # Bundle generation + signature-chain verify tests
    SafetyNumber*.swift                # Order-independence + format pinning
    Identity*.swift                    # IdentityKeyPair + JSON round-trip
    X25519*.swift                      # DH primitive tests
    PQXDHRatchetIntegrationTests.swift # End-to-end Sprint 4 → Sprint 5 seam
    Vectors/
      README.md                        # Provenance + SHA-256 for every KAT file
      *.json, *.txt                    # KAT data (committed verbatim from upstream sources)
  AegisStorageTests/                   # Keychain CRUD + Sprint 8 storage tests
    AegisStorageTests.swift            # Identity round-trip
    SQLiteDatabaseTests.swift          # Sprint 8 — wrapper round-trips
    MigrationsTests.swift              # Sprint 8 — migration runner correctness + schema v1
    RatchetSessionStoreTests.swift     # Sprint 8 — CRUD + FK cascade
    ConversationStorageKeyTests.swift  # Sprint 8 — provision / load / delete
    ConversationStoreTests.swift       # Sprint 8 — full CRUD + send/receive + AAD binding
    SchemaMigrationIntegrationTests.swift  # Sprint 8 closeout — end-to-end fresh DB through real PQXDH
  AegisAppTests/                       # AppState + DemoViewModel + Capability + Sprint 8 demo state
    AppStateTests.swift                # Routing + Keychain handoff
    AppStateDatabaseTests.swift        # Sprint 8 — setupDatabase + refreshConversations
    CapabilityTests.swift              # Drift catcher
    DemoViewModelTests.swift           # Demo encrypt/decrypt
    TwoUserDemoTests.swift             # Sprint 8 — bootstrap + persona toggle + send round-trip

docs/
  STAGES.md                            # Per-sprint roadmap — SOURCE OF TRUTH for what's
                                       # shipped and what's planned. Includes all four
                                       # "Conscious deviation" subsections (Sprint 2 X-Wing,
                                       # Sprint 3 split, Sprint 6→7 split, Sprint 9
                                       # push-notif deferred — write the last one when
                                       # tagging v0.0.10).
  IOS-RUNBOOK.md                       # Phase A: how to run on simulator / iPhone via free Apple ID
  IOS-DISTRIBUTION-RUNBOOK.md          # Phase B: Apple Developer Program → TestFlight

canary/
  2026-04.txt + .asc                   # April canary, PGP-signed by maintainer key
  # 2026-05.txt is drafted in chat history — to be created on or after May 1.
  # Recipe: copy 2026-04.txt structure, change "Reporting period: May 2026" and
  # "Date of publication: 2026-05-XX". Item #4 should mention all THREAT-MODEL.md
  # edits since the April canary (none in Sprint 8 — Sprint 8 was all storage and UI;
  # if Sprint 9 lands a THREAT-MODEL update before May 1, mention that commit). Sign
  # with the maintainer PGP key.

.github/workflows/ci.yml               # Build + tests on macos-26 runner; verifies Vectors/
                                       # SHA-256s against README; Node.js 24 forced via env

# Top-level governance docs (the "four files" + LICENSE)
MISSION.md, THREAT-MODEL.md, GOVERNANCE.md, ALGORITHM-SUBMISSION.md
LICENSE, SECURITY.md, README.md
CONTRIBUTING.md, CODE_OF_CONDUCT.md, CLA.md, CONTRIBUTORS.md, CONFLICTS.md
audit-history.md
```

---

## Open issues (from `gh issue list`)

| # | Type | What it is |
|---|---|---|
| #1 | bug, upstream | macOS 26.x CryptoKit AES.GCM SIGTRAP. 3 tests skipped. Workaround: AAD-tamper test covers the auth-failure path. Closes when Apple fixes. |
| #9 | bug, upstream | macOS 26.x CryptoKit MLKEM1024 SIGTRAP on too-short seed. Workaround: size pre-validation in `MLKEM1024.swift`. Closes when Apple fixes. |
| #10 | enhancement | Optional libsignal byte-level interop test for PQXDH. Pinned-input PQXDH KAT shipped at `1ae88af` covers drift detection; libsignal interop stays as polish-window work. |
| #11 | epic, sprint-7 | Sprint 7 tracker (iOS distribution). Phase A landed; Phase B (TestFlight) waits for Apple Developer Program enrolment — confirmed open on 2026-04-28. |
| #13 | epic, sprint-9 | **Sprint 9 tracker (Networking) — the active sprint.** |
| #14 | epic, sprint-10 | Sprint 10 tracker (First public alpha, v0.1.0). |

Closed for context: #2 (AES-GCM KAT expansion), #3 (Sprint 2),
#4 (Sprint 4), #5 (Sprint 5), #6 (Sprint 6), #7 (CI checksums),
#8 (Node.js 24 actions), **#12 (Sprint 8 — closed at
`v0.0.9-sprint-8` on 2026-04-28)**.

---

## Sprint 9 — what's next (the active sprint)

The user just chose Sprint 9. The planning round is partially
resolved: backend, wire format, server scope, server repo, push
posture all decided. Server runtime is the one remaining
sub-decision before commit 1.

### Backend choice — settled

**Option B (self-hosted minimal HTTP relay) with polling
instead of push.** Reasoning:

- Option A (CloudKit) is gated on Apple Developer Program
  enrolment, which the user does NOT have yet (confirmed
  2026-04-28).
- Option C (federated/p2p) is premature for v0.0.10.
- Self-hosted is mission-aligned with GOVERNANCE.md ("we run
  the box, we never see plaintext").
- Push notifications need APNs which also gates on the Apple
  Developer Program. So **polling** is the v0.0.10 delivery
  mechanism; APNs becomes a "Sprint 9b" once the user enrols.

### Sub-decisions — settled

| # | Decision | Choice |
|---|---|---|
| 1 | Wire format | **JSON for v0.x** (already pinned in STAGES.md); binary at v1.0 |
| 2 | Push notifications | **Deferred to Sprint 9b** — start with polling, add APNs once core flow works |
| 3 | Server scope | **Minimal HTTP API** — POST /prekeys, GET /prekeys/{userId}, POST /messages, GET /messages/since. No Matrix, no federation. ~300 lines |
| 4 | Server repo | **Separate repo** `aegis-relay` — keeps audit surface separate from the client |

### Sub-decision — STILL OPEN

**Server runtime (the user owes this answer):**

| Option | Pros | Cons |
|---|---|---|
| **Swift Vapor** | One language across client+server; same `Codable` types via a tiny shared package; easier auditing for the maintainer | Larger binary, Swift on Linux is fine but not lightweight |
| **Go** | Smaller binary, lower memory, easier ops on tiny VPS, faster cold starts | Second language to maintain; can't share types |
| **Plain Swift NIO** | Less framework | More code to write and audit |

Mild rec: **Vapor** — keeps the project Swift-only. The DX win
(sharing types) is real if we keep the API surface small.

### Once the user answers, the proposed Sprint 9 commit plan

| # | Commit | Notes |
|---|---|---|
| 1 | Wire format types (`WireMessage`, `PublishedPrekeyBundle`, `MessageEnvelope`) + Codable + KAT-style round-trip tests | Client-only, no I/O. Safe to ship regardless of any later backend question |
| 2 | `Transport` protocol + retry/backoff + `InMemoryTransport` for tests | Pure Swift, no networking yet |
| 3 | `HTTPTransport` — URLSession-based client speaking JSON to the relay's API | Client side |
| 4 | `aegis-relay` — separate repo, minimal HTTP server in the chosen runtime | The other half. New repo `DemigodDSK/aegis-relay`, set up via `gh repo create` |
| 5 | Polling loop + `ConversationStore.deliver` integration + UI plumbing | Replaces what would have been push |
| 6 | Closeout + tag `v0.0.10-sprint-9` + "Conscious deviation: deferred push to Sprint 9b" entry in STAGES.md | Documents the trim |

### Definition of done (from issue #13)

- [ ] Wire-format spec (JSON for v0.x — pinned now in spec form)
- [ ] Transport layer with retries and backoff
- [ ] Server-side: stores ciphertext only, never sees plaintext
- [ ] Acknowledged delivery (polling-style ACKs)
- [ ] Push-notification consumer wired up — **DEFERRED** to
      Sprint 9b (write the deviation note when tagging)
- [ ] All new crypto-core code labelled `pre-council-approval`
- [ ] Tag `v0.0.10-sprint-9`

---

## Sprint 7 status (still in flight, BLOCKED on user)

### Phase A (landed on `main`, NOT yet tagged)
- Aegis.xcodeproj generated by XcodeGen from project.yml
- iOS app target builds for iOS 26.4 SDK
- App installs and runs on iPhone 17 Pro simulator (verified via
  `xcrun simctl install` + `xcrun simctl launch`)
- Dark theme renders correctly (after the `2984409` fix)
- Onboarding → identity setup → demo encrypt/decrypt → settings
  → **Conversations tab with two-user toggle (Sprint 8)** all
  work end-to-end on the simulator
- `docs/IOS-RUNBOOK.md` (Phase A: simulator + free-Apple-ID
  iPhone instructions)

### Phase B (waits on Datta's action)
- Apple Developer Program enrolment ($99/yr) — **STILL NOT
  DONE as of 2026-04-28**, which is also why Sprint 9 chose
  the self-hosted relay path with polling
- App Store Connect record creation
- Real signing certificate + provisioning profile
- First TestFlight build pushed to internal testers (just
  Datta)
- Smoke-test on production-signed build
- THEN tag `v0.0.8-sprint-7` (the runbook's last step)

`docs/IOS-DISTRIBUTION-RUNBOOK.md` is the recipe. ~30 minutes
once enrolment is approved.

---

## Three iOS-26-specific lessons (carried from Sprint 7)

If you set up a new SwiftPM-package-driven iOS app target via
XcodeGen on macOS 26.x / Xcode 26.4.x and hit
`IXErrorDomain Code 13 / "Missing bundle ID"` at install time:

1. **Asset catalog must be COMPILED, not folder-referenced.**
   In XcodeGen's `sources:`, do NOT mark `iOS/Resources` as
   `type: folder` — that's a folder reference that just copies
   verbatim. Make it a group so `actool` runs and produces
   `Assets.car` + the AppIcon variants.
2. **`LSRequiresIPhoneOS: true` must be set in Info.plist.**
   Without it, iOS 26 install services get confused.
3. **`ENABLE_DEBUG_DYLIB: NO`.** Xcode 16+'s "Debug Dylib"
   feature splits the binary into shim + sidecar; iOS 26
   simulator install rejects that layout. Force a single-file
   executable.

All three are baked into `project.yml` as of commit `90b55ae`.
The runbook `docs/IOS-RUNBOOK.md` has a troubleshooting row
pointing to that commit.

---

## Sprint 8 lessons (new in this session)

### The forward-secrecy / display tension is a real fork

The Double Ratchet's per-message AEAD key is consumed and
discarded after one use. So if `messages.ciphertext` stores
the wire-format ratchet bytes verbatim, **past messages can
never be decrypted again for thread display**. Sprint 8's
issue body said "ciphertext only on disk" and that goal is
incompatible with rendering past messages without something
extra.

Options surfaced mid-sprint:

- **A** — store plaintext, rely on iOS Data Protection
- **B** — store plaintext encrypted by a per-conversation
  Keychain-backed AES-GCM key (a separate at-rest seal,
  distinct from the wire-side ratchet)
- **C** — store ratchet ciphertext + cache the per-message
  AEAD key alongside it

Decision: **B** (chosen by user mid-sprint). Implementation:
`Sources/AegisStorage/ConversationStorageKey.swift`. The
`ConversationStore.send` / `receive` flow does:

1. Run ratchet encrypt / decrypt to advance the wire-side state
2. Separately, AEAD-encrypt the plaintext under the
   conversation's storage key with AAD bound to
   `(conversation_id, message_id, direction)`
3. Persist the at-rest blob to `messages.ciphertext`

This satisfies "ciphertext only on disk" while preserving the
ability to render old messages. Decision 2 of the original
planning round was about NOT layering a second AEAD over the
**wire ciphertext** to defend against ratchet-state leak —
which is a different threat model from at-rest secrecy.

### Codable on `RatchetSession` and supporting types

Manual `init(from decoder:)` on `RootKey` / `ChainKey` /
`MessageKey` because auto-synthesized Codable would skip the
32-byte length precondition on `init(bytes:)` and let a
malformed blob produce a wrong-sized key (which would crash
at the next ratchet step). Pattern: `singleValueContainer` ->
`Data` -> length check -> throw `DecodingError.dataCorrupted`
on mismatch.

`SkippedKeyIdentity` (internal) and `RatchetSession` (public)
use auto-synthesized Codable.

### iOS Application Support directory creation

`FileManager.default.url(for: .applicationSupportDirectory, in:
.userDomainMask, appropriateFor: nil, create: true)` does NOT
auto-create on first iOS launch in some scenarios. The `create:
true` parameter handles this; do not skip it.

---

## Conventions established in conversation

### Commit message format

```
type(scope): short summary

Optional longer body wrapped at 72 cols. Explains the WHY,
not the WHAT. Cites references (`Refs: #N`) and uses
`pre-council-approval (Maintainer @DemigodDSK, YYYY-MM-DD)`
on any change touching cryptographic-core paths defined in
GOVERNANCE.md.

Refs: #N
Maintainer: Datta Sai Krishna N (@DemigodDSK)
```

`type` ∈ `feat`, `fix`, `docs`, `refactor`, `test`, `chore`,
`crypto-core`. The `crypto-core` type is required for any
change touching files listed in GOVERNANCE.md "What is the
cryptographic core?":
- `Sources/AegisCrypto/Tier1/**`
- `Sources/AegisCrypto/Registry/**` (doesn't exist yet)
- The four governance MDs (THREAT-MODEL, ALGORITHM-SUBMISSION,
  GOVERNANCE, MISSION)

Sprint 8 also used `crypto-core(storage):` for AegisStorage
extensions that persist secret material (ratchet sessions,
storage keys). That's literally outside GOVERNANCE.md's
crypto-core path definition, but the **persistence-of-secret-
material discipline** still applies — keep doing this for
Sprint 9 commits that touch on-disk crypto material.

The `Maintainer:` trailer is the project convention. **Do NOT
add `Co-Authored-By: Claude` trailers** — Datta has not asked
for that and the existing commits don't have it.

### Versioning

- `v0.X.Y-sprint-N` for sprint completions
- `v0.X.Y.Z-polish` for polish/cleanup passes
- `v0.X.Y-foundation` for the inaugural foundation drop only
- v1.0 reserved for first audit-complete release

### Tag every meaningful release

After every commit that ends a sprint, create an annotated tag.
Tags are unsigned (project convention; existing ones don't have
PGP signatures). If the user wants to start signing tags, that's
a future decision.

### Push only after `swift test` exits 0

CI gates merges, but local `swift test` MUST pass before any
push. If it fails or hangs, do NOT push and do NOT bypass —
investigate.

### Sprint cadence pattern

Each sprint follows:
1. **Planning round.** Surface decisions in a settled-choices
   table; user picks A/B/C; sometimes triggers a "Conscious
   deviation" entry in STAGES.md.
2. **N commits**, one per logical chunk, each with full body
   text explaining the why.
3. **Closeout commit** that marks the STAGES.md sprint entry
   ✅ and rolls up the test-status snapshot.
4. **Annotated tag** on the closeout commit.
5. **Push commits + tag together** (one `git push origin main
   <tag>` after CI-clean local `swift test`).
6. **Watch CI** until both runs are green (one for `main`, one
   for the tag).
7. **Close the tracking issue** with a citation to the tag and
   the DoD checklist all ticked.

### Always use the `gh` CLI for GitHub operations

Issues, labels, PRs, releases — all via `gh`. Don't ask the
user to click through web forms unless `gh` doesn't support
the operation.

### Documentation in plain English

Prefer "we encrypt your messages" over "we apply AEAD
primitives to your message bodies." Technical detail belongs
in code comments, not user-facing docs.

### Manual UI smoke testing

The user has manually smoke-tested every UI commit on the
iPhone 17 Pro simulator. After each UI-touching commit,
present a numbered "try this" list so he can replicate the
golden path. Do not claim the UI works without his
confirmation — the test suite verifies code correctness, not
feature correctness.

---

## Credentials and secrets (where they live)

### Maintainer PGP key

| | |
|---|---|
| Fingerprint | `E7B6 56B4 D0DD BB07 29ED 462F FF11 64C0 B4D2 8DE4` |
| Algorithm | ed25519 + cv25519 |
| Created | 2026-04-27 |
| Expires | 2028-04-26 |
| User ID | `Datta sai krishna N (Aegis project maintainer) <dsk7699@gmail.com>` |
| Private key location | `~/.gnupg/private-keys-v1.d/` (passphrase-protected) |
| Public key in repo | `.well-known/security.asc` |
| Public key on keyserver | `keys.openpgp.org` |
| Revocation cert | `~/.gnupg/openpgp-revocs.d/E7B6...8DE4.rev` AND backed up at `~/Documents/aegis-keys-backup-DO-NOT-COMMIT/` |
| gpg-agent cache TTL | 1 hour |
| pinentry | `/opt/homebrew/bin/pinentry-mac` |

### GitHub

- `gh` CLI: `/opt/homebrew/bin/gh` (v2.89.0+)
- Authenticated as `DemigodDSK`
- Token scopes: `gist`, `read:org`, `repo`, `workflow`
- HTTPS via macOS keyring

### Tools installed on the user's Mac

- `gh`, `gpg`, `pinentry-mac` (Homebrew)
- `xcodegen` (Homebrew, installed during Sprint 7)
- Xcode 26.4.1 with iOS 26.4 SDK + iOS 26.4.1 Simulator
  runtime (UUID 145620FA-CBF9-4617-B698-7449A19CE517 is the
  iPhone 17 Pro simulator we tested against)
- Standard Swift 6.3.1 toolchain

### Apple Developer Program

**NOT enrolled** as of 2026-04-28. This blocks:
- Sprint 7 Phase B (TestFlight)
- Sprint 9 Option A (CloudKit)
- APNs push notifications (Sprint 9 push wiring → Sprint 9b)

Cost when enrolled: $99/yr.

### Disk hygiene note

The user's Mac was at 99% capacity (218 MB free) at one point
during a previous session — common contributors to "System
Data" on macOS dev machines: Xcode DerivedData, CoreSimulator
runtimes (2.6 GB after iOS 26.4 download), Application Support
caches (VS Code 1.4 GB, Google Chrome 1 GB), Homebrew cache
(726 MB). Was at 75% (3.8 GB free) by end of Sprint 7 — looks
like macOS reclaimed purgeable space when needed. Worth
checking again if you're about to do a big build.

---

## Glossary

- **Tier 1** — NIST/IETF-standardised algorithms via Apple's
  CryptoKit. Default-safe, used for real conversations.
- **Tier 2 / Aegis Lab** — community-contributed experimental
  algorithms, sandboxed, never default, requires user to type
  "EXPERIMENTAL" to enable per-conversation.
- **Bootstrap period** — time before the Security Council
  exists (target end of Year 1). During bootstrap, the
  Maintainer can approve crypto-core changes alone, tagged
  `pre-council-approval`.
- **Warrant canary** — monthly signed statement that no
  weakening/backdoor demand has been received. Triggered (by
  silence) if the maintainer is gagged.
- **Conscious deviation** — A documented decision to depart
  from STAGES.md / a prior plan. Lives as a `### Conscious
  deviation` subsection in the relevant STAGES.md entry, with
  rationale, trade-offs, what we're giving up, and the
  `pre-council-approval` stamp. Four exist so far.
- **PQXDH** — Signal's post-quantum extended triple
  Diffie-Hellman protocol. Aegis ships its own implementation
  in `Sources/AegisCrypto/PQXDH.swift`.
- **ML-KEM / ML-DSA** — NIST FIPS 203 / 204, post-quantum KEM
  and digital signatures (formerly Kyber / Dilithium).
- **HKDF / HMAC / SHA-256** — RFC-standard primitives consumed
  via Apple's CryptoKit.
- **CAVP / ACVP** — NIST validation programs that publish KAT
  vectors.
- **At-rest storage key** (Sprint 8) — a per-conversation
  256-bit AES-GCM key kept in the iOS Keychain, used to seal
  message plaintext for storage. Distinct from wire-side
  ratchet keys (which are forward-secure and discarded).
  `Sources/AegisStorage/ConversationStorageKey.swift`.
- **TwoUserDemo** (Sprint 8) — synthetic Alice + Bob bootstrap
  on a single device. Runs a real PQXDH handshake, seeds two
  ratchet sessions, creates two `ConversationStore` rows, and
  routes send/receive between them when the user toggles
  persona.
  `Sources/AegisApp/TwoUserDemo.swift`.

---

## What this session covered (chronological)

1. **Pickup of prior session's state**: ran the verification
   checklist, all green. Test count was 224 / 3 skipped / 0
   failures at start.
2. **Sprint 8 planning round**: surfaced the three settled
   choices (storage layer = raw SQLite via system sqlite3,
   on-disk encryption = ratchet ciphertext as-is per the wire-
   side framing, UI scope = two-user toggle option B). User
   said yes to all three.
3. **Sprint 8 commit 1** (`4f36347`): SQLite wrapper +
   migrations runner + schema v1 (conversations + messages).
   16 new tests; count → 240.
4. **Sprint 8 commit 2** (`8c765e7`): Codable on the ratchet
   types + schema v2 + `RatchetSessionStore`. 16 new tests;
   count → 256.
5. **Mid-sprint design fork surfaced**: forward-secrecy /
   display tension — ratchet ciphertext can't be re-decrypted
   for thread display. Surfaced options A (store plaintext +
   rely on iOS Data Protection), B (per-conversation Keychain
   storage key), C (cache per-message keys). User picked B.
6. **Sprint 8 commit 3** (`d8127e3`): `ConversationStorageKey`
   + `ConversationStore` with at-rest AEAD + AAD-bound to
   (conversation, message, direction). 17 new tests; count →
   273.
7. **Sprint 8 commit 4** (`8c65a48`): Conversations tab +
   `ConversationsListView` + `ConversationThreadView`.
   `AppState` extended with the SQLite stack. 7 new tests;
   count → 280. iOS build verified, app smoke-launched on
   simulator (3 tabs visible).
8. **Sprint 8 commit 5** (`9a71a0e`): `TwoUserDemo` —
   synthetic Alice + Bob with real PQXDH handshake on one
   device. Persona segmented control wired. 10 new tests;
   count → 290.
9. **Sprint 8 commit 6 / closeout** (`75a5d10`): integration
   test (`SchemaMigrationIntegrationTests`) covering fresh-DB
   migration → bootstrap → send/receive → read-back through
   real PQXDH. STAGES.md v0.0.9 marked ✅. Tag
   `v0.0.9-sprint-8`. Final count: 292 tests / 3 skipped / 0
   failures.
10. **UI smoke-test**: user manually verified the two-user
    demo on the iPhone 17 Pro simulator. Tap + bootstraps,
    Alice ↔ Bob round-trips work, persona toggle swaps the
    POV correctly. (Brief detour into trying to drive the
    simulator via CGEvent clicks — partial success but slower
    than manual testing; the user confirmed verbally.)
11. **Push + CI**: pushed `main` + `v0.0.9-sprint-8`. Both
    CI runs green (~40s and ~60s). Issue #12 closed with a
    DoD-ticked comment.
12. **Sprint 9 planning round**: surfaced backend choice
    (A/B/C) + sub-decisions. User confirmed no Apple Developer
    Program enrolment yet, which constrains the path:
    - A blocked (CloudKit needs paid Apple account)
    - C premature
    - **B chosen**, with **polling instead of push** because
      APNs also needs the paid account
    - Wire format JSON, server scope minimal HTTP API,
      separate `aegis-relay` repo settled
    - Server runtime (Vapor / Go / Swift NIO) is the one open
      sub-decision when this session ended

---

## Final checklist before the new session begins

When the new agent picks up:

- [ ] Run the verification checklist at the top of this file.
- [ ] Confirm `swift test` exits with 292 / 3 skipped / 0
      failures.
- [ ] Confirm CI is green on `origin/main`.
- [ ] Confirm the Aegis app is still installed on the iPhone
      17 Pro simulator and the Conversations tab works
      (tap + → bootstrap → toggle persona → send a message
      → flip persona → see it as incoming).
- [ ] Read `docs/STAGES.md` v0.0.10 entry (Sprint 9).
- [ ] Read the open Sprint 9 issue body at #13 for the
      definition-of-done checklist that needs ticking at tag
      time.
- [ ] When the user answers the **server runtime question**
      (Vapor / Go / Swift NIO), start commit 1 (wire format
      types — pure client-side Swift, no networking).
- [ ] Use the established settled-choices-table /
      planning-round pattern for any further sub-decisions.
- [ ] Tag commits crypto-core where they touch
      `Sources/AegisCrypto/Tier1/**` paths. For new wire-format
      types in `Sources/AegisCrypto/Wire/**` (likely path),
      use `crypto-core(wire):` per the Sprint 8 precedent for
      crypto-adjacent types — these are on-the-wire artefacts
      whose drift would break interop, so the discipline
      applies.
- [ ] Remember the **May 2026 canary** is due on or after
      **2026-05-01** (3 days from this handoff). User has
      agreed to draft + sign on May 1 — offer to do it then.
      Recipe is in `canary/` directory comment above and in
      `canary/2026-04.txt` as a template.
- [ ] When tagging `v0.0.10-sprint-9`, write the **fourth
      Conscious deviation** in STAGES.md: "Sprint 9 push-
      notification consumer deferred to Sprint 9b pending
      Apple Developer Program enrolment."

---

*New agent: read this file, run the verification checklist,
then read STAGES.md and the four governance docs (MISSION.md,
THREAT-MODEL.md, GOVERNANCE.md, ALGORITHM-SUBMISSION.md). When
the user answers the server runtime question, start the
remaining planning-round confirmation and then commit 1
(wire format types). The user's tone preferences matter —
terse, table-formatted, no hype, surface decisions before
code, end big chunks with status snapshots, surface mid-sprint
forks rather than guessing.*
