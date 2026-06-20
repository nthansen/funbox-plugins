# Changelog — doc-sweep

funbox plugins roll on `main` — no pinned `version`, no tags, no releases. Every commit is the
current version, and `/plugin marketplace update funbox` moves you to the latest. So this
plugin's changelog **is** its commit history:

- **All changes:** https://github.com/nthansen/funbox-plugins/commits/main/plugins/doc-sweep

For what the plugin does and how to use it, see [README.md](README.md).

## Notable additions

**Opt-in push guard** (`revise-docs-push-guard` branch, 2026-06)

- New opt-in `PreToolUse` hook (`hooks/revise-push-guard.sh`) that blocks a Claude-driven
  `git push` when a non-doc file changed since the last `revise-docs` run. Uses `node`
  (no `jq` dependency). Fails open — any internal error allows the push.
- New installer skill `install-revise-hook` (`/doc-sweep:install-revise-hook`) that
  interactively copies the hook to a stable path, writes a config, and merges it into the
  chosen `settings.json`. Supports four scope choices (settings location, repo applicability,
  doc-file set, bypass/uninstall). Fully idempotent and reversible.
- `revise-docs` now writes a per-clone review marker (`$(git rev-parse --git-common-dir)/doc-sweep-revise-marker`)
  on completion — even when no doc changes were needed — so the push guard knows which commits
  have already been reviewed. The marker is inert if the guard is not installed.
