# Security Policy

## Reporting a vulnerability

Please report vulnerabilities by email.

**Primary address (when domain is live):**
`security@aegisproject.org`

**Interim address (until domain registration completes):**
Open a private GitHub Security Advisory at
https://github.com/DemigodDSK/aegis/security/advisories/new
or email the maintainer (Datta Sai Krishna N) at
**dsk7699@gmail.com**.

## Maintainer PGP key

All maintainer signatures (warrant canaries, security advisories,
release tags) are signed with this key. Verify using the
fingerprint and the public key bundled in this repository at
[`.well-known/security.asc`](.well-known/security.asc).

| | |
|---|---|
| **Fingerprint** | `E7B6 56B4 D0DD BB07 29ED  462F FF11 64C0 B4D2 8DE4` |
| **Algorithm**   | ed25519 (signing) + cv25519 (encryption subkey) |
| **Created**     | 2026-04-27 |
| **Expires**     | 2028-04-26 |
| **User ID**     | Datta sai krishna N (Aegis project maintainer) <dsk7699@gmail.com> |

### Verify the public key in this repo matches the published one

```bash
# Import the public key from the repo
gpg --import .well-known/security.asc

# OR import from keys.openpgp.org
gpg --keyserver keys.openpgp.org --recv-keys E7B656B4D0DDBB0729ED462FFF1164C0B4D28DE4

# Confirm the fingerprint matches:
gpg --fingerprint E7B656B4D0DDBB0729ED462FFF1164C0B4D28DE4
```

The fingerprint shown should be exactly:
`E7B6 56B4 D0DD BB07 29ED  462F FF11 64C0 B4D2 8DE4`

If it does not match, do not trust any signature claiming to be
from this maintainer. Open a public GitHub issue immediately —
this is exactly the kind of attack the warrant canary protocol
is designed to surface.

### Verify the warrant canary

```bash
gpg --verify canary/2026-04.txt.asc canary/2026-04.txt
```

Expected output: `Good signature from "Datta sai krishna N..."`.

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
