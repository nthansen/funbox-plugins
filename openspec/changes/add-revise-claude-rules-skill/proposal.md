## Why

`init-claude-rules` bootstraps a repo's `.claude/rules` by reading conventions *off the code* —
a cold, whole-tree scan. But rules decay the moment the code moves on: a working session renames a
layout, introduces a new idiom, retires an old pattern, or establishes a convention with the user
that no rule yet records. Re-running the cold bootstrap to capture one session's worth of change is
the wrong tool — it re-derives everything from scratch instead of folding in what *this session*
just taught, and it has no notion of a rule that has gone *stale* versus one that never existed.

funbox already draws exactly this line for documentation: `init-audience-rules` / `/init` bootstrap
docs, and **`revise-docs` captures a session's learnings into the existing docs**. The `.claude/rules`
family has the bootstrap half (`init-claude-rules`) but not the upkeep half. This change adds it.

## What Changes

- **New skill `revise-claude-rules`** in the existing **`funbox`** plugin
  (`plugins/funbox/skills/revise-claude-rules/`), model-invocable. It reviews **the current session**
  for convention learnings and folds them into the repo's existing `.claude/rules` (and repo-wide
  `CLAUDE.md` rules), using Claude Code's documented rule mechanism — the same model
  `init-claude-rules` writes to. It is the `.claude/rules` counterpart to `revise-docs`.
- **Session-driven, not a cold re-scan.** The source of truth is what happened in this session, not
  a fresh whole-tree analysis (that is `init-claude-rules`' job). The skill considers four kinds of
  session learning: (a) a rule that proved **stale or wrong**, (b) a **new convention introduced**
  this session, (c) a convention the user and Claude **explicitly agreed** to encode, and (d) a
  **gap** — guidance repeatedly needed this session but absent from every rule. If the session
  surfaced no such learning, the skill says so and stops rather than inventing revisions.
- **Operates on the existing rule set.** The skill discovers and reads `.claude/rules/**/*.md` plus
  the relevant `CLAUDE.md` files, then proposes **edits, additions, or stale-rule removals** against
  them. When no `.claude/rules` (and no `CLAUDE.md` rules) exist at all, it points the user to
  `init-claude-rules` as the bootstrap tool, and MAY still capture the session's learnings as an
  initial rule if the user wants.
- **Evidence discipline carried over from `init-claude-rules`.** Every proposed revision cites its
  **session evidence** (the change, file, or exchange it came from) **and** is verified against the
  current code (Grep/LSP that the pattern actually holds now) before being written. A self-refute
  pass separates a durable convention from a one-off, and a utility test drops anything Claude would
  already honor unprompted. A revision with no observable support is not written.
- **Interactive, user-confirmed, one change at a time.** Each proposed add / edit / removal is
  presented with its evidence and exact diff; only confirmed changes are written. Removing a rule
  that has gone stale is **flag-and-confirm**, never a silent delete.
- **Documented rule placement and non-destructive merge — same rules as `init-claude-rules`.**
  Path-specific conventions stay in `paths:`-scoped files under `.claude/rules/`; genuinely
  repo-wide standards go to `CLAUDE.md`; path-specific guidance is never pushed into `CLAUDE.md`.
  Editing an existing rule unions `paths:` globs and revises the matching body section in place
  rather than duplicating it. Where the repo runs funbox's doc-sweep, doc-sweep still owns
  `CLAUDE.md`'s audience/structure and the skill defers to review there.
- **README + CHANGELOG** touch-ups for the `funbox` plugin to list the new skill, and a marketplace
  description refresh only if the plugin's one-liner no longer covers it.

Non-goals: cold whole-repo rule generation (that is `init-claude-rules`), CI enforcement, and
writing other agents' rule files (`AGENTS.md`, `.cursor/rules`, and the like) — v1 is
Claude-focused and reads those only as evidence, matching `init-claude-rules`' scope.

## Capabilities

### New Capabilities
- `claude-rules-revision`: Review the current session for convention learnings — a rule that proved
  stale, a new pattern introduced, a convention agreed with the user, or a gap repeatedly hit — and
  fold them into the repo's existing `.claude/rules` (and repo-wide `CLAUDE.md` rules), following
  Claude Code's documented rule placement. Each revision is session-grounded, verified against the
  current code, user-confirmed, and merged non-destructively; stale-rule removal is flag-and-confirm;
  when no rules exist yet the skill defers to `init-claude-rules`.

### Modified Capabilities
<!-- None. This adds a new skill and capability; no existing spec's requirements change. -->

## Impact

- **New files**: `plugins/funbox/skills/revise-claude-rules/SKILL.md`.
- **Edited files**: `plugins/funbox/README.md`, `plugins/funbox/CHANGELOG.md`, and possibly the
  `funbox` entry's `description` in `.claude-plugin/marketplace.json` if the one-liner needs to
  mention rules revision.
- **Validation**: must pass the existing CI gates — `claude plugin validate` per plugin
  (mind YAML-significant punctuation in unquoted SKILL.md frontmatter) and
  `openspec validate --strict --all`.
- **Consumers**: repos that install `funbox`; the skill writes to the *target* repo it is run in —
  edits/additions under `.claude/rules/` and, for repo-wide standards, non-destructive `CLAUDE.md`
  entries — not to funbox itself.
- **No new marketplace dependencies**; the skill relies on Claude Code's own file/search/LSP tooling.
