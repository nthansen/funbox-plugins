---
name: revise-claude-rules
description: Review this session for convention learnings and fold them into the repo's existing .claude/rules (and repo-wide CLAUDE.md rules) — a rule that proved stale, a new pattern you introduced, a convention you and the user agreed on, or guidance repeatedly needed but unruled. Use after a working session to update .claude/rules from what the session revealed. The .claude/rules counterpart to revise-docs; the incremental sibling of init-claude-rules (which cold-scans the whole repo). Model-invocable, or run manually.
allowed-tools: Read, Glob, Grep, Edit, Write, Bash(git *), LSP
---

Capture what **this session** taught you about the repo's conventions and fold it into the existing
Claude rules — never re-derive the whole rule set from a cold scan (that is `init-claude-rules`).
Guided and conversational: propose each change with its evidence, confirm, then write.

## The rule model this skill follows (read first)

Output follows Claude Code's documented rule/memory model — the **same** model `init-claude-rules`
writes to (refs `code.claude.com/docs/en/memory.md`, `.../large-codebases.md`,
`.../claude-directory.md`), so the two skills stay mutually consistent on one repo:

- **`.claude/rules/` is the primary home.** A rule file's `paths:` glob list is the load trigger:
  with `paths:`, it loads **only when Claude reads a file matching one of those globs**; with no
  `paths:`, it loads at launch (always in effect). The trigger is `paths:`, never a `description` key.
- **`CLAUDE.md` is for genuinely repo-wide standards**, kept concise (docs advise under 200 lines).
  Move path-specific guidance **out** of `CLAUDE.md` into a `paths:`-scoped rule; never push
  single-area guidance into `CLAUDE.md`.

This skill **writes** Claude rules only — never other agents' rule files (`AGENTS.md`, `.cursor/rules`,
and the like). It may still **read** them as evidence.

## How this differs from `init-claude-rules`

`init-claude-rules` reads conventions *off the code* in a cold whole-tree scan — the bootstrap.
This skill's source is **the current session**, and the code is the *validator*, not the source:
you propose a change because the session revealed it, then verify the pattern actually holds in the
code before writing. If there are no rules to revise yet, this is the wrong tool — see Step 2.

## Step 1 — Review the session for learnings

Read back over what happened this session and collect candidate revisions of exactly four kinds.
Do **not** launch a fresh whole-repo analysis — only what the session surfaced qualifies:

1. **Stale / wrong rule** — an existing rule the session showed to be outdated or misleading (the
   code no longer matches it, or following it caused a mistake).
2. **New convention introduced** — a pattern, layout, or idiom this session added or established.
3. **Convention explicitly agreed** — something you and the user decided to encode for next time.
4. **Gap** — guidance you needed repeatedly this session but found in no rule.

**If the session surfaced none of these, say so and stop.** There is nothing to revise; do not
invent revisions to have something to write.

## Step 2 — Read the existing rules (or defer to init)

A revision is defined relative to what already exists, so discover and read the current rule set
first:

- Rule files: `.claude/rules/**/*.md` (nesting allowed). In a git work tree prefer tracked
  discovery (`git ls-files '.claude/rules/**'`); otherwise glob the tree.
- Repo-wide rules: the root `CLAUDE.md` and any subdirectory `CLAUDE.md` relevant to the areas the
  session touched.

Establish the scan context git-optionally, as `init-claude-rules` does, but lighter — you need the
existing rules and the files the session touched, not a full-tree inventory. In a git work tree,
resolve the repo root with `git rev-parse --show-toplevel` (don't rely on a bare `.git` name check —
`.git` is a file in linked worktrees and submodules); without git, use the current directory.

**If there are no `.claude/rules` files and no rules in `CLAUDE.md` at all:** revising nothing is
meaningless. Tell the user `init-claude-rules` is the bootstrap tool for a first rule set. You MAY
still capture this session's learnings as an initial rule **if the user asks** — but do not silently
turn into a cold generator.

## Step 3 — Build an evidence ledger, verified against the code

Each candidate revision keeps a **two-part** citation:

- **Session evidence** — the exchange, file edit, or decision this session that it came from.
- **Code evidence** — where the pattern holds **now**, confirmed with Grep/LSP over the current
  files. Session belief is necessary but not sufficient: **a candidate whose pattern the current
  code does not actually exhibit is not written.** (For a *stale-rule* candidate, the "code
  evidence" is the counter-example — the code that now contradicts the existing rule.)

Then apply the same two gates `init-claude-rules` uses:

- **Self-refute** — is this a durable convention, or a one-off produced by this single task? Hunt
  counter-examples. Thin or contested → downgrade to a low-confidence observation or drop it.
- **Utility test** — would omitting this rule cause a future mistake? Drop anything Claude would
  already honor unprompted (standard idioms, or what is plainly visible in the edited files). A
  well-evidenced but obvious learning earns no rule — it only buries the rules that matter.

Only survivors advance to confirmation, each carrying its citation.

## Step 4 — Confirm each change, one at a time

Present each surviving candidate as a concrete change — an **addition**, an **edit** to an existing
rule, or a **removal** of a stale one — with its evidence and the **exact diff**. Then write only
what the user confirms.

- A **removal**, and any **rewrite that changes a rule's meaning**, is flag-and-confirm — surface it
  with its evidence; never delete or silently reverse a rule.
- A candidate the user **rejects** → write nothing. A candidate the user **narrows** → the written
  scope matches exactly the path set they specify.

## Step 5 — Route and merge each confirmed change

Route and merge identically to `init-claude-rules` — this is what keeps the two skills' output
consistent — and **report every path you write**:

- **Path-specific / single-area change → a file under `.claude/rules/`** (create the dir if absent).
  Give it a `paths:` glob list covering **exactly** the confirmed area. Anchor globs so a
  whole-subtree scope also matches root-level files: pair `dir/*.{ts,tsx}` **with**
  `dir/**/*.{ts,tsx}`. Avoid a bare `dir/**` — it over-broadens to every file in the subtree.
  Kebab-case the file name after its concern.
- **Genuinely repo-wide standard → `CLAUDE.md`** (or `.claude/CLAUDE.md`) as a concise entry, **or**
  a no-`paths:` launch-loaded rule file under `.claude/rules/`. **Never** put path-specific guidance
  in `CLAUDE.md`.

**Merge non-destructively.** When a rule file already covers the concern, **edit that file**: union
any new `paths:` globs into its frontmatter list (dedup), and revise the matching body section **in
place** rather than appending a duplicate. Add a new sibling file only when no existing file covers
the concern. Leave unrelated files and sections untouched. When an **existing rule contradicts** what
you now observe, **flag it** rather than silently keeping or rewriting it. Where the repo runs
funbox's doc skills, they own `CLAUDE.md`'s audience/structure — propose only concise entries
there and defer to review.

**Rule file shape** (same as `init-claude-rules`): a `.md` file under `.claude/rules/`, kebab-case
named after its concern, YAML frontmatter delimited by `---`, the rule under a body heading:

```
---
paths: ["src/api/*.{ts,tsx}", "src/api/**/*.{ts,tsx}"]
---

# API error handling

<the rule, in imperative prose>
```

A launch-loaded (repo-wide) rule omits the `paths:` key.

## Step 6 — Report

Summarize: every path touched and whether each change was an **add**, **edit**, or **removal**; the
two-part evidence behind each; any candidates downgraded or dropped by the self-refute/utility gates;
and any conflicts surfaced (existing-rule-vs-current-code).

Tell the user the revised rules take effect in a **new** session: `.claude/rules/` is scanned at
session start, so rules changed this session won't load until they start a fresh session — a resumed
or window-reloaded session keeps the old rule set. (Once loaded, a `paths:`-scoped rule then triggers
when Claude reads a matching file.)
