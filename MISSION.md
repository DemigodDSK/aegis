# Mission

Aegis exists to make strong, post-quantum cryptography visible,
auditable, and accessible — first to the people who need it most,
eventually to anyone who wants it.

## Why this exists

Every major messenger today (iMessage, WhatsApp, Telegram, even
Signal on the server side) asks users to trust a black box. The
cryptography is not inspectable, not swappable, not auditable.
When a flaw is found or a backdoor demanded, users have no
recourse and no visibility.

We believe the next decade will demand stronger guarantees:

- Quantum computers will eventually break today's standard
  cryptography. The data encrypted today and intercepted today
  ("harvest now, decrypt later") is at risk.
- Regulated industries (defense, healthcare, journalism, law)
  need communications they can independently verify.
- Users deserve to *understand* the security of the tools they
  trust with their lives, not just to be told it's there.

## What this is

A native iOS messenger that:

- Uses NIST-standardised post-quantum cryptography by default
  (ML-KEM-768 for key encapsulation, AES-256-GCM or
  ChaCha20-Poly1305 for messages, ML-DSA-65 for signatures).
- Ships every line of cryptographic code as open source under a
  permissive license, source-level reproducibly built, signed.
- Maintains a *separate, sandboxed laboratory* (Aegis Lab) where
  researchers and students can experiment with novel algorithms
  — clearly marked, never the default, never used for real
  conversations without explicit informed user opt-in.
- Documents its threat model, trust assumptions, known
  limitations, and security audit history publicly and honestly.

## What this is NOT

- Not a Signal or iMessage replacement for the general public.
  We don't have the resources or distribution to win at billion-
  user scale. We're a credible niche tool, not a mass-market app.
- Not feature-parity with iMessage. Voice, video, FaceTime,
  business messaging, RCS interop, Apple Pay integration etc.
  are out of scope. Text and image messaging only at v1.0.
- Not a marketing exercise. No "unbreakable", no "military-grade",
  no "quantum-secure" claims that aren't backed by a specific
  audit and citation.
- Not a place to invent crypto in production. Novel algorithms
  live in the sandbox. The default path uses only audited,
  standardised primitives.
- Not a venue for cryptocurrency, tokens, or "Web3" features.
- Not a profit-maximising business. It may eventually sustain
  full-time work through grants, sponsorship, or enterprise
  licensing — but the mission is the constraint, not the revenue.

## Success looks like

**Year 1**: A working, auditable, post-quantum iOS messenger that
two strangers can use to communicate, with the entire cryptographic
boundary documented and open.

**Year 3**: Used by at least one real journalist, one real lawyer,
and one academic group. First external security audit completed
and published.

**Year 5**: A reference implementation that other privacy projects
cite and learn from. A small community of contributors. Sustainable
funding for one or two full-time maintainers.

**Year 10**: Either acquired by an organisation we trust to honour
the mission, or self-sustaining as an independent project. The
cryptography we shipped has helped real people in real situations.

If we never reach Year 10, that's fine — what we ship in Years 1
through 3 will already exist in the world, freely, for anyone who
needs it.

## License

The Aegis application is licensed under
[GNU Affero General Public License v3 (AGPL v3)](LICENSE). This
ensures any modified version deployed as a service must release
its source under the same terms — protecting the open ecosystem.

The cryptographic core library (when extracted as a separate
sub-package, planned for Year 2) will be **dual-licensed** under
Apache 2.0 to enable embedding in other applications, accelerating
the broader goal of stronger cryptography everywhere.

All contributors must sign the project's
[Contributor License Agreement (CLA)](CLA.md), preserving the
project's ability to evolve its license if and when it is
transferred to a long-term steward.

The project name "Aegis" and its logo, once established, will be
registered as a trademark to protect the integrity of the brand
from confusing forks or impersonation.

## Acquisition stance

This project is not for sale opportunistically. If, at some
future point, an organisation aligned with the mission of this
project expresses interest in stewarding it long-term — and that
organisation can credibly commit to maintaining the open-source
license, the public audit history, the Security Council's
authority, and the ban on backdoors — the maintainer will
consider a transfer.

Until then, the project remains independent.

## Maintainer

**Datta Sai Krishna N**
([@DemigodDSK](https://github.com/DemigodDSK))
project founder, initial sole maintainer.

A Security Council will be formed during Year 1 — see
[GOVERNANCE.md](GOVERNANCE.md).
