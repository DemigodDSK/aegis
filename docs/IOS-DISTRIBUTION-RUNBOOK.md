# iOS distribution runbook (Phase B)

How to get an Aegis IPA from a working `Aegis.xcodeproj`
into TestFlight — Apple Developer Program enrolment,
App Store Connect record, signing certificate, provisioning
profile, archive, upload.

This is the runbook you follow when you're ready to spend
~$99 (Apple Developer Program annual fee) and ~30 minutes
of clicking through App Store Connect. None of these steps
require Aegis source-code changes; everything below is one-
time setup that lives in your Apple Developer account, not
in the repo.

The Sprint 7 tag (`v0.0.8-sprint-7`) is held until "First
TestFlight build pushed to internal testers" lands at the
bottom of this runbook.

---

## Prerequisites

| Item | Where it comes from |
|---|---|
| **Apple ID** | The same Apple ID you use for the App Store on your iPhone is fine. |
| **Apple Developer Program enrolment** | $99/yr at [developer.apple.com/programs](https://developer.apple.com/programs/). Approval typically same-day for individual accounts. |
| **Two-factor authentication enabled** on the Apple ID | Required by Apple for Developer Program enrolment. |
| **Phase A complete** | `Aegis.xcodeproj` builds and runs on iOS Simulator + your physical iPhone via personal-team signing. See [IOS-RUNBOOK.md](IOS-RUNBOOK.md). |

---

## Step 1 — Enrol in the Apple Developer Program

1. Visit [developer.apple.com/programs](https://developer.apple.com/programs/).
2. Click **Enroll**.
3. Sign in with your Apple ID. Apple may ask you to enable
   2FA on this Apple ID if it isn't already.
4. **Entity type**: choose "Individual / Sole Proprietor"
   unless Aegis becomes a registered company. Individual is
   fine for v0.x.
5. Pay the $99 USD annual fee.
6. Approval is usually same-day. You'll get an email when
   your account is active.

Once approved, you can sign in to
[appstoreconnect.apple.com](https://appstoreconnect.apple.com/)
with the same Apple ID.

---

## Step 2 — Create the App Store Connect record

1. Sign in to [App Store Connect](https://appstoreconnect.apple.com/).
2. Click **My Apps → +** (top-left) → **New App**.
3. Fill out:

   | Field | Value |
   |---|---|
   | Platforms | iOS |
   | Name | `Aegis` |
   | Primary Language | English (UK) or English (US) |
   | Bundle ID | `io.github.demigoddsk.Aegis` — must match the iOS app target's `PRODUCT_BUNDLE_IDENTIFIER`. If Apple says the ID is unavailable, register it first under **Certificates, Identifiers & Profiles → Identifiers**. |
   | SKU | `aegis` (any string, just for your records) |
   | User Access | Full Access |

4. Click **Create**.

You don't need to fill out App Store metadata
(screenshots, description, privacy nutrition labels) yet —
that's the v0.1.0 alpha sprint. For Sprint 7 the goal is a
TestFlight build, which doesn't require App Store
metadata.

---

## Step 3 — Configure signing in Xcode

1. Open `Aegis.xcodeproj`.
2. In the project navigator, select the `Aegis` target →
   **Signing & Capabilities**.
3. Set **Team** to your newly-enrolled Apple Developer
   Program team.
4. Tick **Automatically manage signing** if it isn't
   already.
5. Bundle Identifier should already be
   `io.github.demigoddsk.Aegis`; if Xcode complains, the
   bundle ID may not have been registered yet — visit
   [developer.apple.com/account/resources/identifiers/list](https://developer.apple.com/account/resources/identifiers/list)
   and register it as an App ID with the matching prefix.

Xcode will create a development signing certificate and a
development provisioning profile automatically the first
time you build for a real device or archive.

---

## Step 4 — Push notifications (provisioned for Sprint 9)

The entitlements file already declares `aps-environment:
development`. Nothing to change in the project.

When the App Store Connect record exists:

1. Visit [Certificates, Identifiers & Profiles →
   Identifiers](https://developer.apple.com/account/resources/identifiers/list).
2. Pick the `io.github.demigoddsk.Aegis` App ID.
3. Tick **Push Notifications** → Configure → create both a
   Development APNs Key and a Production APNs Key. Download
   the .p8 files.
4. **Do NOT commit the .p8 files** — they're listed in
   `.gitignore`. Store them outside the repo (suggested:
   `~/Documents/aegis-keys-backup-DO-NOT-COMMIT/`).

This sets up the keys Sprint 9 will consume. Phase B
itself doesn't need to wire up the consumer.

---

## Step 5 — Archive + upload to App Store Connect

1. In the Xcode toolbar destination picker, select **Any
   iOS Device (arm64)**.
2. Menu: **Product → Archive**.
3. Xcode builds a Release configuration archive. Takes a
   minute or two.
4. The Organizer window opens with the new archive
   highlighted.
5. Click **Distribute App** → **App Store Connect** →
   **Upload**.
6. Xcode signs the archive with your Distribution
   certificate and uploads. Apple's processing on their
   side takes 5-15 minutes.

Once processed, the build appears under your app in App
Store Connect → **TestFlight → iOS Builds**.

---

## Step 6 — TestFlight: internal testers

1. App Store Connect → your `Aegis` app → **TestFlight →
   Test Information**.
2. Fill out:
   - **Test Information**: brief description ("Pre-1.0
     post-quantum messenger; demo only — see project
     README and THREAT-MODEL.md").
   - **Email**: your `dsk7699@gmail.com` (or whatever
     you'd want testers to contact).
   - **Privacy Policy URL**: GitHub link to a
     `PRIVACY.md` file. (TODO: create
     `PRIVACY.md` — short, mostly "we collect nothing".)
3. **TestFlight → Internal Testing → Add Group → "Maintainer"**
   → add your Apple ID as a tester.
4. Pick the build → **Add to Group**.
5. Apple does a brief review of the build for crash issues
   (~10 minutes). When it's available, you'll get a
   TestFlight notification on your iPhone.
6. Open TestFlight on your iPhone → Aegis → Install.

---

## Step 7 — First-install smoke-test on the production-signed
build

Run through the same flow as Phase A but on the
production-signed TestFlight build:

| Stage | Expected |
|---|---|
| Launch | Onboarding screen 1 |
| Onboarding | All three screens, no skip, "Use Signal instead" framing on screen 3 |
| Identity setup | Display name input, "Generate identity" button works, persists across kill+relaunch |
| Demo | Encrypt → ciphertext envelope card; Decrypt → recovered plaintext; wrong-passphrase decrypt → AEAD-auth-failure error card |
| Settings | About card with v0.0.8 version + maintainer + PGP fingerprint; Security section with 14 capability rows; tap-to-expand works |

Once that smoke-test passes — congratulations. The Sprint
7 deliverables are met. Cut the tag:

```bash
cd ~/Documents/aegis
git tag -a v0.0.8-sprint-7 -m "Aegis v0.0.8 — Sprint 7: iOS distribution"
git push origin v0.0.8-sprint-7
```

---

## What this runbook does NOT cover

- **Wider TestFlight distribution to external testers** —
  that's Sprint 10 (the v0.1.0 alpha). External-tester
  groups require Apple's "Beta App Review", which has
  additional metadata requirements.
- **App Store submission** — Aegis is not going on the
  App Store for any v0.x release. The first App Store
  submission is targeted at v1.0, post-external-audit.
- **Push notification consumer wiring** — Sprint 9
  (networking) consumes the `aps-environment` entitlement
  this runbook provisioned.
- **App Icon redesign / privacy-nutrition labels /
  screenshots** — pre-1.0 polish work, slotted as needed.

---

## Why this is its own runbook

iOS distribution is genuinely separate from iOS
development. Phase A
([IOS-RUNBOOK.md](IOS-RUNBOOK.md)) needs no Apple Developer
account and no money; you can run Aegis on a connected
iPhone today using a free Apple ID. Phase B (this runbook)
is what gets you to TestFlight.

The split mirrors the reality that the SwiftUI surface and
the IPA pipeline are different concerns. Per the Sprint
6→7 split documented in `docs/STAGES.md`, this runbook is
why Sprint 7 is its own sprint.
