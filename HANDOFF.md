# Aegis — Session Handoff

**Purpose:** complete context for a new Claude Code session so it
can continue this project without losing any decisions,
conventions, or credentials.

**How to use:** in a new Claude Code session, paste the contents
of this file as your first message AND open the session in
`~/Documents/aegis` so the agent has direct file access. The new
agent will have full context.

**Last updated:** 2026-04-28 evening, after Sprint 7 Phase A
landed (the iOS app runs on the iPhone-17-Pro simulator with the
correct dark theme). The original handoff (early Apr 27,
end-of-Sprint-1, just before Sprint 2) is preserved in git
history at the corresponding commit if you need to read it cold.

---

## What you (the new agent) are walking into

The user is **Datta Sai Krishna N** (`@DemigodDSK`), maintainer
of the Aegis post-quantum messenger. He's mid-conversation with
the previous Claude Code session about Sprint 8 (Persistence).
The previous session laid out three decisions and is waiting for
his answer:

> 1. **Storage layer:** SQLite via system `sqlite3` C-API — yes /
>    use SwiftData / use something else?
> 2. **Encryption posture:** ratchet ciphertext as-is — yes /
>    add Keychain-backed second layer?
> 3. **UI scope:** two-user toggle (option B per the discussion)
>    — yes / minimal / defer?

When he answers, you start Sprint 8 commit 1 (storage layer) per
his choice. Plan and rationale for the three decisions are below
under "Sprint 8 — what's next".

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
# expected: "Executed 224 tests, with 3 tests skipped and 0 failures"

# 5. CI is green on origin/main
gh run list --limit 3

# 6. Open issues
gh issue list
# expected open: #1, #9, #10, #11, #12, #13, #14 (and that's it)

# 7. iOS smoke-test artefacts present
ls Aegis.xcodeproj && ls iOS/Sources iOS/Resources project.yml
# all should exist

# 8. The Aegis app is installed on the iPhone 17 Pro simulator
xcrun simctl listapps 145620FA-CBF9-4617-B698-7449A19CE517 \
    | grep -A 1 demigoddsk
# expected: shows io.github.demigoddsk.Aegis bundle path
```

If any of those fail, fix it before starting Sprint 8.

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
| **Current version** | `v0.0.7-sprint-6` shipped; Sprint 7 Phase A landed on `main` (commits `02cd59e` → `2984409`); tag `v0.0.8-sprint-7` HELD until Phase B (Apple Developer Program + TestFlight) |

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
   FIRST, get user approval, then change code. Three deviations
   exist so far (Sprint 2 X-Wing, Sprint 3 split, Sprint 6→7
   split) — see `docs/STAGES.md` for the format.

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
| `v0.0.7-sprint-6` | `3fc0539` | iOS app shell as SwiftPM library + Keychain-backed identity persistence (`AegisStorage`) + macOS demo executable. App is visible today via `swift run aegis-demo` on macOS |
| **`v0.0.8-sprint-7`** | — | **Phase A landed** (commits `02cd59e` → `2984409` on `main`): Xcode project via XcodeGen, iOS app target, `swift run` and iOS-Simulator-installable. **Tag held until Phase B** (TestFlight) |

### After Sprint 6 closeout, Sprint 7 split was carved out

Original Sprint 7 (Persistence) → renumbered to **Sprint 8**.
New Sprint 7 = iOS distribution. Subsequent sprints all shifted
by one slot. Documented as "Conscious deviation — split iOS
distribution from Sprint 6" in `docs/STAGES.md` v0.0.8 section.
After this split:

| Sprint | Version | Topic | Status |
|---|---|---|---|
| 7 | v0.0.8 | iOS distribution (Xcode + IPA + TestFlight) | 🚧 Phase A landed; Phase B held |
| 8 | v0.0.9 | Persistence + local conversations | 📋 next (this session's work) |
| 9 | v0.0.10 | Networking | 📋 |
| 10 | v0.1.0 | First public alpha — external testers | 📋 |

### Sprint 7 Phase A — what landed (commits since v0.0.7)

| Commit | Scope |
|---|---|
| `5fd9ea4` | crypto-core(storage): introduce AegisStorage Keychain wrapper |
| `03a00dc` | feat(app): AegisApp SwiftUI target skeleton — AppState + theme + RootView |
| `3809b38` | feat(app): mandatory 3-screen onboarding flow |
| `7c8b22e` | feat(app): identity setup + demo encrypt/decrypt screen |
| `2bbae3e` | feat(app): Settings → Security view + Capability struct + main TabView |
| `3673a70` | feat(app): aegis-demo macOS executable host — the runnable artifact |
| `3fc0539` | docs(stages): mark v0.0.6 Sprint 5 shipped (this is the v0.0.7-sprint-6 tag commit) |
| `fab7774` | docs(stages): split iOS distribution from Sprint 6 (deviation note) |
| `02cd59e` | feat(ios): Aegis.xcodeproj + iOS app target via XcodeGen |
| `1145c33` | docs(ios): runbooks for Phase A (smoke-test) and Phase B (TestFlight) |
| `90b55ae` | fix(ios): three project.yml fixes that unblock simulator install |
| `3c3ae5a` | docs(ios): record the IXErrorDomain Code 13 troubleshooting recipe |
| `2984409` | fix(app): force dark colour scheme + drop screen padding around TabView |

### Test status

`swift test` → **224 tests, 3 skipped (issue #1), 0 failures**.

The 3 skipped tests are `testDecrypt_wrongKey_*`,
`testDecrypt_tamperedCiphertext_*`, `testDecrypt_tamperedTag_*`
— Apple-side CryptoKit AES.GCM SIGTRAP on macOS 26.x (issue #1).
The auth-failure path is verified via
`testDecrypt_tamperedAAD_throwsAuthenticationFailed` which
passes.

### KAT coverage across the suite

236 distinct known-answer-test verifications:
- 5 hand-transcribed NIST CAVP AES-GCM vectors (Sprint 1)
- 65 BoringSSL-mirrored AES-GCM vectors (Sprint 4 polish)
- 25 NIST FIPS 203 ML-KEM-768 KeyGen vectors (Sprint 2)
- 3 IETF X-Wing draft vectors × 3 pass-types each = 9 (Sprint 2)
- 25 NIST FIPS 203 ML-KEM-1024 KeyGen vectors (Sprint 4)
- 25 NIST FIPS 204 ML-DSA-65 KeyGen vectors (Sprint 3)
- 160 Wycheproof ML-DSA-65 verify-side cases (Sprint 3)
- Pinned PQXDH HKDF combiner snapshot (Sprint 4 polish)
- Pinned ChainKey advancement + RootKey ratchet snapshots
  (Sprint 5)

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
    RatchetSession.swift               # Bidirectional Double Ratchet state + encrypt/decrypt
    Tier1/
      AESGCM.swift                     # AES-256-GCM (only Tier 1 AEAD)
      HybridKEM.swift                  # X-Wing PQ-hybrid KEM (CryptoKit XWingMLKEM768X25519)
      MLKEM1024.swift                  # Bare ML-KEM-1024 (CryptoKit MLKEM1024) for PQXDH
      MLDSA65.swift                    # ML-DSA-65 signatures (CryptoKit MLDSA65)
      X25519.swift                     # X25519 namespace + DHKeyPair envelope

  AegisStorage/                        # Keychain-backed persistence layer
    AegisStorage.swift                 # saveIdentity / loadIdentity / deleteIdentity / purgeAll
    Keychain.swift                     # Internal SecItem* wrapper
    KeychainAccessibility.swift        # Type-safe enum for kSecAttrAccessible* attrs

  AegisApp/                            # SwiftUI surface (consumed by both macOS demo and iOS app)
    Theme.swift                        # AegisTheme — palette, typography, layout
    AppState.swift                     # @Observable @MainActor view-model state
    RootView.swift                     # Top-level routing (onboarding → identity → main)
    OnboardingFlow.swift               # 3-screen mandatory honesty flow
    IdentitySetupScreen.swift          # Display-name input + key generation
    DemoViewModel.swift                # Encrypt/decrypt logic for demo screen
    DemoScreen.swift                   # Encrypt/decrypt UI
    SettingsScreen.swift               # About card + Security capability list
    Capability.swift                   # 14-row capability list mirroring THREAT-MODEL.md
    MainTabView.swift                  # Demo + Settings tab view

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
  AegisCryptoTests/                    # 200+ tests covering all the above
    AESGCM*.swift                      # AES-GCM contract + KAT tests
    HybridKEM*.swift                   # X-Wing wrapper tests
    MLKEM768/1024 SmokeTests.swift     # Apple-API tripwires for KEMs
    MLDSA65*.swift                     # Signature wrapper + KAT tests
    Ratchet*.swift                     # Double Ratchet primitive + session tests
    PQXDH*.swift                       # Handshake tests + pinned HKDF KAT
    PrekeyBundle*.swift                # Bundle generation + signature-chain verify tests
    SafetyNumber*.swift                # Order-independence + format pinning
    Identity*.swift                    # IdentityKeyPair + JSON round-trip
    X25519*.swift                      # DH primitive tests
    PQXDHRatchetIntegrationTests.swift # End-to-end Sprint 4 → Sprint 5 seam
    Vectors/
      README.md                        # Provenance + SHA-256 for every KAT file
      *.json, *.txt                    # KAT data (committed verbatim from upstream sources)
  AegisStorageTests/                   # Keychain CRUD tests
  AegisAppTests/                       # AppState + DemoViewModel + Capability list tests

docs/
  STAGES.md                            # Per-sprint roadmap — SOURCE OF TRUTH for what's
                                       # shipped and what's planned. Includes all three
                                       # "Conscious deviation" subsections.
  IOS-RUNBOOK.md                       # Phase A: how to run on simulator / iPhone via free Apple ID
  IOS-DISTRIBUTION-RUNBOOK.md          # Phase B: Apple Developer Program → TestFlight

canary/
  2026-04.txt + .asc                   # April canary, PGP-signed by maintainer key
  # 2026-05.txt is drafted in chat history — to be created on or after May 1.
  # Recipe: copy 2026-04.txt structure, change "Reporting period: May 2026" and
  # "Date of publication: 2026-05-XX", item #4 should mention commit d71dd3d as
  # the only THREAT-MODEL.md edit since April. Sign with the maintainer PGP key.

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
| #11 | epic, sprint-7 | Sprint 7 tracker (iOS distribution). Phase A landed; Phase B (TestFlight) waits for Apple Developer Program enrolment. |
| #12 | epic, sprint-8 | **Sprint 8 tracker (Persistence + local conversations) — the active sprint.** |
| #13 | epic, sprint-9 | Sprint 9 tracker (Networking). |
| #14 | epic, sprint-10 | Sprint 10 tracker (First public alpha, v0.1.0). |

Closed for context: #2 (AES-GCM KAT expansion), #3 (Sprint 2),
#4 (Sprint 4), #5 (Sprint 5), #6 (Sprint 6), #7 (CI checksums),
#8 (Node.js 24 actions).

---

## Sprint 8 — what's next (the active sprint)

The user just chose Sprint 8. Three architectural decisions were
surfaced; he has not yet answered.

### Decision 1 — Storage layer

| Option | Pros | Cons |
|---|---|---|
| **SwiftData** | Apple-native, modern Codable-friendly API, no third-party deps, integrates with SwiftUI `@Query` | Has had migration sharp edges in iOS 17/18; pre-1.0 for a security-sensitive project |
| **CoreData** | Mature, well-understood migration path, Apple-native | Verbose API, NSManagedObject subclassing, harder to audit |
| **Raw SQLite** (system framework) | Fully transparent — anyone can inspect with `sqlite3` CLI; no third-party | We write more code (schema, migrations, query layer) |
| **GRDB** (third-party) | Best Swift SQLite wrapper | Third-party dep; needs a mission-document deviation note |
| **Flat encrypted files** | Simplest | Scales poorly past ~1000 messages |

Mild recommendation: **raw SQLite via the built-in `sqlite3`
C-API**. Audit-friendly, no third-party deps, ~200 extra lines
of schema/query helpers, ".dump" inspectable.

### Decision 2 — On-disk encryption posture

| Option | What it does |
|---|---|
| Store ratchet ciphertext as-is | DB rows contain the existing AEAD-protected bytes from the Double Ratchet |
| Add a Keychain-backed second layer | Belt-and-suspenders; defends against a hypothetical ratchet-state leak |

Mild recommendation: **as-is** — the ratchet is already strong
AEAD; double-encrypting adds key-management complexity for
marginal benefit. Option 2 is a later-sprint hardening.

### Decision 3 — UI scope for "two locally-defined users"

| Option | Effort | Outcome |
|---|---|---|
| A — Minimal: list + thread, single user | ~4 commits | Persistence demonstrated, no two-party feel |
| B — Two-user toggle: "You are Alice / now you are Bob" | ~6 commits | Genuine two-party demo on one device |
| C — Defer the UI to Sprint 9 | ~3 commits | Tighter Sprint 8; needs a deviation note since spec says "two locally-defined users" |

Mild recommendation: **B** — matches the spec, and the toggle
is also useful for testing throughout development.

### Once the user answers, the proposed Sprint 8 commit plan

1. Storage schema + chosen storage layer + migrations
2. `RatchetSession` persistence (extend AegisStorage)
3. `ConversationStore` API (create / list / load /
   append-message)
4. UI: conversation list + thread view
5. Two-user toggle wiring (if option B)
6. Migration test + closeout commit + tag `v0.0.9-sprint-8`

---

## Sprint 7 status (what's "in flight")

### Phase A (landed on `main`, NOT yet tagged)
- Aegis.xcodeproj generated by XcodeGen from project.yml
- iOS app target builds for iOS 26.4 SDK
- App installs and runs on iPhone 17 Pro simulator (verified via
  `xcrun simctl install` + `xcrun simctl launch`)
- Dark theme renders correctly (after the `2984409` fix)
- Onboarding → identity setup → demo encrypt/decrypt → settings
  all work end-to-end on the simulator
- `docs/IOS-RUNBOOK.md` (Phase A: simulator + free-Apple-ID
  iPhone instructions)

### Phase B (waits on Datta's action)
- Apple Developer Program enrolment ($99/yr)
- App Store Connect record creation
- Real signing certificate + provisioning profile
- First TestFlight build pushed to internal testers (just
  Datta)
- Smoke-test on production-signed build
- THEN tag `v0.0.8-sprint-7` (the runbook's last step)

`docs/IOS-DISTRIBUTION-RUNBOOK.md` is the recipe. ~30 minutes
once enrolment is approved.

---

## Three iOS-26-specific lessons from this session

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
5. **Push commits + tag together.**
6. **Watch CI** until both runs are green.
7. **Close the tracking issue** with a citation to the tag.

### Always use the `gh` CLI for GitHub operations

Issues, labels, PRs, releases — all via `gh`. Don't ask the
user to click through web forms unless `gh` doesn't support
the operation.

### Documentation in plain English

Prefer "we encrypt your messages" over "we apply AEAD
primitives to your message bodies." Technical detail belongs
in code comments, not user-facing docs.

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

### Disk hygiene note

The user's Mac was at 99% capacity (218 MB free) at one point
during this session — common contributors to "System Data" on
macOS dev machines: Xcode DerivedData, CoreSimulator runtimes
(2.6 GB after iOS 26.4 download), Application Support caches
(VS Code 1.4 GB, Google Chrome 1 GB), Homebrew cache (726 MB).
By the end of session disk was at 75% (3.8 GB free) — looks
like macOS reclaimed purgeable space when needed.

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
  `pre-council-approval` stamp. Three exist so far.
- **PQXDH** — Signal's post-quantum extended triple
  Diffie-Hellman protocol. Aegis ships its own implementation
  in `Sources/AegisCrypto/PQXDH.swift`.
- **ML-KEM / ML-DSA** — NIST FIPS 203 / 204, post-quantum KEM
  and digital signatures (formerly Kyber / Dilithium).
- **HKDF / HMAC / SHA-256** — RFC-standard primitives consumed
  via Apple's CryptoKit.
- **CAVP / ACVP** — NIST validation programs that publish KAT
  vectors.

---

## What this session covered (chronological)

1. **Verification-and-pickup of prior session's state**:
   confirmed Sprint 1 + canary work was clean. ML-KEM
   investigation revealed Apple ships PQ CryptoKit natively
   (`MLKEM768`, `MLKEM1024`, `XWingMLKEM768X25519`, `MLDSA65`,
   `MLDSA87`, `SecureEnclave.MLKEM768/1024`, `SecureEnclave
   .MLDSA65/87`).
2. **Sprint 2 (v0.0.3-sprint-2):** X-Wing PQ-KEM via Apple's
   `XWingMLKEM768X25519` + KATs. Conscious deviation #1 (X-Wing
   instead of concat+HKDF combiner).
3. **Sprint 3 split (Conscious deviation #2)**: split ML-DSA-65
   from PQXDH + Keychain. Shipped Sprint 3 = ML-DSA-65 only.
4. **Sprint 4 (v0.0.5-sprint-4):** PQXDH key exchange + identity
   types + prekey bundles + safety numbers + bare ML-KEM-1024 +
   X25519. Six-commit stack.
5. **Sprint 5 (v0.0.6-sprint-5):** Double Ratchet end-to-end.
   Five-commit stack ending with the PQXDH→Ratchet integration
   test.
6. **Polish backlog cleared:** issues #2, #7, #8 closed; pinned
   PQXDH KAT shipped (#10 partial).
7. **Sprint 6 (v0.0.7-sprint-6):** SwiftUI surface + Keychain
   identity persistence + macOS demo. The first sprint where
   Aegis became *visible* — `swift run aegis-demo` opens a
   real working app on macOS.
8. **README + THREAT-MODEL.md polish:** brought claims tables
   in sync with shipped state; added scope-note paragraph
   above the capability table.
9. **Sprint 6→7 split (Conscious deviation #3):** carved iOS
   distribution out of Sprint 6 into a new Sprint 7. Shifted
   v0.0.9 → v0.0.10, v0.1.0 → Sprint 10. Filed tracking issues
   #11–#14.
10. **Sprint 7 Phase A landed:** Xcode project via XcodeGen,
    iOS app target, runbooks for Phase A and Phase B. Hit and
    fixed three iOS-26-specific install issues (asset catalog
    folder reference, LSRequiresIPhoneOS, ENABLE_DEBUG_DYLIB).
    Verified end-to-end on iPhone 17 Pro simulator. Force-dark
    colour scheme + remove TabView screen padding fix landed
    (`2984409`). User confirmed the app works visually with a
    screenshot showing successful AES-256-GCM round-trip.
11. **May canary recipe drafted** but NOT yet executed (waits
    for May 1+). Recipe content is in this file's `canary/`
    section comment.
12. **Sprint 8 planning round opened:** three decisions
    surfaced; user has not yet answered. End of session.

The user briefly asked about Xcode's Coding Intelligence
panel (whether to install the Xcode-bundled Claude Agent or
enable MCP for external agents). The previous session
recommended leaving both off — the existing `xcodebuild` /
`xcrun` / file-edit / git workflow has been productive
without it. The user hasn't pushed back.

---

## Final checklist before the new session begins

When the new agent picks up:

- [ ] Run the verification checklist at the top of this file.
- [ ] Confirm `swift test` exits with 224 / 3 skipped / 0
      failures.
- [ ] Confirm CI is green on `origin/main`.
- [ ] Confirm the Aegis app is still installed on the iPhone
      17 Pro simulator (or accept that the user may have erased
      it; reinstalling is `xcodebuild build` + `xcrun simctl
      install`).
- [ ] Read `docs/STAGES.md` v0.0.8 entry (the "Conscious
      deviation — split iOS distribution from Sprint 6" note,
      and the v0.0.9 / Sprint 8 entry which is the next-up).
- [ ] Read the open Sprint 8 issue body at #12 for the
      definition-of-done checklist that needs ticking at tag
      time.
- [ ] When the user answers the three Sprint 8 decisions,
      start commit 1 (storage layer schema + chosen storage
      tooling).
- [ ] Use the established settled-choices-table /
      planning-round pattern at the start of EVERY sprint.
- [ ] Tag commits crypto-core where they touch
      `Sources/AegisCrypto/Tier1/**` paths (see GOVERNANCE.md
      §"What is the cryptographic core?"). Storage layer code
      under `Sources/AegisStorage/**` is NOT crypto-core per
      that literal definition — but if Sprint 8 extends
      `AegisStorage` to persist `RatchetSession` (which the
      previous session recommended), the
      persistence-of-secret-material discipline still applies
      (matches the AegisStorage Sprint-6 commit's
      `crypto-core(storage):` type).

---

*New agent: read this file, run the verification checklist,
then read STAGES.md and the four governance docs (MISSION.md,
THREAT-MODEL.md, GOVERNANCE.md, ALGORITHM-SUBMISSION.md). When
the user answers the three Sprint 8 decisions, start the
planning round and then commit 1. The user's tone preferences
matter — terse, table-formatted, no hype, surface decisions
before code, end big chunks with status snapshots.*
