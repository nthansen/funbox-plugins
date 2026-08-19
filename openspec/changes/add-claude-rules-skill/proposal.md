## Why

Agent rules files are the mechanism a repo uses to tell a coding agent how *this* codebase
actually works — its layering, naming, error-handling idioms, test conventions. But they are
almost always written from memory: a maintainer types a handful of "do this, not that" bullets,
they drift from the code within weeks, and the agent trusts them anyway. Across a spread of
representative real repos — a TypeScript monorepo, a Python service, a C#/.NET solution, a
C++/CMake tree, and polyglot full-stack layouts — **several carry a hand-written CLAUDE.md but
none carry a dedicated, evidence-derived rules file**: the slot for machine-verified conventions
is empty even where strong, discoverable conventions exist in the code.

The rules that would help an agent most are *already latent in the repository* — recurring in
the actual symbols, imports, directory shapes, and config files. What is missing is a
disciplined way to **read them off the codebase** rather than invent them, and to do it with
the whole repo in view so a monorepo or polyglot tree is characterized correctly instead of
from whichever subtree the agent happened to open.

## What Changes

- **New skill `init-claude-rules`** in the existing **`funbox`** plugin
  (`plugins/funbox/skills/init-claude-rules/`), model-invocable. It analyzes a repository's
  structure and recurring code patterns and, **interactively with the user**, builds Claude rules
  using Claude Code's **own documented mechanism**: path-scoped rule files under `.claude/rules/`
  as the primary home, plus concise repo-wide entries in `CLAUDE.md` where the docs say global
  standards belong. Scope is deliberately Claude-focused for v1; other agents' rules files are a
  later expansion.
- **Interactive, guided rule-building — not one-shot generation.** The skill walks the repo
  *with* the user: it surfaces each recurring pattern it observes (naming, layering, error
  handling, test placement) with its evidence, and asks which are real conventions, what the rule
  should say, and **where it applies** (which paths/subtrees). Rules are written from the user's
  confirmed answers, so the output reflects intent, not just inference.
- **Rules use `paths:` frontmatter for contextual loading (the documented feature).** Per Claude
  Code's memory docs, a rule file under `.claude/rules/` with a `paths:` glob list loads **only
  when Claude reads files matching those globs**; a rule with no `paths:` loads at launch. The
  skill writes path-specific conventions as `paths:`-scoped files (so a subtree's rules apply only
  there) and reserves launch-loaded / `CLAUDE.md` placement for genuinely repo-wide standards —
  matching the official "move path-specific or single-area guidance to path-scoped rules" advice.
- **Scan-root establishment, git optional.** The skill works on any codebase, not just git repos.
  In a git work tree it defaults the scan root to the resolved repository root (scanning from there
  even when invoked in a subdirectory, and saying which root it chose) so monorepos and polyglot
  trees are characterized with full-repo context; without git it scans the current directory (or an
  explicit path) and does not refuse.
- **Noise exclusion with ignore layering.** Analysis runs over a scannable file set: `git ls-files`
  in a git work tree, else a tree walk honoring `.gitignore` plus a bundled default ignore list. In
  both modes the skill subtracts patterns from `~/.claude/rules-ignore` (user) then
  `.claude/rules-ignore` (repo), in `.gitignore` syntax, so large *tracked* directories irrelevant
  to scanning (generated clients, fixtures, embedded third-party code) can be excluded; excluded
  top-level directories are reported.
- **Evidence-based rules only, and useful ones.** Every proposed rule cites the concrete pattern it
  was inferred from (files/symbols/config it observed); a rule with no observed support in the repo
  is not emitted. This mirrors funbox's existing claim-discipline stance (see the in-flight
  `pr-description` skill's claim ledger). Beyond evidence, a **utility test** (borrowed from `/init`)
  drops candidates Claude would already honor unprompted — standard idioms, or anything plainly
  visible in the code — so the rule set stays small and the rules that matter aren't buried.
- **LSP/structural analysis, config-signal aware.** The skill uses whole-repo reads plus
  available symbol/LSP tooling to find recurring conventions (naming, module layering, error
  handling, test placement), and reconciles them against declared config signals
  (`eslint.config.*`, `tsconfig.json`, `pyproject.toml`, `.editorconfig`, formatter configs) so
  it prefers enforced convention over guessed convention. It also mines already-written convention
  docs (`README`/`CONTRIBUTING`) and other agents' rule files (`.cursor/rules`, `AGENTS.md`,
  `.github/copilot-instructions.md`) as evidence — read-only; it still writes only Claude rules.
- **Follows Claude's file-selection guidance for CLAUDE.md.** The primary output is path-scoped
  rules; the skill may *also* propose a short repo-wide entry in `CLAUDE.md` (or `.claude/CLAUDE.md`)
  when a convention is genuinely global, keeping such additions concise (the docs advise <200 lines
  per CLAUDE.md) and non-destructive. It does **not** move per-area, path-specific guidance into
  CLAUDE.md — that belongs in `.claude/rules/` per the docs.
- **Propose, don't clobber.** When rule files already exist under `.claude/rules/` (or a CLAUDE.md
  already exists), the skill merges/updates rather than overwriting, flagging conflicts between an
  existing rule and the reality now observed in the repo.
- **README + CHANGELOG** touch-ups for the `funbox` plugin to list the new skill, and a
  marketplace description refresh if the plugin's one-liner no longer covers it.

Non-goals: enforcing rules in CI, and supporting other agents' rules-file formats in v1. v1 is
Claude-focused (`.claude/rules/` + CLAUDE.md); multi-agent targets (`AGENTS.md`, `.cursor/rules`,
and the like) are a documented follow-on.

## Capabilities

### New Capabilities
- `claude-rules-generation`: Analyze a repository or folder from a chosen scan root (git optional) and, interactively with the user,
  build evidence-backed Claude rules the way Claude Code documents — path-scoped rule files under
  `.claude/rules/` using `paths:` frontmatter for contextual loading, plus concise repo-wide
  entries in `CLAUDE.md` for genuinely global standards — inferred from observed
  structure/patterns/config, confirmed by the user, never invented, and reconciled against any
  existing rules rather than overwriting them.

### Modified Capabilities
<!-- None. This adds a new skill and capability; no existing spec's requirements change. -->

## Impact

- **New files**: `plugins/funbox/skills/init-claude-rules/SKILL.md` (plus any bundled
  reference assets under that skill dir).
- **Edited files**: `plugins/funbox/README.md`, `plugins/funbox/CHANGELOG.md`, and possibly the
  `funbox` entry's `description` in `.claude-plugin/marketplace.json` if the one-liner needs to
  mention rules generation.
- **Validation**: must pass the existing CI gates — `claude plugin validate` per plugin
  (mind YAML-significant punctuation in unquoted SKILL.md frontmatter) and
  `openspec validate --strict --all`.
- **Consumers**: repos that install `funbox`; the skill writes to the *target* repo it is run
  in — path-scoped files under `.claude/rules/` (creating the directory if absent) and, for
  repo-wide standards, non-destructive concise entries in that repo's `CLAUDE.md` — not to funbox
  itself. It also honors optional exclude files (`~/.claude/rules-ignore`, `.claude/rules-ignore`)
  when present, but does not create them.
- **No new marketplace dependencies**; the skill relies on Claude Code's own file/search/LSP
  tooling.
