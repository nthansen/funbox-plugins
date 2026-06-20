<!--
Raw capture of superpowers:brainstorming output.
Decision log: background → constraints → decision chain Q1-Q4 → design trade-offs.
design.md reorganizes this into structured sections; do not duplicate.
-->

# Brainstorm — revise-docs push-time guard

## Background

A prior change (skill-quality-gate) merged with an un-filled `## Purpose` (the
`openspec archive` TBD placeholder) because nothing prompted the author to capture
the loose end before the PR landed. That surfaced a broader want: **run doc-sweep's
`revise-docs` (capture this session's doc learnings) automatically at session
wrap-up — i.e. before `git push` — rather than at every commit** (many commits are
work-in-flight and don't warrant a doc pass). The user also flagged the hard part:
if such a guard generates new doc files, those files must get committed and included
in the push.

## Constraints (discovered during exploration)

- **A hook cannot run the model.** Claude Code hooks and native git hooks are
  deterministic shell commands; they can't invoke Claude, and `revise-docs` is
  model-driven (reviews the session, edits docs with judgment). So "a hook runs
  revise-docs" is impossible. The viable mechanism is **block-and-remind**: a
  `PreToolUse`/`Bash` hook denies a `git push`, and Claude — still in-session — runs
  `revise-docs`, commits, and retries. Claude committing between the block and the
  retry is what gets generated doc files into the push.
- **Prior art (repo `CLAUDE.local.md`, "considered & rejected").** Bundling an
  always-on hook in a plugin turns it on for every installer; `${CLAUDE_PLUGIN_ROOT}`
  reportedly may not expand in `settings.json` and the plugin-cache path carries a
  hash that churns on update; community precedent removed always-on hooks. The repo's
  established local-enforcement pattern is the opt-in `.githooks/` mechanism.
- **PreToolUse contract (confirmed via claude-code-guide).** `matcher: "Bash"`,
  `hooks[].command`; stdin JSON includes `tool_name`, `tool_input.command`,
  `session_id`, `cwd`, `transcript_path`; deny via exit 2 + stderr OR JSON
  `hookSpecificOutput.permissionDecision: "deny"` + `permissionDecisionReason`
  (preferred — explicit text Claude reads); allow = exit 0. Hooks fire for subagent
  calls too. (One unresolved point: whether `${CLAUDE_PLUGIN_ROOT}` expands in the
  command — see trade-offs; the design avoids depending on it.)

## Decision chain

**Q1 — Who is this for?**
→ **A reusable, opt-in installer.** doc-sweep provides a manual command/skill that
*writes* the `PreToolUse` hook into the user's own `settings.json` on demand — never
always-on, never bundled-on-for-everyone. Rejected: local-only (just me, too narrow)
and shipped always-on by doc-sweep (hits the rejected prior-art concerns).

**Q2 — What triggers the block?**
→ **Only if docs look stale.** Block a `git push` only when commits since the last
`revise-docs` run touched non-doc files. Rejected: first-push-per-session (simplest
but nags even when no code changed) and block-until-fresh-marker (strictest, highest
friction). Consequence: needs a marker that `revise-docs` writes.

**Q3 — What counts as a "documentation" file?** (a change to anything else ⇒ stale)
→ **`CLAUDE*.md`, `README*.md`, `CHANGELOG.md`, `docs/**`.** Everything else
(including `SKILL.md`, scripts, JSON, source) is non-doc and triggers a nudge.
Matches the audience-rules file set; `SKILL.md` edits usually do imply README/CLAUDE
updates. Rejected: treating `SKILL.md` as a doc (a behavior-changed skill could ship
with stale docs) and CLAUDE.md+README-only (too many nudges).

**Q4 — Which scoping choices should the installer ask (via AskUserQuestion)?**
→ **All four:** (1) settings location (user-global vs project); (2) which repos it
guards (all vs only doc-sweep-enabled repos — keeps a user-global install from
nagging in unrelated repos); (3) doc-file set / sensitivity; (4) bypass + uninstall.
Our brainstorm picks become the presented options + recommended defaults; the hook
reads the user's choices from a small config the installer writes.

## Design trade-offs

- **Marker coupling closes the loop.** `revise-docs` advances a per-clone marker
  (HEAD SHA) on completion *even when it makes no doc changes* (records "reviewed to
  here, nothing needed"). Without that, the retry push would re-block forever. Marker
  lives at `$(git rev-parse --git-common-dir)/doc-sweep-revise-marker` (not committed,
  shared across worktrees).
- **Fail-open.** Any internal hook error ⇒ allow (with a stderr note). A hook bug must
  never break a legitimate push.
- **Self-skip keeps user-global installs polite.** With repo-scope = "doc-sweep-enabled
  only," the hook allows immediately in repos lacking an audience-rules overlay / CLAUDE.md.
- **Copy-the-script-to-a-stable-path** rather than referencing the plugin dir. This is
  robust whether or not `${CLAUDE_PLUGIN_ROOT}` expands in `settings.json`, and dodges
  the plugin-cache-hash churn — making the prior-art concern moot.
- **Bypass** = `git push` command contains `DOC_SWEEP_REVISE_SKIP=1` or `--no-verify`
  (the hook sees the full command string), for intentional skips.
- **Honest non-goals:** can't guard raw-terminal pushes outside a Claude session (only
  Claude-driven pushes fire `PreToolUse`); doesn't auto-run the model; not always-on.
