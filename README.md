# London Hotel Group — Property Information Hub

One accurate record for every property in the London portfolio: unit counts,
lifts, staircases, accessibility, documents — each figure verified by the
property manager on the ground and signed off by corporate.

```
backend/   Laravel 13 API + MySQL 8 schema
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

## Running it locally

### Backend

```bash
cd backend
composer install
cp .env.example .env          # or keep the bundled SQLite .env for a quick start
php artisan key:generate
php artisan migrate --seed
php artisan serve             # http://localhost:8000
```

The seeder creates the seven demo properties and these accounts, all with the
password `password`:

| Email | Role |
| --- | --- |
| `priya.raman@londonhotelgroup.co.uk` | Corporate Administrator |
| `jane.smith@londonhotelgroup.co.uk` | Property Manager (Croydon Housing) |
| `meher.n@londonhotelgroup.co.uk` | Leadership (read-only) |

Change or remove these before the app touches real data.

```bash
vendor/bin/phpunit    # 72 tests
vendor/bin/pint       # code style
```

### iOS

```bash
cd ios
open LondonPropertyHub.xcodeproj
```

Pick the **London Property Hub** scheme and run. The Debug configuration points
at `http://localhost:8000`; a physical device needs your Mac's LAN address
instead — change `API_BASE_URL` in `Config/Debug.xcconfig`.

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

**Editing is optimistic and debounced.** A field updates on screen straight
away, the request follows ~600 ms later, and a rejected change is rolled back
with the server's reason shown under the field. Nothing is lost silently.
