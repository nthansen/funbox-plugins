## Why

The opt-in doc-staleness guard works, but real use surfaced friction: the installer hard-codes the `git push` trigger (some repos want `commit`), never seeds the review marker (so the first guarded action blocks unexpectedly), and reports its setup too thinly to edit or uninstall confidently. Separately, doc review picks up READMEs from vendored/external packages, and the review flow commits piecemeal instead of once. Fixing these now — before more people install the guard — keeps the feature trustworthy and low-surprise.

## What Changes

**Trigger event**
- From: hook hard-coded to `git push`; installer offers no choice.
- To: installer asks for exactly one trigger — push (default) or commit; hook reads `trigger` from config and gates the chosen verb with verb-appropriate deny text.
- Reason: some repos want commit-time gating.
- Impact: non-breaking (existing installs default to push).

**Marker on install**
- From: install never writes the marker; first guarded action falls back to `merge-base..HEAD` and blocks.
- To: fresh install offers seed-now / review-now / leave-unseeded, reporting that seeding is an assumption (no review performed).
- Impact: non-breaking; removes a surprising first-run block.

**Install summary + reconfigure**
- From: thin "Report" step; re-run only vaguely offers update/uninstall.
- To: always print a structured summary (paths, trigger, doc-set, scope, marker state, caveats, bypass, edit/uninstall); existing install offers Reconfigure / Uninstall / Cancel, reconfigure re-asks pre-filled and rewrites config, leaving the marker alone.

**Repo-boundary doc scoping** (new)
- From: `revise-docs` globs `**/README.md` skipping only `node_modules/`; hook flags vendored source as non-doc and counts vendored READMEs as docs.
- To: discovery via `git ls-files` (tracked-only) plus explicit local-twin checks (`audience-rules.local.md`, `CLAUDE.local.md`, `*.local.md`); a scan-confirm-persist `excludeDirs` list in `.claude/context/audience-rules.md` honored by both `revise-docs` and the hook.
- Impact: `revise-docs` gains `Bash(git ls-files*)`.

**Single commit**
- From: review flow commits piecemeal (the session commits per file).
- To: `revise-docs-and-mark` owns one commit (gains `Bash(git add*/commit*)`) after all CLAUDE.md + README edits, then sets the marker; `revise-docs` and `revise-claude-md` stay edit-only.

**Worktree safety** — preserved and verified: marker stays per-clone via `git rev-parse --git-common-dir`; `excludeDirs` in the tracked overlay is shared across worktrees; document that project-scoped installs are per-worktree.

## Capabilities

### New Capabilities
- `doc-scope-exclusion`: repo-boundary scoping for documentation — tracked-only discovery plus a scanned, user-confirmed, persisted `excludeDirs` list, honored by both the review skill and the guard hook so vendored/external files are never treated as repo docs.

### Modified Capabilities
- `revise-docs-push-guard`: configurable push/commit trigger; marker seeding on install; structured install summary and reconfigure flow; wrapper-owned single commit; hook honors the exclusion config.

## Impact

- Code: `plugins/doc-sweep/skills/install-revise-hook/SKILL.md`, `plugins/doc-sweep/hooks/revise-push-guard.sh`, `plugins/doc-sweep/skills/revise-docs/SKILL.md`, `plugins/doc-sweep/skills/revise-docs-and-mark/SKILL.md`.
- Config contract: hook config JSON gains `trigger` and `excludeDirs`; `.claude/context/audience-rules.md` gains a persisted `excludeDirs` list.
- Tooling: `revise-docs` gains `Bash(git ls-files*)`; `revise-docs-and-mark` gains `Bash(git add*/commit*)`.
- Tests/docs: `install-revise-hook` and `revise-docs` evals updated and re-gated; doc-sweep `CHANGELOG.md` updated.
- Dependencies: external `claude-md-management:revise-claude-md` unchanged (edit-only; no conflict).
