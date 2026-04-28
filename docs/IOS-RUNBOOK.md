# iOS smoke-test runbook (Phase A)

How to open `Aegis.xcodeproj` in Xcode and run the app on
the iOS Simulator or a connected iPhone — without an Apple
Developer Program enrolment, without TestFlight, without
any paid signing.

This is the runbook you follow today. The Phase B runbook
([IOS-DISTRIBUTION-RUNBOOK.md](IOS-DISTRIBUTION-RUNBOOK.md))
covers the App Store Connect / TestFlight side once you've
enrolled in the Apple Developer Program.

---

## Prerequisites

| Tool | Where to get it |
|---|---|
| **macOS 26+** | already installed (the SwiftPM target floor matches) |
| **Xcode 26+** | App Store, or [developer.apple.com/xcode](https://developer.apple.com/xcode/) |
| **iOS 26.4 SDK** | inside Xcode: `Xcode → Settings → Components → iOS 26.4 → Get`. Several-GB download, one-time. |
| **xcodegen** (optional) | `brew install xcodegen` — only needed if you edit `project.yml` and want to regenerate `Aegis.xcodeproj` |
| **Apple ID** (any) | a free personal Apple ID is enough for installing on your own iPhone via Xcode |

To verify Xcode and the iOS SDK are ready:

```bash
xcrun --sdk iphoneos --show-sdk-version
# → should print 26.x
```

If that errors with "iOS 26.x is not installed", open Xcode →
Settings → Components and download the iOS platform.

---

## Open the project

```bash
cd ~/Documents/aegis
open Aegis.xcodeproj
```

Xcode resolves the local `Aegis` SwiftPM package (the one
defined by `Package.swift` at the repo root) and pulls
`AegisCrypto`, `AegisStorage`, `AegisApp` as dependencies of
the iOS app target. First open takes ~30 seconds while the
package graph resolves; subsequent opens are instant.

---

## Run on the iOS Simulator

1. In the Xcode toolbar, pick the **Aegis** scheme.
2. Pick a destination — any **iOS Simulator** model running
   iOS 26.4 (e.g. "iPhone 17 Pro").
3. Hit **▶︎ Run** (`Cmd+R`).

What you should see:

| Stage | What appears |
|---|---|
| Launch | Charcoal background, blue shield glyph, **Onboarding** title |
| Onboarding 1 | "What we protect" + "How does this work?" link → Continue |
| Onboarding 2 | "What we do NOT protect" + "Read our full threat model" link → Continue |
| Onboarding 3 | "Is Aegis right for you?" with three assessment rows including "Use Signal instead" for life-or-liberty threats → Begin |
| Identity setup | "Pick a display name" — type something, tap **Generate identity** |
| Main → Demo tab | Type a message + a passphrase, tap **Encrypt**, see the AES-256-GCM envelope (methodId, nonce, ciphertext, tag in monospaced base64), tap **Decrypt**, see the plaintext recovered |
| Main → Settings tab | About card (version, maintainer, GitHub link, PGP fingerprint) + Security section with 14 expandable capability rows |

Force-quit and relaunch — the identity persists in the
simulated Keychain, the onboarding flag persists in
UserDefaults, and you land directly on the main app.

---

## Run on your physical iPhone (free Apple ID)

You can install Aegis on your own iPhone right now without
spending a cent on the Apple Developer Program. The signing
limitation: the build is valid for 7 days, after which you
re-run `Cmd+R` from Xcode while connected.

1. Connect your iPhone via USB. Unlock it. Trust this Mac if
   prompted.
2. In Xcode → Settings → Accounts, sign in with any Apple
   ID. The personal team appears as "*Your Name* (Personal
   Team)".
3. In the project navigator, select the `Aegis` target →
   **Signing & Capabilities**:
   - Tick "Automatically manage signing"
   - Team: your personal team
   - Bundle Identifier: change to something unique to your
     team if Xcode complains about a duplicate (e.g.
     `io.github.demigoddsk.Aegis.dev`)
4. In the toolbar destination picker, choose your iPhone.
5. Hit **▶︎ Run**.

First run on a physical device will prompt you to "Trust"
the developer certificate on the iPhone:

  *Settings → General → VPN & Device Management →
   Developer App → trust the certificate matching your
   Apple ID*.

After trusting, the app launches and persists like the
simulator run.

---

## If something doesn't work

| Symptom | Likely cause | Fix |
|---|---|---|
| `xcodebuild: error: iOS 26.x is not installed` | iOS SDK not downloaded | Xcode → Settings → Components → iOS 26.4 → Get |
| `DVTPlugInLoading` errors / "plugin failed to load" | Xcode framework cache stale after Xcode update | `xcodebuild -runFirstLaunch` |
| `IXErrorDomain Code 13 / "Missing bundle ID"` at simulator install time, even though `CFBundleIdentifier` is set in Info.plist | Asset catalog wasn't compiled (so `actool` didn't produce `Assets.car` and the `AppIcon` variants), OR the Xcode-16+ Debug Dylib feature is producing a shim+sidecar bundle layout that the iOS-26 install service rejects | Already fixed in `project.yml` at commit 90b55ae: (a) `iOS/Resources` is a *group* not a `type: folder`, (b) `ENABLE_DEBUG_DYLIB: NO`, (c) `LSRequiresIPhoneOS: true`. If you hit this on a fork, regenerate via `xcodegen` and rebuild after a Clean Build Folder. |
| "Failed to register bundle identifier" | bundle id collides with another app on this signing identity | edit `Aegis.target.PRODUCT_BUNDLE_IDENTIFIER` in `project.yml` (e.g. add `.dev`), run `xcodegen`, retry |
| Identity / onboarding state survives across re-installs | Keychain entries are scoped to the team-prefixed access group; reinstalling the same app preserves them | use **Settings → Reset everything** (Sprint-7 polish item) or `swift run aegis-demo`'s `state.resetEverything()` API |

---

## After you change `project.yml`

```bash
cd ~/Documents/aegis
xcodegen
```

Re-runs the generator. Re-open `Aegis.xcodeproj` in Xcode
(or pick *File → Revert* if it's already open).

Both `project.yml` AND the generated `Aegis.xcodeproj/` are
committed in this repo; if you're a contributor without
xcodegen installed, you can still open the project directly
from the committed `.xcodeproj`. Edits made directly in
Xcode (e.g. via the GUI's Build Settings tab) will diverge
from `project.yml` — prefer mirroring the change back into
the spec and re-running xcodegen rather than committing
.pbxproj diffs.

---

## What this runbook does NOT cover

- Apple Developer Program enrolment, App Store Connect,
  certificates, provisioning profiles, TestFlight push —
  those live in
  [IOS-DISTRIBUTION-RUNBOOK.md](IOS-DISTRIBUTION-RUNBOOK.md).
- Push notifications consumer wiring — Sprint 9 territory.
- App Icon redesign — the current icon is a procedurally-
  generated charcoal-and-blue shield placeholder. Replace it
  by overwriting
  `iOS/Resources/Assets.xcassets/AppIcon.appiconset/AppIcon-1024.png`
  with any 1024×1024 PNG.
