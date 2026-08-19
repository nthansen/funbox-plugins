## 1. Scaffold the skill in the funbox plugin

- [x] 1.1 Create `plugins/funbox/skills/revise-claude-rules/` with `SKILL.md`; set frontmatter `name: revise-claude-rules` (matching the dir) and a tightly-scoped `description` triggering only on "review this session and update the repo's `.claude/rules`" — avoid generic "rules/conventions" wording (over-trigger risk), and keep all frontmatter scalars free of `: ` and other YAML-significant punctuation (CI `claude plugin validate` gate)
- [x] 1.2 Set `allowed-tools` to the minimum: `Read, Glob, Grep, Edit, Write, Bash(git *)` plus the `LSP` tool
- [x] 1.3 In the SKILL.md body, restate the shared rule model (the same one `init-claude-rules` follows): `.claude/rules/` with `paths:` frontmatter (loads on matching-file read), no-`paths:` rules load at launch, repo-wide standards go to CLAUDE.md (<200 lines); writes Claude rules only, reads other agents' rule files as evidence at most

## 2. Session-driven learning capture (spec: Session-driven learning capture)

- [x] 2.1 Write the step that reviews the current session for the four learning kinds — stale/wrong rule, new convention introduced, convention explicitly agreed with the user, gap repeatedly hit — and states this source is the session, not a cold whole-tree re-scan (that is `init-claude-rules`)
- [x] 2.2 Handle the empty case: when the session surfaced no learning, report that there is nothing to revise and stop without inventing revisions

## 3. Existing rule set + init deferral (spec: Operate on the existing rule set, defer to init when empty)

- [x] 3.1 Discover and read existing rules first: `.claude/rules/**/*.md` and the relevant `CLAUDE.md` files (tracked-aware discovery); define proposed changes relative to them
- [x] 3.2 Reuse `init-claude-rules`' git-optional scan-root logic but lighter — the skill needs the existing rules and the files the session touched, not a full-tree inventory
- [x] 3.3 No-rules case: when no `.claude/rules` and no `CLAUDE.md` rules exist, point the user to `init-claude-rules` as the bootstrap; capture session learnings as an initial rule only if the user asks — never silently cold-generate

## 4. Evidence discipline (spec: Session-grounded evidence verified against current code)

- [x] 4.1 Require every candidate revision to carry a two-part citation: the session evidence (exchange/edit/decision) and the current-code evidence (Grep/LSP that the pattern holds now)
- [x] 4.2 Add the code-verification gate: a candidate whose pattern the current code does not exhibit is not written
- [x] 4.3 Add the self-refute pass (durable convention vs one-off) and the utility test (drop anything Claude would already honor unprompted), reusing `init-claude-rules`/`pr-description` house style

## 5. Interactive confirmation (spec: Interactive, user-confirmed revisions)

- [x] 5.1 Present each proposed addition/edit/removal with its evidence and exact diff, one change at a time; write only confirmed changes (mirror `revise-docs`' propose-a-diff-then-ask flow)
- [x] 5.2 Make stale-rule removal (and any meaning-changing rewrite) flag-and-confirm, never a silent delete

## 6. Output routing + merge (spec: Documented rule placement and non-destructive merge)

- [x] 6.1 Route each confirmed revision identically to `init-claude-rules`: path-specific → `paths:`-scoped file under `.claude/rules/` (paired top-level + recursive globs, no bare `dir/**`); repo-wide → concise `CLAUDE.md` entry or no-`paths:` launch-loaded rule; never push path-specific guidance into `CLAUDE.md`; report every path written
- [x] 6.2 Edit the same-concern file in place (union `paths:` globs, revise the matching section) rather than duplicating; leave unrelated files/sections untouched; defer to doc-sweep where it owns `CLAUDE.md`
- [x] 6.3 Flag any conflict between an existing rule and the reality observed in the current code rather than silently keeping or rewriting it
- [x] 6.4 Report step: paths touched, each change + its evidence, and the "takes effect in a NEW session" caveat (rules load at session start)

## 7. Docs and marketplace

- [x] 7.1 Add the skill to `plugins/funbox/README.md` (human-facing: what it does, the session-capture flow, the init/revise split, and the output routing)
- [x] 7.2 Add a `plugins/funbox/CHANGELOG.md` entry
- [x] 7.3 Update the `funbox` entry `description` in `.claude-plugin/marketplace.json` only if the current one-liner no longer covers rules revision

## 8. Validation

- [x] 8.1 Run `claude plugin validate` for the funbox plugin and fix any findings (frontmatter, structure)
- [x] 8.2 Run `openspec validate --strict --all` and confirm green
- [x] 8.3 Smoke-test the procedure (2026-08-18, three scratch git repos): (A) existing `.claude/rules/api-errors.md` whose `fail(message)` claim the code had drifted past to `fail(code, message)` — walked Steps 1-6, edit merged **in place** (`api-errors.md | 2 +-`, no duplicate file, `paths:` globs preserved); (B) a `state.md` Redux rule the code contradicted (zustand only) — flagged the contradiction and removed the stale rule on confirm (` D .claude/rules/state.md`); (C) a repo with no rules — deferred to `init-claude-rules`, clean working tree, nothing written. Code-evidence greps and per-repo scan-root resolution behaved as instructed; the empty-session branch (Step 1 finds nothing → stop) is the same write-nothing control flow validated by (C)
