# Changelog — doc-sweep

funbox plugins roll on `main` — no pinned `version`, no tags, no releases. Every commit is the
current version, and `/plugin marketplace update funbox` moves you to the latest. So this
plugin's changelog **is** its commit history:

- **All changes:** https://github.com/nthansen/funbox-plugins/commits/main/plugins/doc-sweep

For what the plugin does and how to use it, see [README.md](README.md).

## Notable additions

**Guard improvements** (`revise-docs-push-guard` branch, 2026-06)

- **Configurable trigger** — the guard can now gate `git commit` instead of `git push`
  (exactly one, chosen at install; push remains the recommended default). The hook reads a
  `trigger` config field and names the gated verb in its deny message.
- **Marker seeding on install** — a fresh install offers to seed the review marker (seed
  HEAD now / run `revise-docs-and-mark` now / leave unseeded), so the first guarded action
  isn't a surprise block.
- **Structured install summary + reconfigure** — the installer prints a summary (paths,
  trigger, doc-set, scope, marker state, caveats, bypass, edit/uninstall) and, on an
  existing install, offers Reconfigure / Uninstall / Cancel.
- **Repo-boundary doc scoping** — `revise-docs` discovers docs from tracked files
  (`git ls-files`, honoring `.gitignore`) plus local `*.local.md` twins, and both the review
  and the hook honor a scanned, user-confirmed `excludeDirs` list (persisted in
  `.claude/context/audience-rules.md`) so vendored/external files are never treated as repo
  docs.
- **Single review commit** — `revise-docs-and-mark` now makes exactly one commit of the doc
  changes (staging only doc paths, never `git add -A`) before advancing the marker;
  `revise-docs` and the delegated `revise-claude-md` stay edit-only.
- **Worktree-safe** — the review marker stays shared per-clone via
  `git rev-parse --git-common-dir`; project-scoped installs are per-worktree (noted in the
  install summary).

**Opt-in push guard** (`revise-docs-push-guard` branch, 2026-06)

- New opt-in `PreToolUse` hook (`hooks/revise-push-guard.sh`) that blocks a Claude-driven
  `git push` when a non-doc file changed since docs were last reviewed. Uses `node`
  (no `jq` dependency). Fails open — any internal error allows the push.
- New installer skill `install-revise-hook` (`/doc-sweep:install-revise-hook`) that
  interactively copies the hook to a stable path, writes a config, and merges it into the
  chosen `settings.json`. Supports four scope choices (settings location, repo applicability,
  doc-file set, bypass/uninstall). Fully idempotent and reversible.
- New wrapper skill `revise-docs-and-mark` (`/doc-sweep:revise-docs-and-mark`) — the guard's
  entry point. It runs the normal `revise-docs` review (unchanged) and then records a per-clone
  review snapshot (`$(git rev-parse --git-common-dir)/doc-sweep-revise-marker`), even when no
  doc changes were needed, so the guard knows which commits have been reviewed. The snapshot
  mechanism is entirely owned by the guard; **`revise-docs` is not modified**.
