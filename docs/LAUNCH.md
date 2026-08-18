# Getting the app into the App Store

The build is set up so releasing is two commands. Everything below the first
section is a one-off you do once and never again.

---

## Part 1 — The things only you can do

These need your Apple account and cannot be scripted in advance.

### 1. Pick a bundle identifier

`uk.co.londonhotelgroup.propertyhub` is the placeholder. If your organisation
owns a different domain, change it in **one place**:

```
ios/Config/Shared.xcconfig  →  PRODUCT_BUNDLE_IDENTIFIER
ios/fastlane/Appfile        →  app_identifier
```

### 2. Set your team

In `ios/Config/Shared.xcconfig`, set `DEVELOPMENT_TEAM` to your ten-character
Apple Developer team ID. You'll find it at
[developer.apple.com/account](https://developer.apple.com/account) → Membership.

Alternatively, open the project in Xcode, select the target → Signing &
Capabilities, and pick your team from the dropdown — Xcode writes the value for
you.

### 3. Create the App Store Connect record

At [appstoreconnect.apple.com](https://appstoreconnect.apple.com) → My Apps → **+**:

| Field | Value |
| --- | --- |
| Platform | iOS |
| Name | London Property Hub |
| Primary language | English (U.K.) |
| Bundle ID | the one from step 1 |
| SKU | `lhg-property-hub` |
| User access | Full Access |

### 4. Create an API key (skip if you'd rather sign in interactively)

App Store Connect → Users and Access → Integrations → App Store Connect API →
**+**. Give it the **App Manager** role, download the `.p8` (you get one
chance), and put it in `ios/fastlane/`.

Then copy `ios/fastlane/.env.example` to `ios/fastlane/.env` and fill in
`ASC_KEY_ID`, `ASC_ISSUER_ID` and `ASC_KEY_PATH`. The `.gitignore` already
excludes both the `.env` and the key file.

### 5. Point the app at your production API

`ios/Config/Release.xcconfig` → `API_BASE_URL`. It must be **HTTPS** and
reachable from the public internet — App Review will hit it from Apple's
network, and the app ships with no App Transport Security exception for it.

Deploy the backend first: see [`backend/deploy/README.md`](../backend/deploy/README.md).

---

## Part 2 — Releasing

```bash
cd ios
bundle install          # once, installs fastlane
bundle exec fastlane beta
```

That archives a Release build, sets the build number from the commit count,
uploads to TestFlight, and writes a changelog from your recent commits.

When you're ready for the public App Store:

```bash
bundle exec fastlane release
```

This does the same build and submits it for review, with the compliance answers
already filled in (no IDFA, no encryption beyond HTTPS, no third-party content —
all true for this app).

### Without fastlane

Xcode → **Product → Archive** → Distribute App → App Store Connect → Upload.
The scheme is already shared, so this works from a fresh clone.

---

## Part 3 — What App Review will ask for

**A demo account.** Review needs to get past the sign-in screen. In App Store
Connect → your app → App Review Information, provide:

- a real account on your production API (create one; do not use a seeded demo
  password)
- a note: *"Corporate Administrator role — full access to all screens."*

**Privacy details.** App Store Connect → App Privacy. The honest answers for
this app:

| Question | Answer |
| --- | --- |
| Does the app collect data? | Yes |
| What kind? | Contact Info (name, email) and User Content (property records) |
| Linked to identity? | Yes — records are attributed to the user who made them |
| Used for tracking? | **No** |
| Used for advertising? | **No** |

**Encryption.** `ITSAppUsesNonExemptEncryption` is already `false` in
`Info.plist`. The app uses HTTPS only, which is exempt.

**A privacy policy URL.** Required for any app that collects data, even an
internal one. Host it anywhere public.

### Likely review notes, and the honest answers

> *"This looks like it's for a specific business."*

It is. Apple's guideline 4.2.7 covers enterprise-style apps distributed
publicly — provide the demo account and explain it's a staff tool for London
Hotel Group. If you would rather not list it publicly at all, use **Apple
Business Manager custom app distribution** instead of the public store; the
build is identical, only the distribution channel changes.

> *"The app requires a login with no way to sign up."*

Correct, and expected for a staff tool. The sign-in screen says so: *"Access is
managed by your corporate administrator."* Provide the demo credentials and
this passes.

---

## Version numbers

`MARKETING_VERSION` in `Config/Shared.xcconfig` is the version people see —
bump it by hand for each release (`1.0.0` → `1.1.0`).

`CURRENT_PROJECT_VERSION` is the build number and is set automatically by
fastlane from the commit count, so it always increases and you never have to
think about it.

---

## Troubleshooting

**"No profiles for 'uk.co...' were found"**
`DEVELOPMENT_TEAM` is unset, or the bundle ID doesn't exist in your account yet.
Open the project in Xcode, pick your team under Signing & Capabilities, and let
it register the identifier.

**"Invalid Bundle. Missing Info.plist key"**
Usually a missing app icon. `Assets.xcassets/AppIcon.appiconset` ships with a
1024×1024 PNG already — if you replace it, keep it 1024×1024 with **no alpha
channel** or the upload is rejected.

**The app shows "No connection" on a device but works in the simulator**
`API_BASE_URL` in `Debug.xcconfig` is `localhost`, which on a phone means the
phone itself. Use your Mac's LAN address (`ipconfig getifaddr en0`).

**TestFlight build never appears**
Processing takes 5–30 minutes. If it fails, the reason arrives by email —
usually a missing privacy declaration or an invalid icon.
