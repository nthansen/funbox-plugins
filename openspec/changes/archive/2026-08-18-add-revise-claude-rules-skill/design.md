## Context

See `proposal.md - Why` for motivation. This design covers *how* a single model-invocable
SKILL.md realizes the `claude-rules-revision` capability inside the existing `funbox` plugin, and
how it relates to its two siblings — `init-claude-rules` (cold bootstrap of `.claude/rules`) and
`revise-docs` (session-learning capture into CLAUDE.md/README).

Constraints that shape the approach are the same ones that shaped `init-claude-rules`:

- **funbox packaging law** (CLAUDE.md): one `SKILL.md` per skill dir with frontmatter `name`
  matching the directory; unquoted frontmatter scalars must avoid `: ` and other YAML-significant
  punctuation. Plugin omits `version` (rolling `main`). CI gates: `claude plugin validate` per
  plugin + `openspec validate --strict --all`.
- **Skills are prompts, not programs.** The skill instructs Claude to use existing tools
  (Read/Glob/Grep, the `LSP` tool, `git`); the design is a procedure + tool-use policy.
- **Claude Code's documented rule/memory model** is the contract, identical to the one
  `init-claude-rules` conforms to: a `.claude/rules/` file with a `paths:` frontmatter glob list
  loads only when Claude reads a matching file; no `paths:` loads at launch; repo-wide standards
  belong in `CLAUDE.md` (target <200 lines); subdirectory `CLAUDE.md` loads on demand. Sources:
  `code.claude.com/docs/en/memory.md`, `.../large-codebases.md`, `.../claude-directory.md`.
- **Existing funbox precedent to match**: `revise-docs` establishes the session-review /
  propose-a-diff / ask-before-writing flow; `init-claude-rules` establishes the rule model,
  evidence ledger, self-refute + utility gates, output routing, and non-destructive merge. This
  skill composes the two — `revise-docs`' flow over `init-claude-rules`' rule discipline.

## Goals / Non-Goals

**Goals:**

- A session-driven procedure that reads convention *learnings* out of the current session, verifies
  each against the current code, confirms it with the user, and folds it into the existing rule set
  as an edit, addition, or stale-rule removal.
- Reuse of `init-claude-rules`' rule model, evidence discipline, routing, and non-destructive merge
  so the two skills produce mutually consistent output on the same repo.
- Graceful behavior when there is nothing to do (no session learnings → stop) and when there is
  nothing to revise (no rules exist yet → defer to `init-claude-rules`).

**Non-Goals:**

- No cold whole-repo re-scan — that is `init-claude-rules`. This skill does *targeted* verification
  of the specific patterns the session surfaced, not a fresh full-tree analysis.
- No CI enforcement, no watch/hook mode — one-shot, session-invoked, like the other funbox skills.
- v1 writes Claude rules only; other agents' rule files are read-only evidence, matching
  `init-claude-rules`.

## Decisions

### D1 — New skill in `funbox`, sibling to `init-claude-rules`

It shares the plugin manifest/marketplace entry with the other funbox skills, exactly as
`init-claude-rules` does. The init/revise split mirrors the docs family's `/init`-vs-`revise-docs`
split: one skill bootstraps, the other captures ongoing session learnings. Rejected: folding revise
into `init-claude-rules` as a mode — the trigger surfaces differ (cold "generate rules for this
repo" vs. "update the rules from what we just did"), and a tight, separate description triggers more
precisely than an overloaded one.

### D2 — Session is the source; the repo is the check

The learnings come from the session transcript, not a cold scan. Four learning kinds are in scope:
a rule that proved **stale/wrong**, a **new convention introduced**, a convention **explicitly
agreed** with the user, and a **gap** repeatedly hit but unruled. Every candidate revision is then
**verified against the current code** (Grep/LSP that the pattern actually holds now) before it is
proposed — session belief is necessary but not sufficient. This is the concrete difference from
`init-claude-rules`, whose source is the code itself; here the code is the *validator* of a
session-originated claim. If the session surfaced no learning, the skill stops without inventing
work — the counterpart to `revise-docs` finding nothing to change.

### D3 — Evidence ledger + self-refute + utility test, reused from `init-claude-rules`

Each proposed revision carries a citation with two parts: the **session evidence** (the exchange,
file edit, or decision it came from) and the **code evidence** (where the pattern holds now). The
self-refute pass asks whether the learning is a durable convention or a one-off produced by this
one task; the utility test drops anything Claude would already honor unprompted. A revision with no
observable code support is not written — the same discipline as `init-claude-rules`' evidence
requirement, applied to changes rather than fresh rules.

### D4 — Operate on the existing rule set; defer to init when empty

The skill discovers and reads `.claude/rules/**/*.md` and the relevant `CLAUDE.md` files first,
because a revision is defined relative to what already exists (edit this rule, add a sibling, remove
that stale one). When the repo has **no** `.claude/rules` and no `CLAUDE.md` rules, revising nothing
is meaningless, so the skill points the user at `init-claude-rules` as the bootstrap; it MAY still
write the session's learnings as an initial rule if the user asks, but it does not silently become a
cold bootstrapper. Scan-root establishment reuses `init-claude-rules`' git-optional logic but is
lighter — the skill needs the existing rules and the files the session touched, not a full-tree
inventory.

### D5 — Stale-rule removal is flag-and-confirm, never silent

`init-claude-rules`' merge is framed additively (union globs, revise in place, flag contradictions).
Revise adds an explicit **removal** path because rule *decay* is a first-class reason to run it: a
rule the session showed to be wrong. Removal (and any rewrite that changes a rule's meaning) is
always surfaced with its evidence and the exact diff, and written only on confirmation — matching
`revise-docs`' propose-a-diff-then-ask flow and `init-claude-rules`' "flag, don't silently delete"
stance.

### D6 — Documented placement and non-destructive merge, identical to `init-claude-rules`

Routing and merge mechanics are inherited wholesale: path-specific → `paths:`-scoped file under
`.claude/rules/` (paired top-level + recursive globs, no bare `dir/**`); repo-wide → concise
`CLAUDE.md` entry or a no-`paths:` launch-loaded rule; never push path-specific guidance into
`CLAUDE.md`; edit the same-concern file in place rather than duplicating; leave unrelated files
untouched; defer to doc-sweep where it owns `CLAUDE.md`. Keeping these identical is what makes the
two skills safe to run on the same repo.

### D7 — Model-invocable with a tightly-scoped description

Like `init-claude-rules` and `revise-docs`, the skill is model-invocable, but the description is
anchored on "review **this session** and update the repo's `.claude/rules`" — not generic
"rules/conventions" wording, which is the over-trigger hazard that made `init-audience-rules`
manual-only. Manual `/revise-claude-rules` invocation stays available.

## Risks / Trade-offs

- **Over-encoding a one-off as a convention** → the D3 self-refute + code-verification gate: a
  session learning that the current code does not actually exhibit is not written.
- **Auto-invocation over-triggering** on ordinary "rules" talk → the D7 narrow description scoped to
  session-driven `.claude/rules` updates; manual invocation stays available. Revisit
  `disable-model-invocation` at implementation if the description proves too eager (mirrors
  `init-claude-rules`' open question).
- **Divergence from `init-claude-rules`** if the two skills' routing/merge logic drift → D6 keeps
  them identical by construction; the SKILL.md restates the shared rule model rather than inventing
  a variant.
- **Running it on a repo with no rules** → D4 defers to `init-claude-rules` instead of silently
  cold-generating.
- **Rules load at session start** → a revision written this session does not take effect until a new
  session; the skill reports this caveat, as `init-claude-rules` does.

## Migration Plan

Additive only. New skill dir + README/CHANGELOG edits; no changes to existing skills or specs.
Rollback = delete the skill dir and revert the README/CHANGELOG/marketplace edits. Verify with
`claude plugin validate` (funbox) and `openspec validate --strict --all` before merge, per CI.

## Open Questions

- Whether `disable-model-invocation: true` (manual-only) is warranted if the model-invocable
  description over-triggers in practice. Deferrable: it changes only the frontmatter and README
  trigger wording, not the specs, procedure, or tasks — resolve while testing the description.
- Whether to write other agents' rule files (`AGENTS.md`, `.cursor/rules`) on revision after the
  Claude-focused v1. Deferrable behind the v1 default, matching `init-claude-rules`' deferral.
