# Aegis — Session Handoff

**Purpose:** complete context for a new Claude Code session so it can
continue this project without losing any decisions, conventions, or
credentials.

**How to use:** in a new Claude Code session, paste the contents of
this file as your first message. The new agent will have full context.

---

## TL;DR for the new agent

Read this whole document, then `cat` these in order to get the canonical
project state:

```bash
cd ~/Documents/aegis
cat MISSION.md
cat THREAT-MODEL.md
cat GOVERNANCE.md
cat ALGORITHM-SUBMISSION.md
cat docs/STAGES.md
git log --oneline --decorate
gh issue list
swift test 2>&1 | tail -5
```

If `swift test` shows "Executed 25 tests, with 3 tests skipped and 0
failures (0 unexpected)" then the project is in a healthy state and you
can pick up at the **"What to do next"** section below.

---

## Project identity

- **Name:** Aegis
- **One-liner:** "Post-quantum messaging, in the open."
- **Repository:** https://github.com/DemigodDSK/aegis  (public)
- **Local path:** `~/Documents/aegis`
- **Maintainer:** Datta Sai Krishna N (`@DemigodDSK`, dsk7699@gmail.com)
- **License:** AGPL v3 (Apache 2.0 dual-license planned for crypto core in Year 2)
- **Current version:** v0.0.2.1 polish pass complete, Sprint 2 next

## Why this project exists (the ONE thing you must internalise)

Datta is building an **iOS messenger** with two distinguishing properties:

1. **NIST-standardised post-quantum cryptography by default** (ML-KEM-768
   hybridised with X25519 for key exchange; AES-256-GCM for messages;
   ML-DSA-65 for signatures).
2. **A sandboxed cryptography "laboratory" tier** (Aegis Lab) where
   community contributors can submit experimental algorithms — clearly
   marked, never the default, never used for real conversations without
   explicit informed user opt-in.

The user is NOT trying to dethrone Signal or iMessage. The audience is
journalists, lawyers, academics, security researchers, and privacy-
conscious individuals who want auditable, swappable cryptography rather
than a black box.

The user is willing to take 5+ years on this. The mission is the
constraint, not revenue.

---

## Working principles (DO NOT VIOLATE)

These were established across many hours of conversation with the user.
They are non-negotiable:

1. **No drift from architecture.** Every code/governance change must
   honour MISSION.md, THREAT-MODEL.md, GOVERNANCE.md, and
   ALGORITHM-SUBMISSION.md. If a sprint requires a deviation, write a
   "conscious deviation" entry in the relevant document FIRST, get
   user approval, then change code.

2. **Cryptographic core changes are special.** During the bootstrap
   period (until a Security Council exists, target end of Year 1) the
   maintainer can merge them alone, but every such commit must be
   tagged `pre-council-approval` in the commit message body and a
   tracking issue should be opened.

3. **Honesty over marketing.** The user has explicitly chosen to tell
   users in onboarding "do NOT use this app for life-or-liberty
   situations until v2.0; use Signal instead." This is a feature, not
   a bug. Never soften it.

4. **No "creative" cryptography in Tier 1.** Tier 1 = NIST/IETF
   standards only. Tier 2 sandbox = community algorithms with a giant
   "EXPERIMENTAL" warning. The two tiers MUST NOT mix in the default
   user path.

5. **No backdoors, ever.** GOVERNANCE.md explicitly commits the
   project to shutting down rather than complying with a backdoor
   demand. The warrant canary is the public surfacing mechanism.

6. **Don't promise more than you ship.** The version-by-version
   capability table in THREAT-MODEL.md is the source of truth for
   user-facing claims. If a column says NO, the app must not claim
   that capability.

7. **Defer "creative" work that the user keeps wanting to add.**
   The user has a habit of jumping to fancy features (post-quantum +
   blockchain + AI etc.). Politely refocus on the next sprint's
   documented goal. He has agreed to phase-by-phase discipline; hold
   him to it.

8. **The user is not a cryptographer (and neither are you).** Tier 1
   approvals require unanimous Security Council vote. Until the
   Council exists, the user is doing approvals himself with the
   `pre-council-approval` tag. Do not green-light novel algorithms.

---

## Repository state — what's shipped

### Tags (commits in chronological order)

| Tag | Commit | What it shipped |
|---|---|---|
| `v0.0.1-foundation` | `20613f0` | 13 governance/policy MD docs + LICENSE + first canary |
| `v0.0.2-sprint-1` | `ca622f8` | AegisCrypto SwiftPM target with AES-256-GCM (CryptoKit) + 5 NIST KATs |
| `v0.0.2.1-polish` | `b1782b9` | CI, STAGES.md, issue templates, .editorconfig, About sidebar |
| (no tag yet) | `147afcb` | PGP key + signed canary + SECURITY.md fingerprint |

### Files (28 tracked)

```
.editorconfig
.github/
  ISSUE_TEMPLATE/algorithm-submission.yml   # Tier 2 form
  ISSUE_TEMPLATE/bug_report.yml             # standard bug
  ISSUE_TEMPLATE/config.yml                 # routes security to advisories
  workflows/ci.yml                          # 4-job CI
.gitignore
.well-known/security.asc                    # maintainer PGP public key
ALGORITHM-SUBMISSION.md                     # Tier 1 vs Tier 2 policy
CLA.md                                      # Contributor License Agreement v1.0
CODE_OF_CONDUCT.md                          # Contributor Covenant 2.1
CONFLICTS.md                                # COI disclosures
CONTRIBUTING.md                             # contributor process
CONTRIBUTORS.md                             # roster (only maintainer so far)
GOVERNANCE.md                               # Security Council + decision rules
LICENSE                                     # AGPL v3 (full text)
MISSION.md                                  # what this is and isn't
Package.swift                               # SwiftPM manifest
README.md                                   # public landing page
SECURITY.md                                 # disclosure policy + PGP fingerprint
Sources/AegisCrypto/
  AegisError.swift                          # exhaustive error enum
  Encryption.swift                          # protocol + EncryptedPayload
  EncryptionMethod.swift                    # Tier 1/Tier 2 metadata
  Tier1/AESGCM.swift                        # CryptoKit-backed AES-256-GCM
THREAT-MODEL.md                             # what we protect/don't + capability table
Tests/AegisCryptoTests/
  AESGCMKATTests.swift                      # 5 NIST CAVP vectors
  AESGCMTests.swift                         # 23 contract tests
audit-history.md                            # permanent record (empty so far)
canary/2026-04.txt                          # inaugural warrant canary
canary/2026-04.txt.asc                      # PGP signature, verifies cleanly
docs/STAGES.md                              # per-sprint roadmap v0.0.1 → v0.1.0
```

### GitHub state

- 3 issues open (#1 CryptoKit SIGTRAP bug, #2 expand KATs from BoringSSL, #3 Sprint 2 plan)
- 8 custom labels: `bug` `upstream` `tier-1` `crypto-core` `enhancement` `tests` `epic` `sprint-2`
- 12 topics: messaging, cryptography, post-quantum, post-quantum-cryptography, swift, ios, swiftui, privacy, open-source, encryption, aes-gcm, ml-kem
- About sidebar description set
- CI passing on every push (4 jobs across macOS 14 + 15)
- Discussions disabled, blank issues disabled, projects enabled
- Project board: https://github.com/users/DemigodDSK/projects/1

### Test status

```
swift test
# →
# Executed 25 tests, with 3 tests skipped and 0 failures (0 unexpected)
```

The 3 skipped tests are documented:
`testDecrypt_wrongKey_throwsAuthenticationFailed`,
`testDecrypt_tamperedCiphertext_throwsAuthenticationFailed`,
`testDecrypt_tamperedTag_throwsAuthenticationFailed`. They skip because
of an Apple-side CryptoKit bug on macOS 26.x / Swift 6.3.x — see
GitHub issue #1. The auth-failure code path IS verified by
`testDecrypt_tamperedAAD_throwsAuthenticationFailed` which passes.

---

## Credentials and secrets (where they live, what they protect)

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
| Public key on keyserver | `keys.openpgp.org` (sent successfully) |
| Revocation cert | `~/.gnupg/openpgp-revocs.d/E7B656B4D0DDBB0729ED462FFF1164C0B4D28DE4.rev` |
| gpg-agent cache TTL | 1 hour (so user only types passphrase once per session) |
| pinentry | `/opt/homebrew/bin/pinentry-mac` (macOS GUI dialog) |

**Critical:** the user MUST back up the revocation certificate to a
location outside the repo (suggested: `~/Documents/aegis-keys-backup-DO-NOT-COMMIT/`).
Without it, a stolen private key cannot be revoked for 2 years. Remind
the user once if they haven't done it yet — but only once.

### GitHub authentication

- `gh` CLI installed at `/opt/homebrew/bin/gh` (v2.89.0 as of last session)
- Authenticated as `DemigodDSK`
- Token scopes: `gist`, `read:org`, `repo`, `workflow`
- Auth method: HTTPS with personal access token (stored in macOS keyring)

### Other tools installed via Homebrew

- `qemu` (was used for the prior NexusOS project; not used by Aegis)
- `mtools`, `dosfstools`, `gptfdisk`, `xorriso` (NexusOS leftovers; safe to leave)
- `gnupg` (used for canary signing)
- `pinentry-mac` (passphrase prompts for gpg-agent)
- `gh` (GitHub CLI)
- Standard Xcode 26.0 / Swift 6.3.1 from Apple

---

## Conventions established in conversation

These are written into the codebase but worth surfacing:

### Commit message format

```
type(scope): short summary

Optional longer body wrapped at 72 cols.

Refs: #N
Co-authored-by: Name <email>
```

`type` ∈ `feat`, `fix`, `docs`, `refactor`, `test`, `chore`, `crypto-core`.

The cryptographic-core type is required for any change touching files
listed in GOVERNANCE.md "What is the cryptographic core?" — currently
five Swift files plus the four governance MD files plus this
HANDOFF.md (added below).

### Versioning

- `v0.X.Y-sprint-N` for sprint completions (e.g. `v0.0.2-sprint-1`)
- `v0.X.Y.Z-polish` for polish/cleanup passes (e.g. `v0.0.2.1-polish`)
- `v0.X.Y-foundation` for the inaugural foundation drop only
- v1.0 reserved for first audit-complete release

### Tag every meaningful release

User has been clear about this. After every commit that ends a sprint
or a polish pass, create an annotated tag. Don't let tags drift from
commits.

### Push only after `swift test` exits 0

CI gates merges, but local `swift test` MUST pass before any push. If
it fails or hangs, do NOT push and do NOT bypass — investigate.

### Always use the `gh` CLI for GitHub operations

Issues, labels, PRs, releases — all via `gh`. Don't ask the user to
click through web forms unless `gh` genuinely doesn't support the
operation. The user's web-UI attempt at issue creation produced a
stray file (`issues/new`) that we had to clean up; that's the cost of
not using gh.

### Documentation in plain English

The user explicitly chose readability over jargon. When writing docs,
prefer "we encrypt your messages" over "we apply AEAD primitives to
your message bodies." The technical detail belongs in the code
comments, not the user-facing docs.

---

## Known issues / things to be honest about

1. **macOS 26 CryptoKit SIGTRAP** (issue #1). Three tests skipped.
   Auth-failure path verified via the AAD-tamper test. When Apple
   ships a fix, remove the `XCTSkipIf(true, ...)` calls.

2. **Hand-transcribed NIST vectors are risky** (issue #2). We have 5
   verified vectors; need ~20 more, fetched programmatically from
   BoringSSL's vetted test data with a checksum-pinned fetcher.

3. **No iOS app yet.** Sprint 5 (v0.0.6) introduces the SwiftUI app
   shell. Earlier sprints stay library-only.

4. **No backend yet.** Sprint 7 (v0.0.8) introduces transport. Until
   then there is no networking, no Firebase, no CloudKit.

5. **No real users yet.** Don't tell anyone to use this app for
   anything sensitive until v1.0 + first external audit. The "use
   Signal instead" line in onboarding is real.

6. **Security Council does not exist.** First-priority Year 1 work.
   Until then, every cryptographic-core commit is `pre-council-approval`.

7. **Stray commit `fbde603`** ("Add new issues for AES.GCM and
   enhancement tasks") in git history is from when the user tried to
   create issues via the GitHub web editor and accidentally committed
   a file. The file was removed in commit `7941d57` but the commit
   itself stays for honest history. This is fine — don't try to
   rewrite history.

8. **Polish pass commit `147afcb`** (PGP key + signed canary +
   SECURITY.md update) was NOT tagged. Consider whether to tag it as
   `v0.0.2.2-pgp` or just roll it into the next sprint's tag.

---

## What to do next — Sprint 2

The user has explicitly asked for **Sprint 2: ML-KEM-768 + X25519
hybrid key encapsulation** to be the next thing. Tracking issue is
GitHub #3. Definition of done is in `docs/STAGES.md` "v0.0.3" section.

### Immediate first steps for Sprint 2

1. **Investigate ML-KEM availability in Apple CryptoKit**
   on macOS 26 / iOS 18+. As of session end this was uncertain. Check:
   - `xcrun --sdk macosx --show-sdk-version`
   - `swift -e "import CryptoKit; print(_typeName(MLKEM.self))"` (or
     similar — discover the right symbol via Xcode autocomplete)
   - Apple's CryptoKit changelog for "PQ", "Kyber", "ML-KEM"
   - PQ3 protocol references in Apple security documentation

2. **If CryptoKit ships ML-KEM:** use it. Wrap with our `Encryption`
   protocol-style abstraction (likely a NEW `KeyEncapsulation`
   protocol since KEM is conceptually different from AEAD).

3. **If CryptoKit does NOT ship ML-KEM:**
   - Vendor liboqs at a pinned commit + checksum
   - Write Swift bindings via system module map
   - Document the vendoring decision in a new `docs/VENDORING.md`
   - Add the vendored source to CI builds

4. **Either way:**
   - Create `Sources/AegisCrypto/Tier1/MLKEM768.swift`
   - Create `Sources/AegisCrypto/Tier1/X25519KEM.swift`
   - Create `Sources/AegisCrypto/Tier1/HybridKEM.swift` (concat + HKDF combiner)
   - Define a new `KeyEncapsulation` protocol parallel to `Encryption`
   - Fetch NIST ML-KEM-768 KAT vectors from a vetted source
   - Write `Tests/AegisCryptoTests/MLKEM768KATTests.swift`
   - Tag `v0.0.3-sprint-2` after `swift test` passes

5. **Document any deviations**. If, for example, you decide to vendor
   a Rust-based PQ library via FFI, that's a "conscious deviation"
   from MISSION.md ("no third-party dependencies in v0.0.x"). Update
   MISSION.md before merging.

### What NOT to do in Sprint 2

- Don't add an iOS app yet. That's Sprint 5.
- Don't add a backend. That's Sprint 7.
- Don't add ML-DSA signatures. That's Sprint 3.
- Don't add forward secrecy. That's Sprint 4.
- Don't expand the AES-GCM KATs in this sprint — that's separate
  work tracked in issue #2 and can ship as its own commit.

### Acceptance criteria for Sprint 2

Per docs/STAGES.md:

```
- [ ] Investigate Apple CryptoKit ML-KEM availability
- [ ] If absent: vendor liboqs (pinned commit + checksum)
- [ ] KeyEncapsulation protocol (parallel to Encryption)
- [ ] Tier1/MLKEM768.swift
- [ ] Tier1/X25519KEM.swift
- [ ] Tier1/HybridKEM.swift (concat + HKDF combiner)
- [ ] NIST ML-KEM-768 KAT vectors passing
- [ ] Tag v0.0.3-sprint-2
```

After Sprint 2 ships: publish a new monthly canary
(`canary/2026-05.txt`), sign it with the same PGP key, push.

---

## How to verify everything is intact (when starting the new session)

Run this checklist at the start of the new session:

```bash
cd ~/Documents/aegis

# 1. Repo health
git status                                          # should be clean
git log --oneline --decorate -10
git remote -v                                       # should point to DemigodDSK/aegis

# 2. Tools
which gh swift gpg                                   # all should be present
gh auth status                                       # should show DemigodDSK logged in
gpg --list-secret-keys --keyid-format LONG          # should show ed25519 key

# 3. PGP signature still verifies
gpg --verify canary/2026-04.txt.asc canary/2026-04.txt
# expected: "Good signature from \"Datta sai krishna N ...\""

# 4. Tests still pass
swift test 2>&1 | tail -3
# expected: "Executed 25 tests, with 3 tests skipped and 0 failures"

# 5. CI is green
gh run list --limit 3

# 6. Open issues
gh issue list
# expected: #1, #2, #3
```

If any of those fails, fix it before starting Sprint 2.

---

## Tone the user wants from a Claude Code agent

Across many turns the user has consistently rewarded these behaviours:

- **Honest about limitations.** When something is broken or you don't
  know, say so. Don't try to wave it away.
- **Concrete next steps.** Tell the user the next 2–3 commands or
  decisions, not abstract advice.
- **Brutally direct when stakes are high.** The user has thanked me
  for being uncomfortable-but-correct ("you have a habit of
  redesigning instead of building", "you should not call this
  quantum-secure"). Maintain that.
- **No hype.** No "Amazing!", no rocket emojis in every message, no
  congratulating on trivialities. The user has shipped real work and
  knows it.
- **Use the user's ambition without indulging it.** When he says "let's
  build the next Signal", say "let's build something better than
  trying to be Signal — here's the actual realistic path." Then ground
  in the next-sprint deliverable.
- **Status snapshots when transitioning.** End big chunks of work
  with a table of what's done and what's next. The user reads tables.

The user does NOT want:
- Excessive cheerleading
- Long explanatory paragraphs when bullet points suffice
- Re-explaining things he's already shown he understands
- Asking permission for tiny obvious actions (just do them)
- "Let me know if..." closers without a specific next question

---

## What this conversation covered (chronological summary)

1. **Original ask:** open-source iOS messenger like iMessage with BYO
   encryption. User had tried Rork (React Native + Expo) — it failed
   (non-functional crypto, infinite TypeScript loops). User had also
   started a native Swift project at `~/OpenSourceMessenger`.

2. **Audit of the Swift project:** revealed 1,350 lines but won't
   compile, AES key derivation broken, encryption never wired into
   message-sending path, two duplicate source trees, multiple API
   mismatches. Documented honestly.

3. **Architecture-vs-reality conversation:** user chose Path X
   ("architecture-pure, even if slow"). We agreed to scrap and
   restart. Established 12-stage roadmap (later distilled into
   docs/STAGES.md).

4. **Vision refinement:** user clarified — open-source, post-quantum,
   curated marketplace of community algorithms, willing to take 5+
   years, OK with selling later if to "good hands" but not
   opportunistically. We named the project **Aegis**.

5. **Foundation phase (v0.0.1-foundation):** wrote 13 governance/
   policy documents from scratch with the user's commitments embedded.
   Set up GitHub, pushed first commit + tag.

6. **Sprint 1 (v0.0.2-sprint-1):** real Swift code. Wrote AegisCrypto
   SwiftPM target with AES-256-GCM via CryptoKit + 5 NIST CAVP test
   vectors. 23 contract tests. Hit a macOS 26 CryptoKit SIGTRAP bug
   that we worked around by skipping 3 tests with full documentation.
   `swift test` exits 0.

7. **Polish phase (v0.0.2.1-polish):** GitHub Actions CI (4 jobs
   across macOS 14 + 15), STAGES.md roadmap, 3 issue templates,
   .editorconfig, repo About sidebar with 12 topics.

8. **PGP identity (commit 147afcb, untagged):** generated maintainer
   ed25519 key (`E7B6...8DE4`), exported public key into repo at
   `.well-known/security.asc`, published to keys.openpgp.org, signed
   the inaugural warrant canary, embedded fingerprint into SECURITY.md
   with verification instructions.

9. **End of session:** user asked for handoff doc → this file.

---

## Glossary (terms used throughout the project)

- **Tier 1** — NIST/IETF-standardised algorithms, default-safe, used
  for real conversations.
- **Tier 2 / Aegis Lab** — community-contributed experimental
  algorithms, sandboxed, never default, requires user to type
  "EXPERIMENTAL" to enable per-conversation.
- **Bootstrap period** — the time before the Security Council exists
  (target: end of Year 1). During bootstrap, the Maintainer can
  approve crypto-core changes alone, tagged `pre-council-approval`.
- **Warrant canary** — monthly signed statement that no
  weakening/backdoor demand has been received. Triggered (by
  silence) if the maintainer is gagged.
- **PQXDH** — Signal's post-quantum extended triple Diffie-Hellman
  protocol; the inspiration for our key-exchange design (Sprint 3).
- **ML-KEM** — NIST FIPS 203, post-quantum key encapsulation,
  formerly known as Kyber.
- **ML-DSA** — NIST FIPS 204, post-quantum digital signatures,
  formerly known as Dilithium.
- **CAVP** — NIST Cryptographic Algorithm Validation Program; source
  of our test vectors.
- **HKDF** — RFC 5869, key derivation function we use to derive
  AES-256 keys from KEM shared secrets.
- **AAD** — additional authenticated data, the AEAD pattern's mechanism
  for authenticating bytes that aren't encrypted (e.g. a conversation
  ID).

---

## Final checklist before closing this session

Confirm with the user (or just verify yourself in the new session):

- [x] Repo public at github.com/DemigodDSK/aegis
- [x] CI green
- [x] PGP key generated and on keyserver
- [x] First canary signed and verifiable
- [x] SECURITY.md has fingerprint embedded
- [ ] User has backed up revocation certificate (REMIND THEM ONCE)
- [ ] User has chosen whether to tag commit `147afcb` as a polish
      release or roll it into Sprint 2's tag (mild preference for
      tagging `v0.0.2.2-pgp` since it's a meaningful boundary)

---

*Saved at end of conversation. New agent: read this file, then read
the four governance docs, then `git log` and `gh issue list`. You'll
have full context. Begin Sprint 2 when the user says go.*
