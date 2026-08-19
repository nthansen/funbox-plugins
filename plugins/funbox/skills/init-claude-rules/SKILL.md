---
name: init-claude-rules
description: Interactively derive path-scoped Claude rule files under .claude/rules from this repository's own structure, recurring code patterns, and config signals — evidence-backed, user-confirmed, never invented. Use when the user wants to initialize, generate, bootstrap, or refresh .claude/rules for a repo from its actual code (the `.claude/rules` counterpart to `/init` for CLAUDE.md). Works on any codebase (git optional); run it from the root of the repo or folder you want scanned.
allowed-tools: Read, Glob, Grep, Write, Edit, Bash(git *), LSP
---

Build a repository's Claude rules by reading them *off the code*, not from memory, and confirm each
with the user before writing it. Guided and conversational, not a one-shot generator.

## The rule model this skill follows (read first)

Output follows Claude Code's documented rule/memory model (refs `code.claude.com/docs/en/memory.md`,
`.../large-codebases.md`, `.../claude-directory.md`):

- **`.claude/rules/` is the primary home.** A rule file's `paths:` glob list is the load trigger:
  with `paths:`, it loads **only when Claude reads a file matching one of those globs**; with no
  `paths:`, it loads at launch (always in effect). The trigger is `paths:`, never a `description` key.
- **`CLAUDE.md` is for genuinely repo-wide standards** — keep it concise (docs advise under 200
  lines). Subdirectory `CLAUDE.md` loads on demand. Move path-specific guidance **out** of
  `CLAUDE.md` into a `paths:`-scoped rule; never push single-area guidance into `CLAUDE.md`.

So: path-specific conventions → `paths:`-scoped files under `.claude/rules/`; only a truly global
standard → `CLAUDE.md` (or a no-`paths:` launch-loaded rule file).

**The `paths:` trigger is a read.** A scoped rule loads when Claude *reads* a matching file ("not on
every tool use"), matched on the operated-on path (GA; symlink-aware since v2.1.198). Caveat: it may
not fire when Claude *creates a brand-new file* in a scoped area without first reading one there. Do
**not** try to force loading from `CLAUDE.md` — a prose pointer is always-on (defeats scoping) and an
`@import` loads the rule unconditionally at launch (also defeats scoping). The remedy is a routing
choice, in Step 5.

v1 **writes** Claude rules only — never other agents' rule files (`AGENTS.md`, `.cursor/rules`, and
the like). It may still **read** them as evidence (Step 2).

## Step 1 — Establish the scan root

Whole-repo context is what lets this skill characterize a monorepo or polyglot tree correctly, so
scan the widest sensible root. Git is used when present but **not required** — a plain folder is a
valid target.

1. **Git work tree:** default the scan root to `git rev-parse --show-toplevel`. If invoked from a
   subdirectory, scan from that repo root anyway and tell the user which root you chose. Don't do a
   bare `.git` name check — `.git` is a directory in a normal checkout but a *file* in a linked
   worktree or submodule; `rev-parse` resolves all three.
2. **No git:** the scan root is the current directory, or an explicit path the user gives. Do not
   refuse — a non-git folder is a supported target.
3. **Subtree override:** if the user *explicitly* asks to scope to a subtree, scope to it — but
   state that scope is reduced, and note it in every rule written (derived from that subtree only,
   not the whole tree).

## Step 2 — Analyze in tiers, reconciled

Three evidence tiers, strongest first when they overlap, over the **scannable file set** (defined
just below — source only, noise excluded):

1. **Structural (always).** Inventory the scannable files: subtrees/packages, language mix, where
   tests live, and file/naming shapes.
2. **Config signals (when present).** Read declared-convention files as first-class evidence —
   `eslint.config.*`/`.eslintrc*`, `tsconfig.json`, `pyproject.toml`/`setup.cfg`/`ruff.toml`,
   `.editorconfig`, and formatters (`.prettierrc*`, `rustfmt.toml`, `.clang-format`, etc.). Also
   mine already-written convention docs — `README`/`CONTRIBUTING` — and other agents' rule files
   (`.cursor/rules`, `.cursorrules`, `AGENTS.md`, `.github/copilot-instructions.md`) for stated
   conventions; read them as evidence, but still write only Claude rules. A *declared* convention
   beats one merely inferred from code.
3. **LSP / symbol (when available).** Use `LSP` to confirm recurring symbol, module-layering, and
   error-handling patterns from **actual usage** across the tree. If `LSP` is unavailable for a
   language (C++/CMake, shell-only, niche), **fall back** to structural + config and **state that
   confidence is reduced** — never hard-fail.

**The scannable file set.** Pick an enumeration source, then subtract ignore patterns:

- **Enumeration source.** In a git work tree, use `git ls-files` (tracked files only — build output
  and gitignored trees already drop out). Without git, walk the tree and honor any `.gitignore`
  present plus a bundled default ignore list (`node_modules/`, `dist/`, `build/`, `out/`, `.venv/`,
  `target/`, `vendor/`, `__pycache__/`, `coverage/`, `*.min.*`, and the like).
- **Override filter (both modes).** A repo can hold large *tracked* directories that are irrelevant
  to scan — generated clients, fixtures, embedded third-party code. Subtract patterns from
  `~/.claude/rules-ignore` (user-global) then `.claude/rules-ignore` (repo-local; more specific
  wins), in `.gitignore` syntax with `!`-reinclude. These apply **even in git mode**, so a
  tracked-but-irrelevant subtree is excluded. Skip either file if absent.

List the top-level directories you excluded, so the user can catch an over-broad ignore.

**Reconciliation order:** declared config > LSP-confirmed usage > single-file inference. When an
observed code pattern **conflicts** with a declared config signal for the same concern, **surface
the conflict** — do not silently pick a side.

**Per-subtree attribution.** Attribute each pattern to the subtree it was observed in (e.g.
"`packages/api` uses X; `apps/web` uses Y"). Do not assert one convention repo-wide when the
evidence is local.

## Step 3 — Build an evidence ledger, then self-refute

Each candidate keeps a ledger entry citing its concrete evidence — the files, symbols, or config
keys it was inferred from. **A candidate with no observable support is not a candidate.** Never
invent a convention the codebase does not exhibit.

Then run a **self-refute pass** (the `pr-description` claim-ledger house style): for each candidate,
hunt counter-examples.

- Thin or contested support → downgrade to a low-confidence *observation*, reported as "seen in
  **N of M** places" where **M is the sites the convention could apply** (the files/modules/call
  sites relevant to that concern), not the whole repo, and N is how many follow it.
- No dominant pattern / refuted → drop it.

Then apply a **utility test** — evidence is necessary but not sufficient. Drop any candidate Claude
would already honor unprompted: standard language idioms, or anything plainly visible in the files
it edits. Ask *would omitting this rule cause a mistake?* If no, it is documentation, not a rule.
A well-evidenced but obvious convention still earns no rule — a bloated rule set buries the rules
that matter.

Only well-supported, useful candidates advance to elicitation, each still carrying its citation.

## Step 4 — Elicit interactively, one area at a time

Group survivors by area/concern, evidence-ranked, and present in **batches per area** — not one
giant prompt. For each candidate, show the pattern **and its evidence**, and ask:

1. Is this a **real convention** to encode, or a coincidence?
2. **How should the rule read** (exact wording)?
3. **Where does it apply** — which paths/subtrees?

Write **only from confirmed answers**: a candidate the user **rejects** → write nothing; a candidate
the user **narrows** → the written scope matches *exactly* the path set they specified.

## Step 5 — Route each confirmed rule and write it

Route by the Step-1 model, and **report every path you write**:

- **Path-specific / single-area rule → a file under `.claude/rules/`** (create the directory if
  absent). Give it a `paths:` glob list covering **exactly** the confirmed area and no unrelated
  paths (e.g. `paths: ["src/**/*.{ts,tsx}"]`, brace expansion allowed). Anchor each glob at the
  subtree root so it matches files directly in that root, not only nested ones — pair a top-level
  glob with a recursive one, e.g. `dir/*.{ts,tsx}` **and** `dir/**/*.{ts,tsx}`, because a lone
  `dir/**/*.ts` can miss `dir/top-level.ts` under a matcher where `**` must consume a segment. Avoid
  a bare `dir/**`: it over-broadens to *every* file in the subtree (READMEs, lockfiles, images), so
  the rule loads outside its language scope. Name the file in kebab-case after its concern (see the
  shape below).
- **Genuinely repo-wide standard → `CLAUDE.md`** (or `.claude/CLAUDE.md`) as a concise entry, **or**
  a launch-loaded rule file under `.claude/rules/` that **omits `paths:`**. **Never** put
  path-specific guidance in `CLAUDE.md`.
- **Create-heavy scoped area where the rule must apply to *new* files** → because `paths:` triggers
  on read, a purely read-triggered scope can miss brand-new files. When the user says immediate
  application matters there, offer an always-on (no-`paths:`) rule or a per-directory `CLAUDE.md` for
  that area instead; otherwise keep the `paths:` scope and note the rule applies from first read.

**Rule file shape.** Each rule is a `.md` file under `.claude/rules/`, kebab-case named after its
concern, with YAML frontmatter delimited by `---` and the rule under a body heading:

```
---
paths: ["src/api/*.{ts,tsx}", "src/api/**/*.{ts,tsx}"]
---

# API error handling

<the rule, in imperative prose>
```

A launch-loaded (repo-wide) rule omits the `paths:` key. Nesting is allowed
(`.claude/rules/api/endpoints.md`).

**One concern per file, kept concise.** Split unrelated conventions into separate rule files (e.g.
`testing.md`, `api.md`) rather than one catch-all. The docs' under-200-line guidance applies to rule
files too — an over-long rule gets lost in context, not obeyed harder.

**Merge non-destructively at every target.** When `.claude/rules/` files or a `CLAUDE.md` already
exist: update/merge rather than overwrite, and **preserve still-valid existing rules**. Concretely —
when a rule file already covers the same concern, **edit that file**: union the new `paths:` globs
into its frontmatter list (dedup), and revise the matching body section in place rather than
appending a duplicate. When no existing file covers the concern, add a new sibling file. Leave
unrelated files and sections untouched. When an **existing rule contradicts** what you now observe,
**flag it** rather than silently keeping or deleting it. Where the repo runs funbox's doc skills,
they own `CLAUDE.md`'s audience/structure — propose only concise entries there and defer to
review.

## Step 6 — Report

Summarize: the scan root chosen and any top-level directories excluded by ignore rules; every path
touched; each rule's scope (`paths:` globs or "launch-loaded / repo-wide"); the evidence behind it;
any reduced-confidence areas (missing LSP); any conflicts surfaced (config-vs-code,
existing-rule-vs-reality); and — if a subtree override was used — the reduced scope it was derived
from.

Tell the user the new rules take effect in a **new** session: `.claude/rules/` is scanned at session
start, so rules written this session won't load until they start a fresh session — a resumed or
window-reloaded session keeps the old rule set. (Once loaded, a `paths:`-scoped rule then triggers
when Claude reads a matching file.)
