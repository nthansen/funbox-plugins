# CLAUDE.md — funbox-plugins

**funbox** is a Claude Code **plugin marketplace**. Repo name `funbox-plugins`; marketplace
name is `funbox` (the `name` in `.claude-plugin/marketplace.json`). Each plugin is
self-contained under `plugins/`.

## Layout

- `.claude-plugin/marketplace.json` — the catalog. Each entry: `{ name, source: "./plugins/<name>", description }`.
- `plugins/<name>/.claude-plugin/plugin.json` — plugin manifest; `name` must match the directory **and** the catalog entry.
- `plugins/<name>/{README.md,CHANGELOG.md}` — required for every plugin.
- `plugins/<name>/skills/<skill>/SKILL.md` — skills; frontmatter `name` must match the skill directory.
- `.claude/context/audience-rules.md` — funbox dogfoods its own **doc skills**; this is the repo's
  documentation **audience-rules overlay**, layered on the `funbox` plugin's bundled base
  (`plugins/funbox/context/audience-rules-base.md`). It holds only funbox's deltas; the base
  owns the CLAUDE-vs-README boundary law.
- The `funbox` plugin's `init-audience-rules` skill is **`disable-model-invocation: true` on purpose**
  (manual-only `/`-command): auto-invocation over-triggers on ordinary CLAUDE.md-vs-README doc
  talk. Don't remove it — `revise-docs`/`audit-docs` stay model-invocable.
- **No hook-based docs guard.** An earlier docs-staleness CI check and a revise-docs pre-push guard
  were removed: both were mechanical "a doc must change when code changes" gates that can't tell
  whether the docs are *right*. The doc skills generate docs from live session context, which no
  deterministic hook can do — run `revise-docs` when docs need updating.

## Versioning — read before touching a version

- Plugins **omit `version`** in `plugin.json` on purpose → `main` is a rolling channel (every
  commit is a new version, resolved by commit SHA). Adding a `version` **pins** the plugin
  (consumers stop auto-updating until it's bumped). Only add one to cut a stable, pinnable release.
- No tags or releases — distribution is the git repo + `marketplace.json`, resolved by commit
  SHA (the same model as the official marketplace). Each plugin's `CHANGELOG.md` points at its
  commit history rather than enumerating versions.

## Validation (CI gate — keep it green)

- The primary gate is the **official `claude plugin validate`**, run per plugin in CI (no
  `--strict`, so the intentionally-omitted `version` isn't flagged) and by the optional local
  pre-commit hook (`git config core.hooksPath .githooks`). CI also runs a gitleaks secret scan.
- Keep `: ` and other YAML-significant punctuation out of **unquoted** SKILL.md frontmatter
  scalars, or they fail at load time.
- CI also runs **`openspec validate --strict --all`** (structural spec/change rules). It
  **self-scopes** — no specs / no active changes ⇒ no findings — so OpenSpec is never forced
  onto a PR that doesn't use it. OpenSpec here is **specs + structural validation only**: the
  `openspec/specs/` artifacts (project schema `spec-driven`, in `openspec/config.yaml`) checked
  by CI. The interactive `/opsx:*` authoring commands and superpowers-bridge routing were
  removed — edit specs directly or drive the `openspec` CLI yourself. (Running the CLI re-emits
  `.claude/commands/opsx/`, `.claude/skills/openspec-*/`, and an empty root `package-lock.json` —
  all **gitignored**, so a CLI run won't dirty the tree; this repo isn't an npm project.)
- The OpenSpec CLI is the npm package **`@fission-ai/openspec`** (CI pins
  `@fission-ai/openspec@1.9.0`). The bare name `openspec` is an unrelated squatter that
  installs cleanly but ships **no `openspec` binary** (`command not found`) — always use
  the scoped name to install/run the CLI.

## Local testing

- `make install-local` points the **funbox** marketplace at this working clone (via
  `claude plugin marketplace add "$(CURDIR)"`) and installs the plugin; `make install-remote`
  switches the source back to the GitHub repo; `make remove` tears it down.
- Gotcha: the local clone and the GitHub repo both resolve to the same marketplace name
  `funbox`, so they can't be added at once — each `make` target removes the marketplace before
  re-adding it. After edits, `/reload-plugins` (or reload the VS Code window).

## Dependencies

A plugin depending on another marketplace (e.g. `funbox` →
`claude-md-management@claude-plugins-official`) needs **both** the `dependencies` entry in its
`plugin.json` **and** the target marketplace listed in `allowCrossMarketplaceDependenciesOn`
in `marketplace.json`, or Claude Code can't resolve the dependency at install time.

## Script gotchas

- `*.sh`, `.githooks/*`, and the `Makefile` must stay **LF** (`.gitattributes`) or they break
  on Linux/macOS (CRLF appends a stray `\r` to each Makefile recipe command).
