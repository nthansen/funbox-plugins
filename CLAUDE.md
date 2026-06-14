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
- `.claude/context/audience-rules.md` — funbox dogfoods **doc-sweep**; this is the repo's
  documentation **audience-rules overlay**, layered on doc-sweep's bundled base
  (`plugins/doc-sweep/context/audience-rules-base.md`). It holds only funbox's deltas; the base
  owns the CLAUDE-vs-README boundary law.
- `doc-sweep`'s `init-audience-rules` skill is **`disable-model-invocation: true` on purpose**
  (manual-only `/`-command): auto-invocation over-triggers on ordinary CLAUDE.md-vs-README doc
  talk. Don't remove it — `revise-docs`/`audit-docs` stay model-invocable.

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
  `Bash`/`PowerShell`); cross-marketplace deps must be allowlisted; orphan plugin dirs; a
  danger-pattern scan.
- CI also runs the **official `claude plugin validate`** per plugin (no `--strict`, so the
  intentionally-omitted `version` isn't flagged), plus `bash -n`, ShellCheck, PowerShell
  parse, and gitleaks.
- The validator checks SKILL.md frontmatter with **regex, not a YAML parser** — it can pass
  malformed YAML (e.g. an unquoted `key: value` colon-space inside a `description`) that fails
  at load time. Rely on `claude plugin validate` for frontmatter correctness, and keep `: ` and
  other YAML-significant punctuation out of unquoted frontmatter scalars.

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
