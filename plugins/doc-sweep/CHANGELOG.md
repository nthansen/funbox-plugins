# Changelog — doc-sweep

funbox plugins roll on `main` — no pinned `version`, no tags, no releases. Every commit is the
current version, and `/plugin marketplace update funbox` moves you to the latest. So this
plugin's changelog **is** its commit history:

- **All changes:** https://github.com/nthansen/funbox-plugins/commits/main/plugins/doc-sweep

For what the plugin does and how to use it, see [README.md](README.md).

## Notable additions

**Unify doc classification** (`unify-doc-classification`, 2026-07)

- Both guards previously carried their own copy of the doc-matching logic; a `.claude/**`
  misclassification (non-`.md` and nested files under `.claude/` were not reliably recognized as
  docs) had drifted between them. Fixed by extracting a single shared module,
  `hooks/doc-classify.mjs`, that both the CI check (`docs-ci-check.sh`) and the push guard
  (`revise-push-guard.sh`) now delegate to — one glob-matching implementation, one default doc
  set, no room for the two guards to disagree again. Installers vendor the classifier alongside
  the guard script they scaffold.
- **`docMode` is retired** in favor of a plain **`docPatterns`** glob array (**BREAKING** for any
  hand-written or previously-scaffolded config still using the old `docMode` field — it is no
  longer read; re-run the relevant install skill, or rename the field to `docPatterns` in
  `doc-sweep-revise.json` / `docs-ci.json`, to keep a custom doc-file set in effect). Omitting
  `docPatterns` falls back to the module's built-in default, which now correctly includes
  `.claude/**/*.md`.
- New **`exemptPatterns`** concept: first-party changes that never require docs, matched before
  `docPatterns`. The built-in default covers common test globs (`*.test.*`, `*.spec.*`,
  `test/**`, `tests/**`, `__tests__/**`, `*_test.go`, `*_test.py`) — a change whose only non-doc
  files are exempt now clears both the CI check and the push guard *without* a `[skip docs]` ack,
  so test-only PRs and pushes are never blocked. A change that mixes an exempt file with real
  source still enforces on the source file. Unlike `docPatterns` (an installer prompt),
  `exemptPatterns` isn't prompted for — configure it by hand-editing the per-install config JSON
  that the classifier reads via `--config`.
- Funbox's own `docs-staleness.yml` needs no change to pick this up — it runs the check with no
  config, so the fixed built-in default (including `.claude/**`) applies automatically.
- New `node --test` suite, `hooks/doc-classify.test.mjs`, covering glob translation, default
  classification, `docPatterns`/`exemptPatterns` overrides, `excludeDirs` precedence, and the
  test-only-exempt behavior; wired into `validate.yml`.

**Docs-staleness CI check** (`add-docs-staleness-ci`, 2026-07)

- New PR-time GitHub Actions check (`hooks/docs-ci-check.sh`) that **fails** a pull request when
  non-doc files changed but no documentation did — catching drift on human commits, contributors
  without doc-sweep, and **fork PRs**, which the local push guard can't reach. Deterministic: no
  LLM, no API key, no secret; baseline is the PR merge base (no marker). Uses `node` (no `jq`) and
  fails open if the base can't be resolved.
- New acknowledgment token **`[skip docs]`** (mirrors `[skip ci]`): a code-only PR clears the
  check by updating docs, or putting `[skip docs]` in any commit message, or in the PR body
  (editable in-browser — no rebase). The **same token now also clears the local push guard** (it
  must be present on every non-doc commit in the range), so both guards share one vocabulary.
- New installer skill `install-docs-ci` (`/doc-sweep:install-docs-ci`) that vendors the check
  script under `.github/doc-sweep/` and scaffolds a self-contained `pull_request` workflow — no
  external action reference. Idempotent, with reconfigure/uninstall.
- The push guard is repositioned as the optional *local, pre-push* companion; CI is the primary
  drift guard. (funbox itself now uses the CI check and no longer installs the local hook.)

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
