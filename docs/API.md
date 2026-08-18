# API reference

Base URL: `{APP_URL}/api`
Auth: `Authorization: Bearer <token>` on everything except `POST /auth/login`.

Responses are unwrapped JSON — a resource is the object itself, a collection is
a bare array. Errors follow Laravel's shape:

```json
{ "message": "Some details need correcting.", "errors": { "values.postcode": ["…"] } }
```

| Status | Meaning |
| --- | --- |
| 401 | Token missing, expired or revoked — sign in again |
| 403 | Authenticated, but the role or ownership rule forbids it |
| 422 | Validation failed; `errors` is keyed by field path |
| 429 | Rate limited (login attempts) |

---

## Session

| Method | Path | Notes |
| --- | --- | --- |
| POST | `/auth/login` | `{email, password, deviceName}` → `{token, expiresAt, user}`. Throttled: 5 failures per email+IP per 5 min |
| POST | `/auth/logout` | Revokes only the calling token |
| GET | `/auth/me` | The signed-in user |
| PUT | `/auth/password` | Changing a password revokes every other device |

## Cold start

| Method | Path | Notes |
| --- | --- | --- |
| GET | `/bootstrap` | User, field registry, dropdown lists, accommodation model, report columns — everything needed before rendering |
| GET | `/dashboard` | Aggregates over the filtered, role-scoped set |

## Properties

| Method | Path | Notes |
| --- | --- | --- |
| GET | `/properties` | Filters: `q`, `borough`, `council`, `region`, `propertyType`, `verification` |
| POST | `/properties` | Admin only |
| GET | `/properties/{id}` | Full record: values, accommodation, lifts, stairs, documents, history, flags |
| PATCH | `/properties/{id}` | `{values: {fieldKey: value}, reason?}` — send only what changed |
| DELETE | `/properties/{id}` | Soft delete, admin only |
| PATCH | `/properties/{id}/accommodation` | `{accommodation: {key: count}}`; response `flags` carries any large-change flags raised |

### Field value shapes

| Field type | JSON |
| --- | --- |
| text, email, postcode, select | `"Croydon"` |
| number, decimal | `7` / `12.5` |
| date | `"2026-04-11"` |
| yesno | `"Yes"` \| `"No"` \| `"N/A"` |
| measurement | `{"v": 12.6, "u": "m²"}` |
| *(unset)* | `null` |

## Verification workflow

| Method | Path | Who |
| --- | --- | --- |
| POST | `/properties/{id}/submit` | Manager or admin. 422 with `missing[]` if required fields are blank |
| POST | `/properties/{id}/approve` | Admin. Also approves every pending audit row |
| POST | `/properties/{id}/request-changes` | Admin |
| POST | `/properties/{id}/request-verification` | Admin. Starts a fresh round |

## Sub-records

| Method | Path |
| --- | --- |
| POST / PATCH / DELETE | `/properties/{id}/elevators[/{elevatorId}]` |
| POST / PATCH / DELETE | `/properties/{id}/staircases[/{staircaseId}]` |
| POST / DELETE | `/properties/{id}/documents[/{documentId}]` (multipart: `file`, `type`, `notes`) |
| GET | `/documents/{id}/download` |
| POST | `/properties/{id}/flags/{flagId}/resolve` — `{action: "confirm"\|"revert"}` |

## Reports

| Method | Path | Notes |
| --- | --- | --- |
| GET | `/reports` | `columns=Site,Borough,…`; returns rows plus the company-total row |
| GET | `/reports/export/{csv\|xlsx\|pdf}` | Binary. `scope=all` ignores filters and exports everything visible. `X-Filename` header carries the filename |

## Admin (corporate administrator only)

| Method | Path |
| --- | --- |
| GET | `/import/sample` — a demo legacy spreadsheet |
| POST | `/import/preview` — multipart `file`; parses and auto-maps, writes nothing |
| POST | `/import/remap` — re-preview after correcting the mapping |
| POST | `/import/commit` — creates the importable rows |
| GET / POST / DELETE | `/field-definitions[/{id}]` |
| GET / POST / DELETE | `/option-lists[/{listKey}[/{value}]]` |

---

## Role rules

|  | Admin | Manager | Leadership |
| --- | --- | --- | --- |
| See every property | ✓ | own only | ✓ |
| Edit a property | ✓ | own, until submitted | — |
| Submit for review | ✓ | own | — |
| Approve / request changes | ✓ | — | — |
| Create / delete properties | ✓ | — | — |
| Import spreadsheets | ✓ | — | — |
| Add custom fields | ✓ | — | — |
| Export | ✓ | own only | ✓ |

These are enforced by `PropertyPolicy` and the `role:` middleware on the server.
The iOS app hides what a role cannot do, but hiding is not the control.
