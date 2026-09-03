# London Hotel Group — Property Information Hub

One accurate record for every property in the London portfolio: unit counts,
lifts, staircases, accessibility, documents — each figure verified by the
property manager on the ground and signed off by corporate.

```
backend/   Laravel 13 API (MySQL 8 in production, SQLite locally)
ios/       SwiftUI app (iOS 17+), the primary client
web/       The original React prototype, kept as a reference client
docs/      Launch guide and API reference
```

## What it does

**Three roles, enforced server-side.**
Corporate administrators do everything. Property managers see and edit only the
properties they are named on, and their record locks the moment they submit it
for review. Leadership reads the whole portfolio and writes nothing.

**A verification round.**
Corporate requests verification → the manager fills the record in → they submit
→ corporate approves or sends it back with a comment. Every state change is
recorded.

**An audit trail that is not optional.**
Every edit writes who changed what, from what, to what, and why. Approving a
record approves the edits behind it.

**Large-change detection.**
A unit count that moves by 10+ *and* by half or more of its previous value is
flagged for the manager to confirm or revert before anyone trusts it. Growth
from zero is never flagged — that is data entry, not a suspicious correction.

**Fields the business can add itself.**
Corporate adds a field in the app; it appears on every property immediately,
validated and audited like any built-in field, with no rebuild and no release.

**Legacy spreadsheet import.**
Upload an Excel or CSV file, the columns are matched to fields automatically,
you correct anything wrong, and you see exactly what will be created —
duplicates and all — before a single row is written.

**Exports that match the screen.**
CSV, Excel and PDF, containing exactly the columns and filters you are looking
at, plus the company-total row.

## Trying it without a server

The iOS app ships with a demo account. Sign in with one of these and nothing
leaves the device — no API, no database, no network at all — but every screen
works against a full sample portfolio held in memory.

| Email | What you get |
| --- | --- |
| `demo@londonhotelgroup.co.uk` | Corporate Administrator — approvals, import, custom fields |
| `demo.manager@londonhotelgroup.co.uk` | Property Manager — three properties, locked once submitted |
| `demo.leadership@londonhotelgroup.co.uk` | Leadership — the whole portfolio, read-only |

Any password is accepted, and the sign-in screen has a one-tap button for each
role. The seven seeded properties, their lifts, stairs, documents and audit
history are the same ones the server seeder creates, so the two tell the same
story.

The demo is not a set of screenshots. It enforces the real rules — role scoping,
the lock on a submitted record, the audit trail, large-change flags, field
validation — and anything the API would refuse, the demo refuses too, in the
same words. Exports are real files: a working CSV, a real `.xlsx` workbook and a
rendered PDF all come out of the reports screen.

The one thing the demo does less of than the API is read Excel binaries. Import
parses the file you pick as long as it is a CSV, which is what the sample file
on the import screen gives you, so download it and upload it back to run the
mapping, the duplicate check and the commit for real. An `.xlsx` is turned away
with a message saying so rather than a canned result.

Everything you change lives in memory for that session. **Reset demo data** in
the account sheet, signing out, or relaunching the app puts it all back.

Demo sign-ins work in every build, including Release, so an App Store reviewer
can get in. To keep them out of production, set `isEnabled` in
`ios/LondonPropertyHub/Demo/DemoAccount.swift` to `!APIConfiguration.isProduction`.

## Running it locally

Everything runs on your Mac against a SQLite file — no MySQL, no cloud
services, no network beyond localhost.

### One command

```bash
scripts/local-api.sh          # http://localhost:8000
```

It installs Composer dependencies, creates the database and seeds it if that
has not happened yet, then serves. Leave it running, open the Xcode project and
hit Run — the Debug configuration already points the simulator at
`http://localhost:8000`, and `Info.plist` exempts localhost from App Transport
Security so plain HTTP is allowed there and nowhere else.

Add `--fresh` to throw the database away and re-seed it. Everything the script
writes is gitignored, so that is always safe.

```bash
scripts/local-api.sh --fresh
```

### Prerequisites

PHP 8.3+ with `pdo_sqlite`, `gd` and `zip`, plus Composer. If you have neither:

```bash
/bin/bash -c "$(curl -fsSL https://php.new/install/mac/8.4)"
```

That puts `php` and `composer` in `~/.config/herd-lite/bin` and adds it to your
PATH — open a new terminal afterwards. Homebrew works equally well if you
already use it.

### Server accounts

The seeder creates seven properties and eight accounts, all with the password
`password`. These are real accounts on your local API — separate from the
on-device demo above, which needs no server:

| Email | Role |
| --- | --- |
| `priya.raman@londonhotelgroup.co.uk` | Corporate Administrator |
| `jane.smith@londonhotelgroup.co.uk` | Property Manager (Croydon Housing) |
| `meher.n@londonhotelgroup.co.uk` | Leadership (read-only) |

Change or remove these before the app touches real data:

```bash
php artisan hub:create-admin              # a real account, password prompted
php artisan hub:disable-demo-accounts     # closes the seeded ones
```

### Doing it by hand

```bash
cd backend
composer install
cp .env.example .env          # then set DB_CONNECTION=sqlite
php artisan key:generate
php artisan migrate --seed
php artisan serve             # http://localhost:8000

vendor/bin/phpunit            # 75 tests
vendor/bin/pint               # code style
```

### iOS

```bash
cd ios
open LondonPropertyHub.xcodeproj
```

Pick the **London Property Hub** scheme and run. The sign-in screen shows
`Connected to Local · localhost` when it is pointed at your machine — or sign in
with a demo account and skip the API entirely. A physical
device cannot reach your Mac on localhost — change `API_BASE_URL` in
`Config/Debug.xcconfig` to your Mac's LAN address, e.g. `http://192.168.1.20:8000`.

### Web (reference prototype)

```bash
cd web
npm install
npm run dev                   # http://localhost:5173
```

The web app is the original self-contained prototype with in-memory state. It
is kept as a design reference; the iOS app is the client that talks to the API.

## Shipping to the App Store

See **[docs/LAUNCH.md](docs/LAUNCH.md)** — it is the short list of things only
you can do (bundle ID, team, App Store Connect record), then two commands.

## Architecture notes

**The field registry is the single source of truth.** `FieldRegistry` on the
server describes all 50 base fields once; validation, the importer, the export
columns and the iOS form rendering all read from it. Adding a field means
touching one list, not five.

**Base fields are columns, custom fields are rows.** The 50 known fields have
real columns on `properties`, so filtering and aggregation stay fast. Fields
added after launch live in `property_field_values`, which is why the business
can extend the record without a migration.

**The demo is the same app, not a mock of it.** `PropertyAPI` is the only thing
that knows about demo mode: it routes to `DemoBackend`, an actor holding the
portfolio in memory, and every screen, store and model above it is unchanged.
`Demo/DemoRegistry.swift` mirrors `FieldRegistry` and friends, and the rules —
`PropertyPolicy`, `PropertyWriter`, `ReportBuilder`, `UpdatePropertyRequest` —
are reproduced next to a note saying which server class each one answers to.

**Editing is optimistic and debounced.** A field updates on screen straight
away, the request follows ~600 ms later, and a rejected change is rolled back
with the server's reason shown under the field. Nothing is lost silently.
