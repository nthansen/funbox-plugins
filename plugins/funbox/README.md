# funbox

Claude Code **skills** that keep your docs swept by audience — `CLAUDE.md` / `README.md` — writing
them from what actually happened in your session.

Part of the [**funbox**](../../README.md) Claude Code plugin marketplace.

## Install

```text
/plugin marketplace add nthansen/funbox-plugins
/plugin install funbox@funbox
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
skills keep docs swept by audience, using the live session context to write them — something a
mechanical "a doc must change when code changes" check can't do.

## Skills

- **`revise-docs`** — after a working session, reviews what changed (new commands, renamed paths,
  gotchas, architectural decisions) and updates the docs, splitting content by audience. README
  updates are handled directly; `CLAUDE.md` updates are delegated to the
  `claude-md-management:revise-claude-md` skill. Proposes a diff per file and applies only what you
  approve.
- **`audit-docs`** — not session-specific: reviews `CLAUDE.md` health by delegating to the
  `claude-md-management:claude-md-improver` skill — flagging misplaced content (human-facing text
  that belongs in a README, local paths that belong in `CLAUDE.local.md`) and evaluating quality
  against its rubric, with approval before any changes.
- **`init-audience-rules`** — scaffolds a project-specific audience-rules **overlay** so the two
  skills above apply *this repo's* conventions on top of the invariant base. Inspects the repo
  (primary shell/OS, monorepo layout, existing doc conventions) and writes a small, team-shared
  overlay of just the project's differences — with approval before writing.

All three ask for approval before changing anything.

## Audience rules

The skills enforce a simple split — what belongs in `CLAUDE.md` / `CLAUDE.local.md` (Claude) vs
`README.md` / `README.local.md` (humans). Rules load in **two layers**, and the effective ruleset
is base + overlay:

1. **Base** — [`context/audience-rules-base.md`](context/audience-rules-base.md): the file-boundary
   law (`CLAUDE*` = Claude, `README*` = humans, never mix; the `.local.md` convention). **Always
   enforced and not overridable.**
2. **Overlay** on top — the tunable layer: the **consuming project's**
   `${CLAUDE_PROJECT_DIR}/.claude/context/audience-rules.md` (plus `audience-rules.local.md` for
   personal exceptions) if present, otherwise the plugin's **bundled default overlay**
   [`context/audience-rules.md`](context/audience-rules.md). An overlay may add file types and
   refine per-file contents and shell/path conventions, but never reassigns a file's audience or
   scope.

So the boundary law can never drift, a project override stays small — just its differences — and
everyone else gets a sensible default with no setup. To scaffold a project overlay without
hand-writing it, run `init-audience-rules`.

## Requirements

Both `revise-docs` and `audit-docs` delegate their `CLAUDE.md` work to the
**`claude-md-management`** plugin (from the official `claude-plugins-official` marketplace), so
funbox declares it as a dependency. Installing funbox **auto-installs `claude-md-management`** — as
long as you have the `claude-plugins-official` marketplace added (most setups do). If you don't,
Claude Code reports a `dependency-unsatisfied` error with the command to add it.

## Usage

After a session, ask Claude to "revise the docs" (or run `/revise-docs`); to check documentation
health anytime, "audit the docs" (or `/audit-docs`).

## Versioning

Distributed on the **funbox** rolling `main` channel — the plugin omits `version` in `plugin.json`,
so every commit is the current version and `/plugin marketplace update funbox` moves you to the
latest. Changes are tracked in [CHANGELOG.md](CHANGELOG.md).

## License

Released into the public domain under [The Unlicense](../../LICENSE). Do whatever you want with it
— no attribution required.
