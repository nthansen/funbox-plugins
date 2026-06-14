# Documentation audience rules — funbox project overlay

> doc-sweep **overlay** — layered on the invariant base (`audience-rules-base.md`); lists
> only this project's differences. The base still applies in full.

## Added file types

| File | Audience | Scope | Contents |
|---|---|---|---|
| `CHANGELOG.md` | Humans only | Team-shared, checked into git | One per plugin under `plugins/<name>/`. |

## Contents refinements

- `README.md` lives at the repo root **and** one per plugin (`plugins/<name>/README.md`); only
  the root has a `CLAUDE.md`.

## Shell + path conventions

funbox is cross-platform: committed `*.sh` **and** `*.ps1` are both first-class shared scripts —
do **not** push PowerShell content to a `.local.md` twin. Only machine-specific *paths* go local.
(The EOL/CRLF and versioning rationale lives in `CLAUDE.md`, not here.)
