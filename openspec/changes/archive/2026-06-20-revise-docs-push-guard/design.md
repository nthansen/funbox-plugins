## Context

doc-sweep's `revise-docs` skill captures a session's documentation learnings, but it
is invoked manually and easy to forget — a recent change merged with an un-filled
spec Purpose for exactly this reason. The natural moment to run it is **session
wrap-up = `git push`**, not every commit (most commits are work-in-flight). The user
wants an opt-in mechanism that nudges `revise-docs` at push time, handling the doc
files it may generate.

Hard constraint: Claude Code / git hooks are deterministic shell commands and
**cannot run the model**, so they cannot execute `revise-docs`. The only viable
mechanism is **block-and-remind**: a `PreToolUse`/`Bash` hook denies a `git push`,
and Claude (in-session) runs `revise-docs`, commits, and retries.

Stakeholders: the funbox maintainer and any doc-sweep user who opts in. Prior art in
`CLAUDE.local.md` warns against always-on/bundled hooks; the established pattern is
opt-in.

## Goals / Non-Goals

**Goals:**
- An **opt-in, interactive installer** (a doc-sweep manual skill) that writes a
  `PreToolUse` hook into the user's chosen `settings.json`.
- The hook blocks a `git push` **only when docs look stale** (non-doc files changed
  since the last `revise-docs` marker), with a message that drives Claude to run
  `revise-docs`, commit, and re-push.
- Generated doc files reach the push because Claude commits them between block and
  retry; the marker advance prevents a re-block loop.
- Installer lets the user scope four things: settings location, repo applicability,
  doc-file set, bypass/uninstall.

**Non-Goals:**
- Running the model from a hook (impossible).
- Guarding raw-terminal `git push` outside a Claude session (only Claude-driven
  pushes fire `PreToolUse`).
- An always-on or plugin-bundled hook (opt-in only).
- Auto-committing from the hook itself (Claude does the commit, in the loop).

## Decisions

### D1: Opt-in interactive installer, not always-on
- **Choice:** doc-sweep ships a manual skill `install-revise-hook`
  (`disable-model-invocation: true`, like `init-audience-rules`) that writes the hook
  on demand.
- **Rationale:** Avoids the rejected-prior-art problems (always-on for every
  installer; `${CLAUDE_PLUGIN_ROOT}`/cache-path fragility).
- **Alternatives:** local-only (too narrow); shipped always-on (rejected prior art).

### D2: Block only when docs look stale
- **Choice:** Hook denies `git push` iff a non-doc file changed in `marker..HEAD`.
- **Rationale:** Nudges only when a doc pass is plausibly warranted; avoids nagging on
  doc-only or no-op pushes.
- **Alternatives:** first-push-per-session (nags needlessly); block-until-fresh-marker
  (highest friction).

### D3: Doc-file set = CLAUDE*/README*/CHANGELOG/docs
- **Choice:** Docs = `CLAUDE*.md`, `README*.md`, `CHANGELOG.md`, `docs/**`; everything
  else (incl. `SKILL.md`) is non-doc.
- **Rationale:** Matches the audience-rules file set; skill/code edits usually imply
  doc updates. User-tunable at install.
- **Alternatives:** include `SKILL.md` as doc (misses stale skill docs);
  CLAUDE.md+README only (over-nags).

### D4: A guard-owned wrapper records the snapshot; revise-docs is untouched
- **Choice:** The snapshot mechanism is **fully abstracted from `revise-docs`**. A new
  guard-owned wrapper skill `revise-docs-and-mark` (1) invokes the unchanged
  `doc-sweep:revise-docs` via the Skill tool, then (2) writes HEAD SHA to
  `$(git rev-parse --git-common-dir)/doc-sweep-revise-marker` — even when no doc changes
  were needed. The hook's deny message and the installer point users at this wrapper.
  `revise-docs` itself gains **no** marker step and no knowledge of the guard.
- **Rationale:** The retry push must pass; advancing the marker to HEAD after a review is
  the only way to distinguish reviewed-from-unreviewed history deterministically in a
  shell hook. The reviewing actor must do the advance — but it need not be `revise-docs`
  itself: wrapping it keeps the base skill pure (operates as-is, usable with or without
  the guard), with the entire snapshot concern owned by the guard feature. A passive
  hook cannot do this: no `PreToolUse`/`PostToolUse`/`Stop` hook can detect "revise-docs
  completed to commit X," and advancing on allowed-push would never close the loop (the
  non-doc commits remain in `marker..HEAD`).
- **Alternatives:** marker written *inside* `revise-docs` (rejected — couples the base
  skill to an opt-in feature); a separate "mark only" command run after `revise-docs`
  (rejected — two manual steps; the wrapper folds them into one). session-id state
  (doesn't express "stale"); timestamp (SHA is rebase-robust via fallback to
  `merge-base`).

### D5: Copy hook script to a stable path; fail-open
- **Choice:** Installer copies the bundled hook to a stable, version-independent path
  and writes an absolute reference into `settings.json`. The hook fails **open** (any
  error ⇒ allow + stderr note).
- **Rationale:** Robust whether or not `${CLAUDE_PLUGIN_ROOT}` expands in settings;
  dodges plugin-cache-hash churn. Fail-open ensures a hook bug never blocks real work.
- **Alternatives:** reference the plugin dir directly (fragile); fail-closed (a bug
  would wedge all pushes).

### D6: Self-skip + bypass keep it polite
- **Choice:** With repo-scope "doc-sweep-enabled only," the hook allows immediately in
  repos lacking `.claude/context/audience-rules.md`/`CLAUDE.md`. Bypass when the push
  command contains `DOC_SWEEP_REVISE_SKIP=1` or `--no-verify`.
- **Rationale:** A user-global install must not nag in unrelated repos; intentional
  skips need an escape hatch.

## Risks / Trade-offs

- [Risk] **Marker/loop coupling** — if `revise-docs` fails to advance the marker, the
  retry push re-blocks. → Mitigation: marker advance is unconditional on revise-docs
  completion; bypass token always available; fail-open on hook errors.
- [Risk] **Only guards Claude-driven pushes** — a raw `git push` in a terminal won't
  fire `PreToolUse`. → Mitigation: documented non-goal; the target workflow is
  Claude-in-the-loop sessions. (A native `.githooks/pre-push` could complement later
  but can only hard-block a human, not run the model.)
- [Trade-off] **Doc-file heuristic is approximate** — a non-doc change might not
  actually need docs, causing an occasional unnecessary nudge. → Accepted: the nudge is
  cheap (run revise-docs, which advances the marker even when it changes nothing) and
  bypass exists.
- [Risk] **settings.json merge** could clobber existing hooks. → Mitigation: installer
  merges idempotently (append our entry; never overwrite the array) and supports clean
  uninstall.
- [Risk] **`${CLAUDE_PLUGIN_ROOT}` expansion uncertainty.** → Mitigation: design avoids
  it entirely (D5).

## Migration Plan

1. Land the new skill + hook script + `revise-docs` marker change behind no default
   behavior change (nothing activates until a user runs the installer).
2. Document opt-in install/uninstall in doc-sweep `README.md` + `CHANGELOG.md`.
3. Rollback: run the installer's uninstall (removes the settings entry + copied script
   + config); the `revise-docs` marker write is inert without the hook.

No CI/runtime surface changes; the marketplace gates (validate-marketplace,
shellcheck, danger-scan) still apply to the new shell script.

## Open Questions

- Final skill name: `install-revise-hook` (proposed).
- Stable copy path for user-global installs: `~/.claude/hooks/doc-sweep-revise-push.sh`
  (absolute, resolved at install) vs `${CLAUDE_PROJECT_DIR}/.claude/hooks/...` for
  project scope (proposed: pick per chosen settings location).
- Whether to also offer a complementary native `.githooks/pre-push` reminder for
  raw-terminal pushes (deferred; out of scope for v1).
