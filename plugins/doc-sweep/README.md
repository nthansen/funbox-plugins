# doc-sweep

Every repo keeps docs for different readers, and it's easy to put the wrong thing in the wrong
place:

- **`CLAUDE.md`** — instructions for Claude, shared with the team in git.
- **`CLAUDE.local.md`** — your machine-specific paths, tools, and config, kept out of the
  shared file and gitignored so it never leaks into the team's docs.
- **`README.md`** — for humans: how to build, run, and use the project.
- **`README.local.md`** — your machine-specific human-facing notes (e.g. local setup
  commands), kept out of the shared `README` and gitignored.

After a working session these fall out of date, and content drifts across the boundaries — a
local path hardcoded into the shared `CLAUDE.md`, or Claude-only instructions cluttering the
`README`. **doc-sweep** keeps docs swept with two skills that maintain documentation by
audience, so the right content always lives in the right file.

Part of the [**funbox**](../../README.md) Claude Code plugin marketplace.

## Skills

- **`revise-docs`** — after a working session, reviews what changed (new commands, renamed
  paths, gotchas, architectural decisions) and updates the docs, splitting content by
  audience. README updates are handled directly; `CLAUDE.md` updates are delegated to the
  `claude-md-management:revise-claude-md` skill. Proposes a diff per file and applies only
  what you approve.
- **`audit-docs`** — not session-specific: reviews `CLAUDE.md` health by delegating to the
  `claude-md-management:claude-md-improver` skill — flagging misplaced content (human-facing
  text that belongs in a README, local paths that belong in `CLAUDE.local.md`) and evaluating
  quality against its rubric, with approval before any changes.

Both ask for approval before changing anything.

## Audience rules

The skills enforce a simple split — what belongs in `CLAUDE.md` / `CLAUDE.local.md` (Claude)
vs `README.md` / `README.local.md` (humans). They load the rules in this order:

1. The **consuming project's** rules, if present:
   `${CLAUDE_PROJECT_DIR}/.claude/context/audience-rules.md` (plus
   `audience-rules.local.md` for personal exceptions).
2. Otherwise the plugin's **bundled default**:
   [`context/audience-rules.md`](context/audience-rules.md).

So a project can tailor the rules to its own conventions, and everyone else gets a sensible
default with no setup.

The `.local.md` split isn't Claude-only — it applies to both audiences. Each shared doc has an
optional gitignored local companion: `CLAUDE.md`/`CLAUDE.local.md` (Claude Code auto-loads both)
and `README.md`/`README.local.md` (e.g. setup commands specific to your machine). The rule is
the same either way — keep per-developer content in the `.local.md` twin, out of the committed
doc.

## Requirements

Both skills delegate their `CLAUDE.md` work to the **`claude-md-management`** plugin (from the
official `claude-plugins-official` marketplace) — `revise-docs` to `revise-claude-md`,
`audit-docs` to `claude-md-improver` — so doc-sweep declares it as a dependency.
Installing doc-sweep **auto-installs `claude-md-management`** — as long as you have the
`claude-plugins-official` marketplace added (most setups do). If you don't, Claude Code
reports a `dependency-unsatisfied` error with the command to add it.

## Usage

```text
/plugin marketplace add nthansen/funbox-plugins
/plugin install doc-sweep@funbox
```

Then, after a session, ask Claude to "revise the docs" (or run `/revise-docs`); to check
documentation health anytime, "audit the docs" (or `/audit-docs`).

## License

Released into the public domain under [The Unlicense](../../LICENSE). Do whatever you want
with it — no attribution required.
