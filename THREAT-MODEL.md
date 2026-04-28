# Threat Model

This document states explicitly who Aegis protects its users
against, who it does not, and what users must trust for the
security guarantees to hold.

We will be honest about our limitations. A messenger that
overpromises is more dangerous than one that does not exist.

---

## Adversaries we DO protect against

### 1. Passive network observers
ISPs, public Wi-Fi operators, cellular carriers, anyone who can
capture packets on the wire. They see TLS-protected traffic to
our server and nothing about message content.

### 2. Active network attackers (with caveats)
Man-in-the-middle attempts, BGP hijacks, certificate-authority
compromise, downgrade attacks. Our cryptography uses ML-KEM-768
hybridised with X25519 for key exchange, so a network attacker
cannot decrypt messages even with quantum capability.

*Caveat:* only if the user verifies their contact's safety
number out-of-band. Without verification, an active attacker
who also controls our server could substitute keys at first
contact.

### 3. Compromised messenger server
If our database is breached, our admin is malicious, or we are
legally compelled to hand over data: the server only ever sees
ciphertext for message bodies. Plaintext message content is
never accessible to the server.

*Limit:* server still sees metadata — see "what we do NOT
protect" below.

### 4. Future quantum computers ("harvest now, decrypt later")
An adversary recording encrypted traffic today, planning to
decrypt it years from now using a large-scale quantum computer,
cannot succeed against ML-KEM-768. This is the central reason
for choosing post-quantum cryptography over conventional
Diffie-Hellman alone.

### 5. Other users on the platform
Users cannot read messages they were not sent. Users cannot
impersonate other users without the impersonated user's signing
key. Users cannot inject messages into other users' conversations.

---

## Adversaries we DO NOT protect against

We protect *the channel*, not *the endpoints*. This is the
fundamental limitation of any messenger, and we will not pretend
otherwise.

### 1. Compromised endpoints
If your iPhone is rooted, has malware, is stolen while unlocked,
or screen-recorded — we cannot protect your messages. The
attacker reads them as you read them.

### 2. Operating system compromise
We rely on iOS's sandbox, Secure Enclave, and Keychain. A
compromise of iOS itself (kernel exploit, malicious app store
update, jailbreak with malware) defeats us.

### 3. Hardware compromise
Apple Secure Enclave attacks (extremely rare, generally requires
physical access and significant resources) defeat the key-storage
guarantees. We have no defence against nation-state hardware
attacks on Apple silicon.

### 4. Coercion / legal compulsion
We cannot protect against you or your contact being legally
required to decrypt messages, or being physically forced to.
Encryption stops machines, not subpoenas or rubber hoses.

### 5. Social engineering
We cannot prevent a human attacker from convincing you to add
the wrong contact, share your screen, or install malware.
Verifying safety numbers in person is your defence here, not
the cryptography.

### 6. Metadata (at v0.1 — major Year 2 priority)

At launch, our server sees:

- WHO talks to WHOM
- WHEN messages are sent
- HOW OFTEN
- APPROXIMATE message size

Message *content* is encrypted; message *patterns* are not. For
most users this is acceptable; for journalists protecting sources
or activists in hostile environments, **this matters and we will
tell you so**. Sealed-sender style metadata protection is a Year 2
goal but is not yet shipped.

### 7. Cryptographic breakthroughs against NIST standards
If a future attack breaks ML-KEM, ChaCha20, or AES, we are
broken. We trust NIST's standardisation process. If we are
wrong, the entire industry is wrong.

*Mitigation:* our pluggable algorithm architecture allows rapid
rotation if a primitive is broken.

### 8. Tier 2 (sandbox / experimental) algorithms
These have NO security guarantees, ever. A user who opts into
using a community-contributed algorithm for a real conversation
is on their own. Sandbox algorithms exist for learning and
experimentation, never for protecting real secrets.

---

## Trust assumptions

For our security guarantees to hold, you must trust:

1. **Apple's iOS, Secure Enclave, and Keychain implementation.**
   We rely on Apple's hardware-backed key storage. If you do not
   trust Apple, you cannot meaningfully use this app.

2. **The signed binary you installed matches the source in this
   repo.** We provide signed releases. Source-level reproducibility
   (any contributor can rebuild from a tagged commit and verify
   the source matches) is committed from v0.1. Binary-reproducible
   builds on iOS are not feasible: Apple's App Store signing
   process embeds per-distribution data into every IPA. We accept
   this limitation as inherent to the iOS distribution model.

   For users requiring binary verification, we will additionally
   publish enterprise-distribution IPAs (signed with our own
   distribution certificate) for which third parties can verify
   binary-against-source.

3. **Your contact's device is similarly trustworthy.** End-to-end
   security requires trustworthy ends.

4. **You verify your contact's safety number out-of-band** before
   assuming MITM-resistance. In person or over a separately-
   authenticated channel (video call where you recognise their
   face). The app makes this easy but cannot do it for you.

5. **NIST's standardisation of ML-KEM-768, ML-DSA-65,
   AES-256-GCM, and ChaCha20-Poly1305.** We follow the
   standards. If the standards are flawed, we are flawed.

6. **The Security Council (once formed)** has the integrity to
   reject contributions that weaken the cryptographic core, and
   the technical competence to recognise such contributions.

---

## Cryptographic guarantees by version

This table commits to user-facing capability per **app release**.
Pre-v0.1 versions (`v0.0.x`) ship the cryptographic primitives
listed below incrementally as a Swift library (see
[README.md](README.md) "Status"); there is no installable app yet.
The first column reflects what we promise the moment a user can
install Aegis on a phone.

| Guarantee | v0.1 | v0.5 | v1.0 |
|---|:---:|:---:|:---:|
| End-to-end encryption (Tier 1) | YES | YES | YES |
| Post-quantum key encapsulation (ML-KEM-768 + X25519 hybrid) | YES | YES | YES |
| Authenticated encryption (AES-256-GCM) | YES | YES | YES |
| Identity signatures (ML-DSA-65) | YES | YES | YES |
| Forward secrecy | NO | YES (Double Ratchet) | YES |
| Post-compromise security | NO | YES | YES |
| Safety number *display* | YES | YES | YES |
| Safety number verification UI (QR scan) | NO (v0.2) | YES | YES |
| ChaCha20-Poly1305 alternative | NO (v0.3) | YES | YES |
| Group messaging (E2EE) | NO | NO | YES |
| Voice / video E2EE | NO | NO | NO (out of scope) |
| Disappearing messages | NO | NO | YES |
| Sealed sender / metadata protection | NO | NO | NO (v2.0) |
| First external audit complete | NO | NO | YES |

We will not ship a version claiming a guarantee until the table
above is updated and reflected in code.

---

## "Should I use this app?" — by user type

**Casual user, wants better-than-default privacy:**
Yes, from v1.0. Stronger than iMessage's defaults; not as polished.

**Privacy-conscious professional (lawyer, doctor, academic):**
Yes, from v1.0 if you accept the metadata limitation.

**Journalist communicating with non-sensitive sources:**
Yes, from v1.0.

**Journalist communicating with sources whose identity must be
protected from a state-level adversary:**
**No. Use Signal until at least v2.0** when sealed sender and
metadata protection ship and have been audited. Do not use this
app for life-or-liberty situations until then. We will tell you
this in the app's onboarding.

**Activist / dissident in a hostile state:**
**No, not yet.** Same reasoning. Signal is the right tool until
this project matures through multiple external audits.

**Someone testing and contributing to PQ cryptography research:**
Absolutely yes from v0.1. This is exactly who Tier 2 is for.

This honesty is itself a feature. Every other "secure" messenger
overstates its guarantees. We will not.

---

## In-app honesty: onboarding disclosure

The principle stated in this threat model is binding only if
users actually understand it. We commit to surfacing our
limitations inside the app, not just in this document.

### First-launch onboarding (mandatory, cannot be skipped)

A 3-screen flow shown the first time the app opens, before any
account is created. The user must tap through every screen. They
cannot start using the app without seeing them.

**Screen 1 — What we protect**
- "Your message content is encrypted end-to-end with post-quantum
  cryptography. Even our servers cannot read what you send."
- One-tap link: "How does this work?" → opens a plain-English
  explainer.

**Screen 2 — What we do NOT protect**
- "Our servers can still see WHO you talk to and WHEN. They
  cannot see WHAT you say, but the pattern of your conversations
  is visible."
- "We cannot protect you if your phone is compromised, if you are
  forced to unlock it, or if your contact's phone is compromised."
- One-tap link: "Read our full threat model" → opens this
  document inside the app.

**Screen 3 — Is this app right for you?**

A short self-assessment:

- "I want better privacy than iMessage / WhatsApp." → ✓ Use
  this app.
- "I am a journalist, lawyer, or professional handling
  confidential matters." → ✓ Use this app, with the metadata
  caveat in mind.
- "My personal safety, freedom, or life depends on no one
  knowing who I am communicating with." → ✗ **Do not rely on
  this app yet. Use Signal.** We will tell you when we are
  ready for your threat model — currently planned for v2.0.

This screen does NOT block use of the app. It informs honestly
and lets the user decide.

### Persistent reminders

- The "Settings → Security" screen always shows the current
  version's guarantees pulled from the version-by-version
  capability table in this document. If a feature has not yet
  shipped, it shows as "Not yet available" with a target version.
- The first time a user opens any conversation, a one-time banner
  appears at the top: "Your messages are encrypted. Tap here to
  verify your contact's safety number." This banner is dismissable
  but the safety-number-verification status is always visible as
  a small icon next to the contact's name.

### Tier 2 (sandbox) algorithm warnings

When a user attempts to switch a conversation to a Tier 2
(community-contributed, unaudited) algorithm:

1. A modal appears with a red warning header: **"Experimental
   Cryptography"**.
2. The text explains: "This algorithm has been contributed by the
   community for educational and research purposes. It has NOT
   been independently audited. Do not use this algorithm for
   conversations whose contents must remain secret."
3. The user must type the word "EXPERIMENTAL" (not just tap a
   checkbox) before the algorithm becomes selectable for that
   conversation.
4. A persistent badge appears next to the conversation in the
   conversations list: a yellow flask icon, with the tooltip
   "Sandbox cryptography — not audited."

These commitments are part of the threat model because the
guarantees of the cryptography are meaningless if users do not
understand them. Onboarding is a security primitive.

---

## Disclosure policy

- Vulnerability reports: `security@aegisproject.org` (domain
  registration pending — until live, see SECURITY.md for interim
  contact).
- PGP key published at well-known URL once generated.
- Acknowledgement within 72 hours.
- 90-day responsible disclosure timeline (negotiable for severe
  issues).
- All confirmed findings published in `audit-history.md` after
  fix is shipped.
- We will never silently patch. We will never ask you to delay
  publishing past 90 days unless we have a working fix and a
  documented reason.

---

## Backdoor stance

We will never knowingly insert a backdoor. We will never accept
a contribution that weakens the cryptographic guarantees for any
party. If we are legally compelled to do so, we will publish
notice (warrant canary), shut the project down, or transfer it to
a jurisdiction that does not compel such modifications —
whichever preserves user safety. The mission is the floor, not
the ceiling.
