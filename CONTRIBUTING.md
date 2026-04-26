# Contributing to Aegis

Thank you for considering a contribution. Aegis is an
intentionally small project with intentionally heavy process
around its cryptographic core. Please read this document fully
before opening a pull request.

## Three kinds of contribution

| Type | Process | Reviewer |
|---|---|---|
| Routine code (UI, networking, build, docs) | Standard PR | Maintainer |
| Cryptographic core changes | `crypto-core` PR + 7-day public review | Security Council (or Maintainer during bootstrap — see [GOVERNANCE.md](GOVERNANCE.md)) |
| New algorithm proposal | Issue first, then PR per [ALGORITHM-SUBMISSION.md](ALGORITHM-SUBMISSION.md) | Maintainer (Tier 2) or unanimous Council (Tier 1) |

If you are unsure which category your change falls into, open
an issue first and ask. We would rather you ask than guess.

## Before you start

1. **Read the four foundational documents**
   ([MISSION.md](MISSION.md), [THREAT-MODEL.md](THREAT-MODEL.md),
   [GOVERNANCE.md](GOVERNANCE.md),
   [ALGORITHM-SUBMISSION.md](ALGORITHM-SUBMISSION.md)).

2. **Sign the [Contributor License Agreement](CLA.md)** —
   required before any code contribution can be merged. Sign by
   adding your name to [CONTRIBUTORS.md](CONTRIBUTORS.md) in
   your first PR with the line:
   `I have read and accept the CLA at v1.0`.

3. **Read the [Code of Conduct](CODE_OF_CONDUCT.md).** We
   enforce it.

4. **Open an issue describing what you plan to do** before
   writing non-trivial code. Avoids wasted effort on changes we
   won't accept.

## Code style

- **Swift code**: SwiftLint is enforced in CI with the project's
  `.swiftlint.yml`. Match the existing style.
- **Naming**: Apple's
  [API Design Guidelines](https://www.swift.org/documentation/api-design-guidelines/).
- **Tests**: Required for any non-trivial change. Cryptographic
  changes require Known-Answer Tests (KATs) from an authoritative
  source.
- **Comments**: Explain *why*, not *what*. Code shows what it
  does; comments explain why it does it that way.

## Commit messages

```
type(scope): short summary

Optional longer body explaining the change in more detail. Wrap
at 72 characters. Reference issues with #N.

Refs: #123
Co-authored-by: Name <email>
```

`type` is one of: `feat`, `fix`, `docs`, `refactor`, `test`,
`chore`, `crypto-core`. The last is required for any change to
files in the cryptographic core (see GOVERNANCE.md for the list).

## Pull request checklist

- [ ] Issue opened and discussed before significant work began
- [ ] CLA accepted in CONTRIBUTORS.md
- [ ] Tests added or updated
- [ ] Documentation updated if behaviour changed
- [ ] CI passes (build, tests, lint, KATs where applicable)
- [ ] If touching cryptographic core, the PR is labelled
      `crypto-core` and the description includes:
   - Rationale
   - Threat model impact
   - Test vectors added
   - Audit considerations

## What we will not accept

We will close (with explanation) PRs that:

- Add cryptocurrency, token, or "Web3" features
- Add advertising, telemetry, or analytics
- Weaken any commitment in [THREAT-MODEL.md](THREAT-MODEL.md)
  without first amending the threat model itself per the
  governance process
- Add support for ad-supported or surveillance-funded business
  models
- Implement DRM or platform lock-in
- Are submitted without a signed CLA

## Help wanted

Areas where contribution is most needed right now:

- Applied cryptographers willing to serve on the Security Council
  (open an issue with label `council-interest`)
- Swift engineers with iOS / CryptoKit experience
- Documentation writers, especially for the threat model and
  user-facing onboarding copy
- Security researchers who would conduct lightweight reviews
  before formal audits begin (open an issue with label
  `security-review`)

## Questions

Open a discussion thread (when GitHub Discussions is enabled) or
an issue with the label `question`.
