# Aegis

> Post-quantum messaging, in the open.

Aegis is an iOS messenger that uses NIST-standardised post-quantum
cryptography by default and ships every line of cryptographic code
as open source. It is built for people who want to *understand* the
security of the tools they trust — not just be told it's there.

This is an unusual messenger. We will tell you what we don't
protect against (see [THREAT-MODEL.md](THREAT-MODEL.md)). We will
tell you when another tool is a better fit for your situation
(in onboarding). We will publish our security audits, our
governance decisions, and a monthly warrant canary. Trust here is
earned by transparency, not asserted.

## Status

This project is in early development. Current version: **pre-0.1**
(library only — no installable app yet).

| Milestone | Status |
|---|---|
| Foundational documents | ✅ [`v0.0.1-foundation`](https://github.com/DemigodDSK/aegis/releases/tag/v0.0.1-foundation) |
| Maintainer PGP identity + signed warrant canary | ✅ [`v0.0.2.2-pgp`](https://github.com/DemigodDSK/aegis/releases/tag/v0.0.2.2-pgp) |
| Cryptographic core: AES-256-GCM | ✅ [`v0.0.2-sprint-1`](https://github.com/DemigodDSK/aegis/releases/tag/v0.0.2-sprint-1) |
| Cryptographic core: PQ hybrid KEM (X-Wing / ML-KEM-768 + X25519) | ✅ [`v0.0.3-sprint-2`](https://github.com/DemigodDSK/aegis/releases/tag/v0.0.3-sprint-2) |
| Cryptographic core: PQ signatures (ML-DSA-65) | ✅ [`v0.0.4-sprint-3`](https://github.com/DemigodDSK/aegis/releases/tag/v0.0.4-sprint-3) |
| PQXDH key exchange + safety numbers | 📋 Sprint 4 ([#4](https://github.com/DemigodDSK/aegis/issues/4)) |
| Forward secrecy / Double Ratchet | 📋 Sprint 5 ([#5](https://github.com/DemigodDSK/aegis/issues/5)) |
| iOS app shell + Keychain identity | 📋 Sprint 6 ([#6](https://github.com/DemigodDSK/aegis/issues/6)) |
| v0.1 alpha (TestFlight, library + app + transport) | 📋 Sprint 9 |
| External security audit | 📋 v1.0 |
| Initial Security Council | 🚧 Recruiting (see [GOVERNANCE.md](GOVERNANCE.md)) |

Detailed per-sprint roadmap: [docs/STAGES.md](docs/STAGES.md).

## What Aegis is, in one paragraph

A native iOS messenger using ML-KEM-768 (post-quantum key
encapsulation) hybridised with X25519 for key exchange,
AES-256-GCM for message confidentiality, and ML-DSA-65 for
identity signatures. All cryptographic primitives are NIST or
IETF standards. A separate sandbox tier ("Aegis Lab") allows
researchers and students to contribute and study novel algorithms,
clearly marked as unaudited and never used by default.

## What Aegis is NOT

A Signal or iMessage replacement for the general public. We don't
have the resources to win at billion-user scale. We're a credible
niche tool — for journalists, lawyers, academics, security
researchers, and privacy-conscious individuals — not a mass-market
app. See [MISSION.md](MISSION.md) for the full statement.

## Documents to read before contributing

In order:

1. [MISSION.md](MISSION.md) — what we're trying to do
2. [THREAT-MODEL.md](THREAT-MODEL.md) — what we protect against and what we don't
3. [GOVERNANCE.md](GOVERNANCE.md) — who decides what, and how
4. [ALGORITHM-SUBMISSION.md](ALGORITHM-SUBMISSION.md) — how new cryptography enters Aegis
5. [CONTRIBUTING.md](CONTRIBUTING.md) — code, docs, and process
6. [CODE_OF_CONDUCT.md](CODE_OF_CONDUCT.md) — community standards
7. [CLA.md](CLA.md) — required for code contributions
8. [SECURITY.md](SECURITY.md) — how to report a vulnerability

## Build and run

The cryptographic library (`AegisCrypto`) builds and tests with
stock SwiftPM today. The iOS app target arrives at Sprint 6
(v0.0.7).

```bash
# Library + tests — runs today.
swift build
swift test
# Expected at v0.0.4-sprint-3: 73 tests passing, 3 skipped, 0 failures.

# iOS app shell — coming at Sprint 6 (v0.0.7).
# open Aegis.xcodeproj
```

Requires Xcode 26 / Swift 6.2+ on macOS 26 — Apple's native
post-quantum CryptoKit primitives (`MLKEM768`, `MLDSA65`,
`XWingMLKEM768X25519`) are gated `@available(iOS 26.0, macOS
26.0, ...)`, so the SwiftPM platform floor follows them.

## License

Aegis is licensed under [AGPL v3](LICENSE). The cryptographic core
library, when extracted as a separate sub-package (planned for
Year 2), will be additionally available under Apache 2.0 to enable
embedding in other applications.

The name "Aegis" and the project's logo are trademarks held by the
project maintainer, Datta Sai Krishna N, in trust for the project.
Forks must use a different name.

## Maintainer

**Datta Sai Krishna N**
([@DemigodDSK](https://github.com/DemigodDSK))

A Security Council is being recruited during Year 1 — see
[GOVERNANCE.md](GOVERNANCE.md). If you have applied-cryptography
or secure-systems-engineering experience and would consider
serving, please open an issue with the `council-interest` label.

## Funding

Aegis is independently developed. We have not received funding
from any government, corporation, or other organisation.

If we receive funding in the future, the source and amount will
be disclosed publicly. Funding will not influence the project's
mission, governance, or security commitments.

## A note about Signal

If your safety, freedom, or life depends on the privacy of your
communications, **use Signal**, not Aegis. Signal is more mature,
more audited, and protects more metadata than Aegis currently
does. We will tell you in our app's onboarding when Aegis is
ready for high-stakes use. We expect this will be true at v2.0
at the earliest, after at least one external audit. Until then,
we will not pretend otherwise.
