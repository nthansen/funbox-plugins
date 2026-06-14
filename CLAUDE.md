# CLAUDE.md — funbox-plugins

**funbox** is a Claude Code **plugin marketplace**. Repo name `funbox-plugins`; marketplace
name is `funbox` (the `name` in `.claude-plugin/marketplace.json`). Each plugin is
self-contained under `plugins/`.

## Layout

- `.claude-plugin/marketplace.json` — the catalog. Each entry: `{ name, source: "./plugins/<name>", description }`.
- `plugins/<name>/.claude-plugin/plugin.json` — plugin manifest; `name` must match the directory **and** the catalog entry.
- `plugins/<name>/{README.md,CHANGELOG.md}` — required for every plugin.
- `plugins/<name>/skills/<skill>/SKILL.md` — skills; frontmatter `name` must match the skill directory.
- `scripts/validate-marketplace.mjs` — the validator; `.github/workflows/validate.yml` runs it in CI.

## Versioning — read before touching a version

- Plugins **omit `version`** in `plugin.json` on purpose → `main` is a rolling channel (every
  commit is a new version, resolved by commit SHA). Adding a `version` **pins** the plugin
  (consumers stop auto-updating until it's bumped). Only add one to cut a stable, pinnable release.
- No tags or releases — distribution is the git repo + `marketplace.json`, resolved by commit
  SHA (the same model as the official marketplace). Each plugin's `CHANGELOG.md` points at its
  commit history rather than enumerating versions.

## Validation (CI gate — keep it green)

- Run `node scripts/validate-marketplace.mjs` before committing. Optional local hook:
  `git config core.hooksPath .githooks`.
- It enforces: marketplace/plugin structure; **required README + CHANGELOG per plugin**;
  SKILL.md frontmatter; **`allowed-tools` must be scoped** (no bare or wildcard
  `Bash`/`PowerShell`); cross-marketplace deps must be allowlisted; a danger-pattern scan.
- CI additionally runs `bash -n`, ShellCheck, PowerShell parse, and gitleaks.

## Local testing

- `make install-local` points the **funbox** marketplace at this working clone (via
  `claude plugin marketplace add "$(CURDIR)"`) and installs both plugins; `make install-remote`
  switches the source back to the GitHub repo; `make remove` tears it down.
- Gotcha: the local clone and the GitHub repo both resolve to the same marketplace name
  `funbox`, so they can't be added at once — each `make` target removes the marketplace before
  re-adding it. After edits, `/reload-plugins` (or reload the VS Code window).

## Dependencies

A plugin depending on another marketplace (e.g. `doc-sweep` →
`claude-md-management@claude-plugins-official`) needs **both** the `dependencies` entry in its
`plugin.json` **and** the target marketplace listed in `allowCrossMarketplaceDependenciesOn`
in `marketplace.json`. The validator rejects an un-allowlisted cross-marketplace dependency.

## Script gotchas

- `*.sh`, `.githooks/*`, and the `Makefile` must stay **LF** (`.gitattributes`) or they break
  on Linux/macOS (CRLF appends a stray `\r` to each Makefile recipe command).
- The version-sort `printf $_v` in the patch scripts is an **intentional** word-split;
  `SC2086` is disabled there on purpose — do not "fix" it by quoting.
- grep probes that begin with `-` (e.g. `--thinking-display`) must be passed via `grep -e`,
  or grep parses them as options and aborts.
