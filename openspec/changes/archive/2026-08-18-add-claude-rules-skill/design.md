## Context

See `proposal.md - Why` for motivation. This design covers *how* a single model-invocable
SKILL.md realizes the `claude-rules-generation` capability inside the existing `funbox` plugin.

Constraints that shape the approach:

- **funbox packaging law** (CLAUDE.md): the skill is one `SKILL.md` per skill dir with
  frontmatter `name` matching the directory; unquoted frontmatter scalars must avoid `: ` and
  other YAML-significant punctuation or they fail at load. The plugin omits `version` (rolling
  `main`). CI gates: `claude plugin validate` per plugin + `openspec validate --strict --all`.
- **Skills are prompts, not programs.** A skill cannot ship a parser or run a persistent LSP
  server; it *instructs Claude* to use the tools Claude Code already has (Read/Glob/Grep, the
  `LSP` tool, `git`). So the design is a procedure + tool-use policy, not an algorithm to code.
- **Existing funbox precedent to match**: the doc skills load layered rules, state which layers
  are in effect in one line, and use tight `allowed-tools`. The in-flight `pr-description` skill
  establishes the house style of an evidence/claim ledger and an adversarial refute pass — this
  skill reuses that discipline for rules.
- **Real-repo diversity the skill must survive**: TypeScript monorepo, Python service, C#/.NET
  `.sln`, C++/CMake tree, and polyglot full-stack layouts. Several carry a hand-written CLAUDE.md;
  none carry a dedicated, evidence-derived rules file under `.claude/rules/`.
- **Claude Code's documented rule/memory model** (the design conforms to this, not to a
  hand-rolled convention). Confirmed against official docs:
  - `.claude/rules/` is a real feature. A rule file with a **`paths:`** frontmatter glob list
    loads **only when Claude reads files matching those globs**; a rule with no `paths:` loads at
    launch. (Not a `description` key — the loading trigger is `paths:`.)
  - CLAUDE.md loads by walking up the tree from the working directory (managed → user → project →
    local, root-down concatenation); **subdirectory `CLAUDE.md` files load on demand** when Claude
    touches files there. `@path` imports work outside code spans, max depth 4.
  - Official guidance: repo-wide standards belong in CLAUDE.md (target <200 lines); "if an entry
    is a multi-step procedure or only matters for one part of the codebase, move it to a skill or
    a path-scoped rule." Monorepos: root CLAUDE.md + per-package CLAUDE.md.
  - Sources: `code.claude.com/docs/en/memory.md`, `.../large-codebases.md`,
    `.../claude-directory.md`.

## Goals / Non-Goals

**Goals:**

- An *interactive* procedure that reads candidate conventions *off* the repo, cites evidence for
  each, and confirms every rule with the user before writing it — degrading gracefully from
  LSP-rich (typed langs) to config-first (no server available).
- A git-optional scan-root establishment: default to the git repo root when in a work tree
  (scanning the whole tree even from a subdirectory), else the invocation folder — no hard refusal.
- Output as path-scoped rule files with contextual-load frontmatter under `.claude/rules/`,
  non-destructively reconciled with any existing ones.

**Non-Goals (design-level):**

- No CI enforcement, no watch/hook mode — one-shot, session-invoked, like the other funbox skills.
- No custom LSP orchestration beyond the `LSP` tool Claude Code already exposes; if it is
  unavailable for a language, fall back to Grep/structural inference and say so.
- v1 is Claude-focused and writes scoped files under `.claude/rules/`; other agents' rules files
  (`AGENTS.md`, `.cursor/rules`, and the like) are a documented follow-on, not built now.
- Not a batch generator — the skill is a guided, conversational session, so it does not run
  unattended or in CI.

## Decisions

### D1 — New skill in `funbox`, not a new plugin

Per the user's packaging choice. It shares the plugin manifest/marketplace entry with the doc
skills. Alternative (new plugin like `pr-craft`) was rejected for v1: there is only one skill and
no committed sibling roadmap, and a solo-skill plugin adds manifest/README/CHANGELOG overhead for
no isolation benefit. If rule-*enforcement* or rule-*import* siblings emerge, promoting to a
plugin is a later, cheap refactor.

### D2 — Placement follows Claude Code's documented file-selection, not a blanket rule

Output routing mirrors the official guidance (see Context):

- **Path-specific / single-area conventions → `.claude/rules/` with `paths:` frontmatter**, one
  file per concern/area. This is the primary and default output, because `paths:` is exactly the
  documented mechanism for loading a rule only when Claude works in the matching part of the tree.
- **Genuinely repo-wide standards → `CLAUDE.md`** (or `.claude/CLAUDE.md`), kept concise (docs
  advise <200 lines), or equivalently a launch-loaded `.claude/rules/` file with no `paths:`.

Earlier drafts said "never touch CLAUDE.md." That over-corrected: the docs *want* global standards
in CLAUDE.md and path-specific ones in path-scoped rules, so the skill honors that split rather
than banning a target. The only hard line kept is directional — the skill does not push
path-specific guidance *into* CLAUDE.md (the docs say move that out to path-scoped rules), and it
edits CLAUDE.md non-destructively (merge, never clobber). Where the repo already runs funbox's
doc-sweep, doc-sweep still owns CLAUDE.md's audience/structure; this skill only proposes concise
rule entries and defers to review. Alternatives rejected: a single monolithic rules file can't
carry per-area `paths:` scopes; defaulting to `AGENTS.md` presumes cross-agent scope we deferred.

### D3 — Evidence ledger, mirroring `pr-description`

Each proposed rule is emitted with a citation (paths / symbols / config keys). The skill runs a
self-refute pass: for each drafted rule, try to find a counter-example in the repo; if the
pattern is not actually dominant, downgrade to "seen in N of M places" (M = the sites the convention
could apply, not the whole repo) or drop it. A **utility test** (from `/init`) then drops candidates
that are well-evidenced but obvious — anything Claude would already honor unprompted (standard
idioms, or what is plainly visible in the edited files) — so evidence alone never inflates the rule
set. This is the concrete mechanism behind the spec's "evidence-backed rules only" requirement and
reuses house style rather than inventing a new one.

### D4 — Tiered analysis: structural → config → LSP, reconciled

1. **Structural** (always): enumerate the scannable file set — `git ls-files` in a git work tree,
   else a tree walk honoring `.gitignore` + a bundled default ignore list — to map packages/subtrees,
   language mix, test locations, naming shapes. In both modes, layered exclude files
   (`~/.claude/rules-ignore`, `.claude/rules-ignore`, `.gitignore` syntax) subtract large
   tracked-but-irrelevant directories; excluded top-level dirs are reported.
2. **Config signals** (when present): parse `eslint.config.*`, `tsconfig.json`, `pyproject.toml`,
   `.editorconfig`, formatter configs — declared convention is stronger evidence than inferred.
3. **LSP/symbol** (when available for the language): use the `LSP` tool to confirm recurring
   symbol/layering/error-handling patterns from real usage instead of one sampled file.
   Reconciliation rule: **declared config > LSP-confirmed usage > single-file inference**;
   config-vs-code conflicts are surfaced, not silently resolved (spec requirement).

Alternative (LSP-first for everything) rejected: many real repos (e.g. C++/CMake trees,
script-only repos) have weak or no language-server support; structural+config must carry those.

### D5 — Per-subtree attribution for monorepo/polyglot

Rules are scoped to the subtree they were observed in (e.g. `packages/x uses …`) rather than
asserted repo-wide, satisfying the monorepo/polyglot scenarios. This is why the scan root defaults
to the whole tree (D6): from a subdirectory the skill would not see sibling packages and would
over-generalize, so in a git work tree it scans from the repo root even when invoked deeper.

### D6 — Scan-root establishment, git optional

The skill works on any codebase, not only git repos. In a git work tree it defaults the scan root
to `git rev-parse --show-toplevel` and scans from there even when invoked in a subdirectory (telling
the user which root it chose), so whole-tree context (D5) holds; a bare `.git` name check is avoided
because `.git` is a file, not a directory, in linked worktrees and submodules. Without git, the scan
root is the invocation folder (or an explicit path) and the skill does not refuse. A documented
subtree override lets a user narrow scope opt-in, with the reduced scope recorded in every rule.
An earlier draft made repo-root a hard, refuse-below-root precondition; that was dropped because it
broke non-git folders and false-refused on path-comparison edge cases, while defaulting to the git
root achieves the same whole-tree context without a refusal. `allowed-tools` includes a narrow
`Bash(git *)` for root resolution + tracked-file discovery (used only when git is present), alongside
Read/Glob/Grep, `Write`/`Edit`, and the `LSP` tool.

### D7 — Interactive elicitation, not one-shot generation

The skill is a guided session, not a batch generator. It groups observed candidate patterns by
area, and for each one presents the pattern + evidence and asks the user three things: is this a
real convention, how should the rule read, and where does it apply. Only confirmed answers become
rules. This is the concrete mechanism behind the spec's "interactive, user-confirmed rule
building" requirement, and it is why the analysis tiers (D4) feed a *candidate list* rather than a
finished file. To keep a large repo tractable, candidates are presented in evidence-ranked batches
per area rather than one giant prompt; the user can accept/skip/edit each. Alternative (auto-emit
then let the user delete) rejected: it inverts the burden onto the user to disprove rules and
reintroduces the "invented rule" failure the evidence discipline exists to prevent.

### D8 — `paths:` frontmatter for contextual loading, one file per area

Path-specific rule files carry a **`paths:`** frontmatter glob list — the documented key Claude
Code uses to load a rule only when it reads files matching those globs. A rule meant to be always
in effect omits `paths:` (loads at launch) or lives in CLAUDE.md. One file per concern/area (D2)
keeps each `paths:` scope crisp, and a short human-readable heading in the body names the rule (a
body heading, not a load-affecting `description:` key — Claude Code scopes rules by `paths:`, not
by a description). Glob syntax follows the docs (`src/**/*.{ts,tsx}`, brace expansion, etc.). This
is the concrete mechanism behind the spec's `paths:`-frontmatter requirement.

## Risks / Trade-offs

- **LSP tool availability varies by language/session** → tier the analysis (D4); never hard-fail
  on missing LSP, fall back to structural+config and state the reduced confidence in the output.
- **Over-generalizing a coincidental pattern into a "rule"** → the D3 refute pass + evidence
  citations; when support is thin, emit as a low-confidence observation, not a normative rule.
- **Auto-invocation over-triggering** (the same hazard that made `init-audience-rules`
  manual-only) → write a *narrow* description scoped to "interactively build `.claude/rules`
  from the repo," not generic "rules"/"conventions" talk; keep manual-invocation available.
  Decide at implementation whether `disable-model-invocation` is warranted after drafting the
  description (Open Question).
- **Clobbering hand-tuned existing rule files under `.claude/rules/`** → non-destructive merge + conflict
  flagging (spec) and mandatory review-before-write; never overwrite wholesale.
- **Large repos / cost** → analyze from tracked-file inventory and sample representative files per
  subtree rather than reading everything; report what was sampled vs. exhaustively read.
- **`paths:` rules trigger on read, not create** → a scoped rule loads when Claude *reads* a matching
  file ("not on every tool use"; GA, symlink-aware v2.1.198+), so it may not fire when Claude creates
  a brand-new file in a scoped area without first reading one there (confirmed against
  `memory.md`/`claude-directory.md`). A CLAUDE.md loader cannot close this — a prose pointer is
  always-on and `@import` loads unconditionally at launch, both defeating path-scoping. Mitigation
  (D2/D8 routing): for a create-heavy area needing immediate application, route to an always-on
  (no-`paths:`) rule or a per-directory CLAUDE.md; otherwise accept that the rule applies from first
  read.

## Migration Plan

Additive only. New skill dir + README/CHANGELOG edits; no changes to existing skills or specs.
Rollback = delete the skill dir and revert the README/CHANGELOG/marketplace edits. Verify with
`claude plugin validate` (funbox) and `openspec validate --strict --all` before merge, per CI.

## Open Questions

- Should the skill ship `disable-model-invocation: true` (manual-only) like `init-audience-rules`,
  or stay model-invocable with a tightly-scoped description? Deferrable: it changes only the
  frontmatter and the README trigger wording, not the specs, the procedure, or the task
  breakdown. Resolve while drafting/testing the description's trigger precision.
- Which other agents' rules-file formats (`AGENTS.md`, `.cursor/rules`,
  `.github/copilot-instructions.md`) to *write* after the Claude-focused v1, and whether target
  selection is auto-detected or prompted. Deferrable behind the v1 default without changing v1's
  specs. (Note: v1 already *reads* these as evidence; only writing them is deferred.)
- Granularity: one `.claude/rules/` file per concern vs. a small grouped set, and how finely to
  split `paths:` globs. Deferrable — it is a within-`paths:` styling choice that does not change
  the specs or the mechanism. (The frontmatter key itself is settled: `paths:`, per the docs.)
