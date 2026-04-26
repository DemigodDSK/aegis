# Governance

This document describes how Aegis is governed: who makes
decisions, what process they follow, and how the project remains
trustworthy as it grows.

## Principles

1. **Cryptographic decisions require expertise we may not have
   alone.** No single person — including the maintainer — should
   be able to silently approve a change that affects cryptographic
   security.

2. **Decisions must be visible.** Major decisions are documented
   publicly. Disagreements are aired publicly. Reversals are
   acknowledged publicly.

3. **The project's mission is the constraint.** Anyone — including
   the maintainer — who would pressure the project to weaken its
   guarantees, insert backdoors, or oversell its capabilities, is
   acting outside the mission and should be resisted.

4. **Bus factor matters.** No critical knowledge or authority
   lives only in one person's head or in one person's hands.

---

## Roles

### Maintainer

**Datta Sai Krishna N**
([@DemigodDSK](https://github.com/DemigodDSK)),
project founder.

Responsibilities:
- Sets product direction
- Reviews and merges pull requests for non-cryptographic code
- Manages releases, signed builds, and infrastructure
- Speaks for the project publicly
- Holds the trademark (once registered) in trust for the project
- Has the authority to transfer the project to a steward
  organisation under the conditions in MISSION.md "Acquisition
  stance"

Limitations on this role:
- Outside the bootstrap period (see below), the Maintainer cannot
  unilaterally merge changes to code classified as
  "cryptographic core". At least one Security Council vote is
  required.
- The Maintainer cannot approve a Tier 1 algorithm. Only the
  Security Council can.
- The Maintainer's own pull requests touching cryptographic core
  follow the same review process as any contributor's.

### Security Council

A group of 3 to 7 individuals with relevant expertise (applied
cryptography, secure systems engineering, or formal verification)
who collectively govern changes to the cryptographic core.

**Year 1 goal:** Form an initial Council of 3 members. The
Maintainer is one. The other two are recruited from:

- Graduate students or post-docs at a recognised cryptography
  research group (IACR member labs)
- Engineers with a track record in production cryptography
  (Signal, libsodium, RustCrypto, BoringSSL, NaCl, OQS, etc.)
- Independent cryptographic auditors

Council members are credited publicly in the repo. They serve
2-year terms, renewable. They may resign at any time. The Council
selects new members by majority vote.

Council responsibilities:
- Review and approve all changes to the cryptographic core
- Approve all Tier 1 algorithms before they ship
- Review and approve the threat model on every major version
- Adjudicate vulnerability reports
- Provide a public statement (collectively or individually) any
  time the project is asked to weaken its guarantees by anyone

The Council is *not* responsible for:
- Product direction
- Non-cryptographic code review
- Day-to-day maintenance
- Funding decisions

### Contributors

Anyone who submits code, documentation, or algorithm proposals.
Required to sign the [Contributor License Agreement](CLA.md)
before contributions can be merged.

Recognised in [CONTRIBUTORS.md](CONTRIBUTORS.md) after first
merged contribution.

---

## Bootstrap period (until Security Council exists)

Until the Security Council reaches its initial size of 3 members
(target: end of Year 1), the project operates under transitional
governance:

- The Maintainer may approve and merge changes to the
  cryptographic core alone, but must:
  - Tag all such commits with `pre-council-approval` in the
    commit message
  - Open a tracking issue in the repo describing the change
    and its security rationale
  - Stage them for retroactive review by the Council once formed

- During the bootstrap period, no version higher than v0.x
  (pre-1.0) shall be released. The 1.0 release is gated on the
  Council existing AND having reviewed all `pre-council-approval`
  commits.

- The Maintainer's first priority during Year 1 is recruiting
  the initial Council. This is treated as a project-blocking
  responsibility, not an aspiration.

- During the bootstrap period, the Maintainer publicly publishes
  a monthly "bootstrap status" update describing: (a) cryptographic
  decisions made, (b) Council recruitment progress, (c) any
  pressure or unusual requests received.

---

## What is the "cryptographic core"?

Concrete list (any change to a file in these paths requires
Security Council approval, not just Maintainer approval —
except during bootstrap):

- `Sources/AegisCrypto/Tier1/**`
- `Sources/AegisCrypto/Registry/**`
- `Sources/Aegis/Services/EncryptionService.swift`
- `Sources/Aegis/Services/MessageService.swift`
  (specifically, the encrypt/decrypt call sites)
- `Sources/Aegis/Services/AuthService.swift`
  (specifically, key generation and storage)
- `THREAT-MODEL.md`
- `ALGORITHM-SUBMISSION.md`
- `GOVERNANCE.md` (this file)

Files explicitly NOT in the cryptographic core:
- UI / Views
- Networking transport (TLS configuration is in core, but
  HTTP request shape is not)
- Build scripts, CI configuration
- Documentation other than the four files above

When in doubt, the Maintainer asks the Council.

---

## Decision process

### Routine changes (90% of PRs)
- Author opens PR
- CI runs (build, tests, KAT vectors, lint, fuzz)
- Maintainer reviews and merges
- No Council involvement needed

### Cryptographic core changes (post-bootstrap)
- Author opens PR labelled `crypto-core`
- CI runs the full extended suite (including differential testing
  against reference implementations)
- At least 2 Council members must approve
- A 7-day public review window is opened on the PR before merge
  (community comment period)
- Maintainer merges only after both conditions are met
- The PR description must include: rationale, threat model impact
  analysis, test vectors added, audit considerations

### New Tier 1 algorithm proposals
- Even more strict — see [ALGORITHM-SUBMISSION.md](ALGORITHM-SUBMISSION.md)
- Requires unanimous Council approval (not majority)
- Requires reference to a published cryptanalytic literature
  showing the algorithm has been studied
- Requires test vectors from an authoritative source (NIST KATs,
  RFC test vectors, etc.)

### Vulnerability reports
- Reported to `security@` (email)
- Acknowledged within 72 hours by the Maintainer
- Triaged within 7 days by the Council
- Severity determined by Council
- Fix developed in a private branch
- 90-day responsible disclosure timeline begins
- Coordinated public disclosure when fix is ready
- Published to `audit-history.md` permanently

### Mission-changing decisions
The following decisions require Council super-majority (2/3) and
public 30-day comment period:
- Changing the license
- Transferring the project to a steward organisation (see
  MISSION.md "Acquisition stance")
- Removing or relaxing any commitment in THREAT-MODEL.md
- Changing this governance document

---

## Conflicts of interest

Council members or the Maintainer disclose:

- Employment by entities producing competing or related products
  (other messengers, cryptography vendors, security firms with
  audit business that might affect us)
- Funding received from entities with potential influence
- Government or law-enforcement relationships

Disclosed in a public [CONFLICTS.md](CONFLICTS.md) and updated
annually. A disclosed conflict does not bar participation but
does inform the community.

---

## When a Council member disagrees with a merge

Any single Council member may flag any cryptographic-core change
as needing wider review by adding a `requires-discussion` label.
This pauses merge for 14 days while the change is debated
publicly. Used sparingly; respected absolutely.

If after the discussion the Council remains split, the change is
not merged. The default is "do not change cryptographic code
without consensus".

---

## Backdoor and pressure protocol

If the Maintainer or any Council member is approached by any
party — government, employer, prospective acquirer, anyone — to:

- Insert a backdoor
- Weaken the cryptographic guarantees for any user or party
- Suppress a vulnerability disclosure
- Hand over user data beyond the minimum legally required

The recipient of the request must:

1. Refuse on the record.
2. Notify the Council privately within 7 days unless legally
   prohibited from doing so.
3. If legally prohibited from disclosure, the project's warrant
   canary (see below) ceases to be updated, signalling the
   community that something has occurred.
4. The Council convenes to decide whether to: continue with
   modified governance, transfer the project to a jurisdiction
   that does not compel such modifications, or shut the project
   down entirely.

The mission is the floor.

---

## Warrant canary

The Maintainer publishes a signed monthly statement to:

1. The project website (`aegisproject.org/canary` once live)
2. The Maintainer's verified Mastodon/Bluesky account
3. The repo at `canary/YYYY-MM.txt.asc`

All three publication points must be present each month.
Triangulation prevents a compromise of any single channel from
silently invalidating the canary.

The text reads:

> "As of [date], Aegis has not received any requests from any
> government or other party to weaken its cryptographic
> guarantees, insert a backdoor, or hand over user data beyond
> the minimum legally required. The project has not been
> compelled to make any change it would not have made for
> technical or community reasons alone."

If this statement stops being published or its language changes,
the community should infer that the canary has been triggered.
The exact text and signature must be reproducible from a public
template.

---

## Succession

If the Maintainer becomes unable or unwilling to continue, the
Security Council selects a new Maintainer by majority vote from
among:

- Existing Council members
- Long-standing project contributors (≥ 12 months active)
- An external candidate by unanimous Council vote

The Maintainer's role MUST NOT be inherited by family, employer,
acquirer, or any party who does not earn it through the Council's
selection process.

---

## How this document changes

Changes to GOVERNANCE.md follow the "mission-changing decisions"
process: Council super-majority + 30-day public comment.

This rule prevents the governance from being silently weakened.
