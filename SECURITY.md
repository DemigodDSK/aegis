# Security Policy

## Reporting a vulnerability

Please report vulnerabilities by email.

**Primary address (when domain is live):**
`security@aegisproject.org`

**Interim address (until domain registration completes):**
Open a private GitHub Security Advisory at
https://github.com/DemigodDSK/aegis/security/advisories/new
or email the maintainer via their GitHub-noreply address.

**PGP key fingerprint:** `TO BE GENERATED — published to
https://aegisproject.org/security.asc and to keys.openpgp.org
once available.`

### What to include in your report

- A description of the vulnerability
- Steps to reproduce, or proof-of-concept code
- The version (commit SHA) you tested against
- Whether the issue has been disclosed elsewhere
- Whether you wish to be credited publicly (and how)

### What to expect from us

| Stage | Timeline |
|---|---|
| Acknowledgement of receipt | Within 72 hours |
| Triage and severity classification | Within 7 days |
| Fix in private branch | As soon as practicable |
| Coordinated public disclosure | 90 days from initial report (negotiable for severe issues, especially actively-exploited ones) |
| Publication in `audit-history.md` | At time of disclosure |

We will never silently patch a vulnerability. We will never ask
you to delay public disclosure beyond 90 days unless we have a
working fix and a documented operational reason.

## Scope

In scope for this policy:

- The Aegis iOS application (any released version)
- The cryptographic core (`Sources/AegisCrypto/Tier1/` and
  `Sources/AegisCrypto/Registry/`)
- The Aegis backend services
- The build, signing, and release pipeline

Out of scope:

- Tier 2 (sandbox) algorithms — these are explicitly unaudited;
  vulnerabilities in them are expected and not security incidents
- Vulnerabilities in third-party dependencies — please report
  upstream first; we will track and patch
- Issues requiring physical access to an unlocked device
- Social-engineering attacks against users

## Recognition

Researchers who report valid vulnerabilities are credited in
[`audit-history.md`](audit-history.md) (with their permission).
Aegis does not currently have a paid bug bounty programme. We
hope to fund one once project funding stabilises.

## Our commitments

- We will never knowingly insert a backdoor.
- We will never weaken a published cryptographic guarantee
  without notifying users in the app and updating the public
  threat model.
- We will publish a monthly warrant canary
  (see [GOVERNANCE.md](GOVERNANCE.md) — "Warrant canary").

## Threat model

The full threat model — what we protect against, what we don't,
and what trust assumptions you take on by using Aegis — is at
[THREAT-MODEL.md](THREAT-MODEL.md). Read it before relying on
Aegis for anything serious.
