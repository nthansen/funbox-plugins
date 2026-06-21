<!--
Raw capture of superpowers:brainstorming output for the doc-guard-improvements change.
Decision-log format: background → decision chain → design trade-offs → worktree callout.
design.md reorganizes this into structured sections; do not duplicate.
-->

# Brainstorm — doc-staleness guard improvements

## Background

The doc-sweep plugin ships an opt-in push-time guard system:

- `install-revise-hook` (SKILL, `disable-model-invocation: true`) installs a Claude Code
  `PreToolUse`/Bash hook into a chosen `settings.json`, copies the hook script to a stable
  path, and writes a small config JSON.
- `revise-push-guard.sh` is the hook: on a Claude-driven `git push`, it diffs
  `marker..HEAD`, classifies each changed file as doc / non-doc, and **denies** the push
  (fail-open on any error) if a non-doc file changed since docs were last reviewed.
- `revise-docs-and-mark` (wrapper) runs the unchanged `revise-docs` skill, then records the
  **review marker** (`$(git rev-parse --git-common-dir)/doc-sweep-revise-marker`) the hook
  reads. `revise-docs` updates README.md directly and delegates CLAUDE.md to the external
  `claude-md-management:revise-claude-md` command.

User feedback after a real install:
1. The installer didn't let them pick what to trigger on — it was push-only, but in that
   repo they wanted commit.
2. It didn't tell them they needed to run the follow-up skill to set the marker file; on
   first run the guard immediately blocked. They want install to seed the marker, or at
   least instruct.
3. They want a clear summary of what was set up and how to uninstall/edit it; they could
   see people re-running the installer to change their setup.
4. Doc discovery picks up READMEs from external packages/vendored dirs ("be smart, only
   work with repo files, not external packages").
5. The review flow commits piecemeal — it should commit once after all docs are updated.
6. Worktree support — call out / verify nothing breaks under git worktrees.

## Decision chain

**Q1 — Trigger event model?** Surfaced that commit-time gating with `marker..HEAD`
semantics blocks nearly every commit (the new commit isn't in HEAD yet at PreToolUse time,
so it gates commit N+1 whenever committed commit N had an un-reviewed non-doc change).
Push fires once per share. User initially wanted both, then observed that commit-gating
**subsumes** push-gating (a push creates no new commits; the only gap is the single
most-recent commit after the last review, a thin backstop). **Decision: exactly one trigger
— push (recommended default) OR commit.** No "both" (avoids redundant double-prompts).

**Q2 — Marker on install?** Without a marker the first guarded action falls back to
`merge-base..HEAD` and blocks immediately — a surprising first experience. **Decision:
three-way prompt on fresh install — (a) seed `marker=HEAD` now (report it's an assumption,
no review performed; guard then only fires on future changes), (b) run
`revise-docs-and-mark` now (real review), (c) leave unseeded (warn the next run blocks).**
Reconfigure/uninstall leave the marker alone (it's per-clone state, not install state).

**Q3 — Post-install summary + uninstall/edit guidance?** The existing thin "Report" step
wasn't clear enough. **Decision: always print a structured summary** — settings/hook/config
paths, trigger, doc-set, repo scope, marker state, behavior caveats (Claude-driven only,
needs `node`, fails open), bypass tokens (`DOC_SWEEP_REVISE_SKIP=1` / `--no-verify`), and
"re-run `/doc-sweep:install-revise-hook` to edit/uninstall."

**Q4 — Reconfigure flow?** **Decision: on an existing install, offer Reconfigure /
Uninstall / Cancel.** Reconfigure re-asks the question set pre-filled with current config,
rewrites the config JSON (and the matcher only if the hook path changed), leaves the marker
alone, prints the summary.

**Q5 — Vendor/external exclusion approach?** `revise-docs` globs `**/README.md` skipping
only `node_modules/`, so committed `vendor/`, `third_party/`, `Pods/`, submodules get
picked up; the hook (tracked files only, via `git diff`) still flags vendored *source* as
non-doc and counts vendored READMEs as docs. **Decision: discover via `git ls-files`
(tracked-only; auto-honors `.gitignore`) plus a short committed-vendor exclusion list.**
Nuance raised by user: `.local` doc twins are gitignored, so `git ls-files` would drop
them — so discovery = tracked docs **plus** an explicit existence-check for known local
twins by name (`audience-rules.local.md`, `CLAUDE.local.md`, `*.local.md`), never a blanket
"include untracked" (which would drag `node_modules` back). Adds `Bash(git ls-files*)` to
`revise-docs`. The hook applies the same committed-vendor exclusion.

**Q6 — Scan/ask for exclusions, and where to persist?** **Decision: scan + confirm once,
persist to the overlay.** First run/install scans for likely-vendored dirs (git submodules,
non-root package manifests, known names), shows candidates, user confirms; persist an
`excludeDirs` list to `.claude/context/audience-rules.md` (the repo's doc-config home, and
tracked → shared across worktrees). The hook config mirrors it. Later runs read silently —
no re-prompt.

**Q7 — Single-commit ownership?** Confirmed the external `revise-claude-md` command is
`allowed-tools: Read, Edit, Glob` — **no git at all**; neither `revise-docs` nor
`revise-docs-and-mark` commits today, so the "keep committing" is the orchestrating session
committing piecemeal. **Decision: the wrapper owns one commit.** `revise-docs-and-mark`
gains `Bash(git add*)` + `Bash(git commit*)`: after all CLAUDE.md + README edits are
applied/approved, make exactly one commit, then set the marker. `revise-docs` and the
sub-skill stay edit-only.

## Worktree callout

Worktree support is largely correct by construction; the change must preserve it and verify:

- **Marker is shared per-clone, not per-worktree** — both the hook and the wrapper resolve
  it via `git rev-parse --git-common-dir` (points at the main `.git`). Correct: one "docs
  reviewed to here" per clone. The new single-commit step must not change this.
- **`git ls-files` / submodule + vendor scan** behave normally inside a worktree.
- **`excludeDirs` in `.claude/context/audience-rules.md`** is tracked → shared across
  worktrees automatically.
- **Caveat (documented, not new machinery):** a *project-scoped* install writes to
  `${CLAUDE_PROJECT_DIR}/.claude/...`, which in a worktree is that worktree's path, so it
  won't follow sibling worktrees; user-global install sidesteps this. Note it in the
  install summary and design.

## Design trade-offs / YAGNI

- Keep the copied hook filename `doc-sweep-revise-push.sh` even though it now also guards
  commit — renaming is cosmetic churn that would orphan existing installs. Generalize only
  the human-facing wording ("push guard" → "push/commit guard").
- No "both triggers" mode — the marginal trailing-commit backstop isn't worth the redundant
  prompt and extra config surface.
- Exclusions are confirmed once and persisted, not re-prompted each run (revise-docs runs
  frequently; prompting every time would be noise).

## Cross-system dependencies

- `claude-md-management:revise-claude-md` — confirmed **ready / edit-only** (Read, Edit,
  Glob; no git). No conflict with wrapper-owned single commit.

## Acceptance criteria

- `node scripts/validate-marketplace.mjs` and `claude plugin validate` (per plugin) green.
- ShellCheck + `bash -n` clean on the hook.
- `install-revise-hook` and `revise-docs` evals updated (trigger choice, marker step,
  reconfigure, vendor exclusion) and passing the skill-gate (`check-skill-gate.mjs`).
- doc-sweep `CHANGELOG.md` updated.
