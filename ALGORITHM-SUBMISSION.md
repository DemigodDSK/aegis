# Algorithm Submission

This document describes how cryptographic algorithms enter Aegis,
the difference between Tier 1 and Tier 2 algorithms, and the
contributor process for proposing new algorithms.

## The two tiers

### Tier 1 — Approved

Algorithms in the default trust path. Used automatically for new
conversations. Used by users who do not explicitly opt out.

**Tier 1 is closed by default.** New algorithms enter Tier 1 only
through unanimous Security Council approval. We expect Tier 1 to
contain very few algorithms — possibly fewer than ten ever — and
to grow extremely slowly.

Initial Tier 1 algorithms (v0.1):

- **ML-KEM-768** (NIST FIPS 203) — post-quantum key encapsulation
- **X25519** — classical Diffie-Hellman, hybridised with ML-KEM
- **AES-256-GCM** (NIST FIPS 197 + SP 800-38D) — authenticated
  encryption
- **ChaCha20-Poly1305** (RFC 8439) — authenticated encryption
  alternative (planned for v0.3)
- **ML-DSA-65** (NIST FIPS 204) — post-quantum digital signatures
- **HKDF-SHA-256** (RFC 5869) — key derivation
- **SHA-256** (NIST FIPS 180-4) — hashing

Required properties for Tier 1:

- Standardised by NIST, IETF, ISO, or similarly authoritative body
- Published cryptanalytic literature exists and is reasonably
  current
- A canonical reference implementation exists from the standards
  body or a recognised research group
- Test vectors are available from an authoritative source
- The algorithm has been in public review for at least 5 years
  (this rule may be relaxed for direct successors, e.g. ML-KEM
  succeeded Kyber after extensive analysis)

### Tier 2 — Sandbox (Aegis Lab)

Algorithms contributed by the community for research, education,
and experimentation. Never the default. Cannot be selected for a
conversation without explicit, typed user confirmation (see
THREAT-MODEL.md "In-app honesty").

Tier 2 has lower bars and an open submission process. Anyone may
submit. Approval is by Maintainer review (not Council), focused
on:

- Does it correctly implement the algorithm the author claims?
- Does it round-trip on its own test vectors?
- Is it free of obvious bugs that would crash the app?
- Is it accompanied by a clear description and a notice that it
  is not audited?

Tier 2 algorithms are NOT a stepping-stone to Tier 1. The criteria
are completely different. A Tier 2 algorithm has not earned Tier 1
status no matter how popular it becomes.

---

## Tier 2 submission process

To submit an algorithm for the sandbox:

### 1. Open an issue first

Use the "New algorithm proposal" issue template. Describe:

- The algorithm's name and a one-paragraph description
- Whether it is your own design or an implementation of an
  existing algorithm
- If existing: cite the paper or specification
- If novel: this is fine for Tier 2 but be honest that it is
  novel and unaudited

A Maintainer responds within 14 days with feedback or
encouragement to proceed.

### 2. Implement

Your implementation must:

- Conform to the `Encryption` protocol in
  `Sources/AegisCrypto/Tier2/`
- Be written in Swift (preferred). Native bridging permitted with
  Maintainer approval and source code of the bridged library
  included.
- Include a per-algorithm `README.md` describing what the algorithm
  does, its claimed security properties (or none), and its
  provenance
- Include a `TestVectors.swift` file with at least 5 round-trip
  test cases that the CI will run

### 3. Required disclosure

Every Tier 2 algorithm directory must contain a `DISCLAIMER.md`
file with this exact text (you may add to it but not subtract):

> "This algorithm is part of the Aegis Tier 2 sandbox (Aegis Lab).
> It has NOT been independently audited and may contain bugs,
> design flaws, or vulnerabilities. Do not use this algorithm to
> protect information whose disclosure would cause real harm. The
> author of this algorithm makes no warranty as to its security."

### 4. Submit pull request

Open the PR. CI runs:

- Build
- Test vector round-trips
- Lint
- Static analysis

Maintainer reviews and either merges, requests changes, or
declines with explanation.

### 5. After merge

The algorithm appears in the in-app sandbox section, marked with
the yellow-flask icon. Users who select it must type
"EXPERIMENTAL" to confirm.

---

## Tier 1 promotion (Council process only)

A Tier 2 algorithm does NOT automatically become eligible for
Tier 1. The path to Tier 1 is separate and requires:

1. Council member nomination
2. Independent cryptanalytic review (typically requires hiring an
   external auditor; cost may be funded by the project budget if
   strategically important)
3. Reference to an authoritative standardisation track
4. Unanimous Council approval
5. 90-day public comment window
6. Final merge after the comment period

We expect this path to be used rarely. Most algorithms that are
"good enough for Tier 1" will already be NIST/IETF standards when
they arrive.

---

## What we will refuse

The following submissions are refused at intake, without further
review:

- Algorithms claimed to be "unbreakable" or "absolutely secure"
  (no algorithm meets this bar; the claim is itself a red flag)
- Algorithms whose security depends on the algorithm being secret
  (security through obscurity is not security)
- Modifications to Tier 1 algorithms branded as a "new" algorithm
  (e.g., "AES-256 but with a longer key" is not a contribution;
  it is a misunderstanding)
- Cryptocurrency or token primitives unrelated to messaging
- Submissions whose author refuses to sign the CLA

These refusals are stated publicly with their reason in the
issue. We will not engage in extended debate on them.

---

## Author credit

Every Tier 2 algorithm credits its author in the per-algorithm
README. The author's name appears in the in-app description of
the algorithm. This is recognition, not endorsement.

Tier 1 algorithms credit the original designers and the
standardisation body. Implementations of Tier 1 algorithms in
this repo also credit their implementer in
[CONTRIBUTORS.md](CONTRIBUTORS.md).

---

## Right to remove

The Maintainer may remove any Tier 2 algorithm if:

- A serious vulnerability is discovered in it (and the author
  cannot or will not patch within 30 days)
- It violates the project's Code of Conduct
- It is used to enable harm (e.g., used as the basis of a
  closed-source attack tool)

Removal is announced publicly with reasoning. The author may
appeal to the Council.

---

## Algorithm submission template

Use this Markdown template inside your algorithm's directory
`README.md`:

```
# Algorithm: [Name]

## What it does
[1–3 sentences]

## Provenance
[ ] Implementation of an existing standard. Citation: ___
[ ] Novel design by the author. Description and rationale below.

## Claimed security properties
[ ] Confidentiality (against a passive adversary)
[ ] Confidentiality (against an active adversary)
[ ] Integrity
[ ] Authenticity
[ ] Forward secrecy
[ ] Post-compromise security
[ ] Post-quantum resistance
[ ] Other: ___

## Known limitations
[Be honest. List what you know, suspect, or have not analysed.]

## Test vectors
[List the source. If the algorithm is novel, include at least 5
self-generated round-trip test cases in TestVectors.swift.]

## License
Apache 2.0 (required for inclusion in this project's Tier 2.)

## Author
[Name, contact, and a sentence about your background.]

## Disclaimer
See DISCLAIMER.md (required, unmodified).
```
