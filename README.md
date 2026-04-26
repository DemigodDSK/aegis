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

This project is in early development. Current version: **pre-0.1**.

| Milestone | Status |
|---|---|
| Foundational documents (this repo) | ✅ Published |
| First working build | 🚧 In progress |
| Initial Security Council | 🚧 Recruiting (see [GOVERNANCE.md](GOVERNANCE.md)) |
| v0.1 alpha (PQ key exchange + AES-GCM messaging) | Planned |
| External security audit | Planned for v1.0 |

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

(Coming with v0.1.)

```bash
# Eventually:
swift build
swift test
open Aegis.xcodeproj
```

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
