# lore

Claude Code **skills** that keep your docs sorted by audience — `CLAUDE.md` for Claude,
`README.md` for humans — writing them from what actually happened in your session.

Part of the [**funbox**](../../README.md) Claude Code plugin marketplace.

## Install

```text
/plugin marketplace add nthansen/funbox-plugins
/plugin install lore@funbox
```

To update later: `/plugin marketplace update funbox`.

## The problem

Every repo keeps docs for different readers, and it's easy to put the wrong thing in the wrong
place:

- **`CLAUDE.md`** — instructions for Claude, shared with the team in git.
- **`CLAUDE.local.md`** — your machine-specific paths, tools, and config, gitignored so it never
  leaks into the team's docs.
- **`README.md`** — for humans: how to build, run, and use the project.
- **`README.local.md`** — your machine-specific human-facing notes, gitignored.

After a working session these fall out of date, and content drifts across the boundaries. These
skills keep docs sorted by audience, writing them from the live session context — something a
"doc must change when code changes" check can't do.

## Skills

Five skills. Every one shows you its changes and asks before writing.

### `revise-docs` — update docs from what changed

Run it after a working session. It reviews what changed — new commands, renamed paths, gotchas,
architectural decisions — and updates the docs, splitting content by audience.

- README updates: handled directly.
- `CLAUDE.md` updates: delegated to `claude-md-management:revise-claude-md`.
- Proposes a diff per file, and applies only what you approve.

### `audit-docs` — check documentation health

Not session-specific — run it any time. It reviews `CLAUDE.md` health by delegating to
`claude-md-management:claude-md-improver`.

- Flags misplaced content: human-facing text that belongs in a `README`, local paths that
  belong in `CLAUDE.local.md`.
- Evaluates quality against the rubric.
- Asks for approval before any changes.

### `init-audience-rules` — scaffold per-project audience rules

Writes a project-specific **overlay** so `revise-docs` and `audit-docs` apply *this repo's*
conventions on top of the invariant base.

- Inspects the repo: primary shell/OS, monorepo layout, existing doc conventions.
- Writes a small, team-shared overlay of just the project's differences.
- Asks for approval before writing.

### `init-claude-rules` — build `.claude/rules` from your code

The `.claude/rules` counterpart to `/init`. It builds a repo's Claude rules by reading them
*off the code* instead of from memory. Works on any codebase (git optional) — run it from the
root of the repo or folder you want scanned.

- Reads structure, recurring code patterns, and config signals.
- Walks you through each convention **with its evidence**, and writes only the rules you confirm.
- Path-specific conventions → `paths:`-scoped files under `.claude/rules/` (loaded only when
  Claude reads matching files); repo-wide standards → a `CLAUDE.md` entry.
- Exclude large irrelevant directories via `.claude/rules-ignore`.
- Merges with existing rules, never clobbers them.

### `revise-claude-rules` — fold session learnings into existing rules

The `.claude/rules` counterpart to `revise-docs`, and the incremental sibling of
`init-claude-rules`. After a session it folds what the session revealed into your **existing**
`.claude/rules` — it does not cold re-scan the whole repo (that's `init-claude-rules`).

- Captures: a stale rule, a new pattern you introduced, a convention you agreed on, or guidance
  you kept needing but never ruled.
- Verifies each change against the current code, and shows it with its evidence and exact diff.
- Merges non-destructively; stale-rule removal is flag-and-confirm.
- No rules yet? It points you to `init-claude-rules`.

## Audience rules

The skills enforce a simple split:

- `CLAUDE.md` / `CLAUDE.local.md` → Claude
- `README.md` / `README.local.md` → humans

Rules load in **two layers**, and the effective ruleset is base + overlay:

1. **Base** — [`context/audience-rules-base.md`](context/audience-rules-base.md).
   The file-boundary law: `CLAUDE*` = Claude, `README*` = humans, never mix; plus the `.local.md`
   convention. **Always enforced, not overridable.**

2. **Overlay** — the tunable layer on top. `lore` uses, in order:
   - the **consuming project's** `${CLAUDE_PROJECT_DIR}/.claude/context/audience-rules.md`
     (plus `audience-rules.local.md` for personal exceptions), if present;
   - otherwise the plugin's **bundled default overlay**
     [`context/audience-rules.md`](context/audience-rules.md).

   An overlay may add file types and refine per-file contents and shell/path conventions — but
   it can never reassign a file's audience or scope.

The payoff:

- The boundary law can never drift.
- A project override stays small — just its differences.
- Everyone else gets a sensible default with no setup.

To scaffold a project overlay without hand-writing it, run `init-audience-rules`.

## Requirements

`revise-docs` and `audit-docs` delegate their `CLAUDE.md` work to the **`claude-md-management`**
plugin (from the official `claude-plugins-official` marketplace), so `lore` declares it as a
dependency.

- Installing `lore` **auto-installs `claude-md-management`** — as long as you have the
  `claude-plugins-official` marketplace added (most setups do).
- If you don't, Claude Code reports a `dependency-unsatisfied` error with the exact command to
  add it.

## Usage

- **After a session:** ask Claude to "revise the docs" (or run `/revise-docs`).
- **Any time, to check doc health:** ask it to "audit the docs" (or run `/audit-docs`).

## Versioning

Distributed on the **funbox** rolling `main` channel — the plugin omits `version` in `plugin.json`,
so every commit is the current version and `/plugin marketplace update funbox` moves you to the
latest. Changes are tracked in [CHANGELOG.md](CHANGELOG.md).

## License

Released into the public domain under [The Unlicense](../../LICENSE). Do whatever you want with it
— no attribution required.
