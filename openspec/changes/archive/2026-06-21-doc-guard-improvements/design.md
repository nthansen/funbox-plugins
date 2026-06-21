## Context

doc-sweep ships an opt-in doc-staleness guard: `install-revise-hook` (manual,
`disable-model-invocation: true`) installs a `PreToolUse`/Bash hook
(`revise-push-guard.sh`) into a chosen `settings.json`; the hook diffs `marker..HEAD`,
classifies changed files as doc/non-doc, and denies a Claude-driven `git push` when
non-doc work is unreviewed. `revise-docs-and-mark` wraps the unchanged `revise-docs` skill
and writes the per-clone review marker
(`$(git rev-parse --git-common-dir)/doc-sweep-revise-marker`). CLAUDE.md updates are
delegated to the external `claude-md-management:revise-claude-md` command (edit-only:
Read/Edit/Glob, no git).

Real-world install feedback exposed five rough edges (trigger inflexibility, no marker on
install, thin reporting, vendored-doc false positives, piecemeal commits) plus a worktree
call-out. Constraints: the validator + `claude plugin validate` must stay green;
`allowed-tools` must be scoped (no bare Bash); hook stays `node`-only (no `jq`),
deterministic, fail-open; the `*.sh` file stays LF and ShellCheck-clean; per-skill eval
gate (`check-skill-gate.mjs`) must pass.

## Goals / Non-Goals

**Goals:**
- Let the installer choose the guarded verb (push or commit) and seed the marker so the
  first run isn't a surprise block.
- Make the install self-describing: a structured summary and a real reconfigure/uninstall
  path for re-runs.
- Keep doc review and the guard inside repo boundaries — never treat vendored/external
  files as repo docs — via a scanned, confirmed, persisted exclusion list.
- Make a doc review produce exactly one commit.
- Preserve correct behavior under git worktrees and verify it.

**Non-Goals:**
- Supporting *both* push and commit triggers simultaneously (commit subsumes push; the
  trailing-commit backstop isn't worth a redundant prompt).
- Renaming the copied hook file (`doc-sweep-revise-push.sh`) — cosmetic churn that orphans
  existing installs.
- Changing the external `revise-claude-md` command, or making the base `revise-docs`
  aware of the guard/marker.
- Auto-activating anything on plugin install (the guard stays strictly opt-in).

## Decisions

### D1: Exactly one trigger — push (default) or commit
- **Choice:** Installer asks for a single trigger; hook reads `trigger` ("push"|"commit")
  from config and matches the corresponding git subcommand with verb-appropriate deny text.
- **Rationale:** Commit-time gating (`marker..HEAD`, where the new commit isn't yet in HEAD
  at PreToolUse) effectively subsumes push-time gating; offering "both" only adds a
  redundant second prompt for a thin trailing-commit backstop.
- **Alternatives considered:** push-and-commit multi-select (rejected: double-prompt, larger
  config surface); keep push-only (rejected: doesn't meet the commit use-case).

### D2: Seed the marker at install (offered, not forced)
- **Choice:** Fresh install presents three options — seed `marker=HEAD` now (reported as an
  assumption, no review performed), run `revise-docs-and-mark` now, or leave unseeded with a
  warning that the next guarded action blocks. Reconfigure/uninstall never touch the marker.
- **Rationale:** Without a marker the first guarded action falls back to `merge-base..HEAD`
  and blocks — a confusing first experience. Offering keeps the user's intent explicit
  rather than silently asserting docs are current.
- **Alternatives considered:** always auto-seed (rejected: hides the "no review happened"
  assumption); never seed, only instruct (rejected: still a surprising first block).

### D3: Always print a structured install summary; real reconfigure flow
- **Choice:** After any install/reconfigure, print settings/hook/config paths, trigger,
  doc-set, repo scope, marker state, behavior caveats (Claude-driven only, needs `node`,
  fails open), bypass tokens, and edit/uninstall instructions. On an existing install offer
  Reconfigure / Uninstall / Cancel; reconfigure re-asks pre-filled, rewrites the config JSON
  (and the matcher only if the hook path changed), leaves the marker alone.
- **Rationale:** Users couldn't tell what was set up or how to change it, and re-running to
  reconfigure was an expected workflow.
- **Alternatives considered:** terse confirmation line (rejected: the original thin report
  is the reported problem).

### D4: Tracked-only discovery + scanned/confirmed/persisted `excludeDirs`
- **Choice:** `revise-docs` discovers docs via `git ls-files` (tracked-only; honors
  `.gitignore`) plus explicit existence-checks for known local twins
  (`audience-rules.local.md`, `CLAUDE.local.md`, `*.local.md`). On first run/install, scan
  for likely-vendored dirs (git submodules, non-root package manifests, known names),
  confirm with the user once, and persist an `excludeDirs` list to
  `.claude/context/audience-rules.md`. The hook config mirrors it; both honor it. Later runs
  read silently.
- **Rationale:** `git ls-files` cleanly drops gitignored deps (node_modules, dist); the
  vendor list covers *committed* vendored dirs; the local-twin allowlist recovers gitignored
  docs we legitimately care about without re-admitting node_modules. Persisting avoids
  re-prompting on the frequently-run `revise-docs`.
- **Alternatives considered:** expanded hardcoded skip list (rejected: drifts, ignores
  project `.gitignore`); silent auto-detect with no confirmation (rejected: user can't
  correct a wrong guess); ask every run (rejected: noise).

### D5: Wrapper owns a single commit
- **Choice:** `revise-docs-and-mark` gains `Bash(git add*)` + `Bash(git commit*)` and makes
  exactly one commit after all CLAUDE.md + README edits, then writes the marker.
  `revise-docs` and `revise-claude-md` stay edit-only.
- **Rationale:** The sub-skill already can't commit (Read/Edit/Glob), so the piecemeal
  commits come from the orchestrating session; centralizing the commit in the wrapper is the
  natural, low-risk fix.
- **Alternatives considered:** best-effort fold-in if a sub-skill committed (unnecessary —
  no sub-skill commits).

### D6: Worktree safety by construction
- **Choice:** Keep resolving the marker via `git rev-parse --git-common-dir` (shared
  per-clone), keep `excludeDirs` in the tracked overlay (shared across worktrees), and
  document that project-scoped installs live under the worktree's `.claude/`. Add a
  verification step rather than new machinery.
- **Rationale:** The existing common-dir resolution already gives correct cross-worktree
  marker semantics; the change must not regress it.

## Risks / Trade-offs

- [Risk] Commit-trigger mode prompts a doc review on nearly every commit → Mitigation:
  push is the recommended default; the commit cadence is documented in the install summary
  so the user opts in knowingly.
- [Risk] Seeding `marker=HEAD` asserts docs are current without a review → Mitigation: the
  summary states plainly that no review was performed; "review now" is offered alongside.
- [Risk] The vendor scan mis-classifies a real first-party dir as vendored → Mitigation:
  scan only *proposes*; the user confirms; `excludeDirs` is editable in a tracked file.
- [Risk] Adding `Bash(git add*/commit*)` widens the wrapper's tool scope → Mitigation:
  narrowly scoped patterns; validator enforces no bare Bash; behavior is the wrapper's own
  single commit only.
- [Trade-off] Dropping "both triggers" loses the trailing-commit backstop → accepted: the
  gap is one commit and not worth the redundant prompt.

## Migration Plan

Non-breaking and opt-in. Existing installs keep working: a config without `trigger` defaults
to "push"; a config without `excludeDirs` falls back to tracked-only + default vendor list.
No deploy/endpoint/DB changes. Rollback = revert the doc-sweep skill/hook edits; existing
hook entries and markers remain valid. Acceptance: validator + `claude plugin validate`
green; ShellCheck/`bash -n` clean; updated evals pass the skill-gate; CHANGELOG updated;
worktree behavior verified manually.

## Open Questions

None — all design forks were resolved during brainstorming.
