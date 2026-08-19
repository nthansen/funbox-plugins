## 1. Scaffold the skill in the funbox plugin

- [x] 1.1 Create `plugins/funbox/skills/init-claude-rules/` with `SKILL.md`; set frontmatter `name: init-claude-rules` (matching the dir) and a tightly-scoped `description` triggering only on "interactively build `.claude/rules` from this repo" — avoid generic "rules/conventions" wording (over-trigger risk)
- [x] 1.2 Set `allowed-tools` to the minimum: `Read, Glob, Grep, Write, Edit, Bash(git *)` plus the `LSP` tool; keep all frontmatter scalars free of `: ` and other YAML-significant punctuation (CI `claude plugin validate` gate)
- [x] 1.3 Resolve design Open Question #1: decide `disable-model-invocation` vs. model-invocable after drafting the description; record the choice in the SKILL.md frontmatter — chose **model-invocable** (proposal's stated decision) with a description scoped to deriving `.claude/rules`, not generic "rules/conventions"
- [x] 1.4 In the SKILL.md body, cite Claude Code's documented rule model as the contract the skill follows: `.claude/rules/` with `paths:` frontmatter (loads on matching-file read), no-`paths:` rules load at launch, repo-wide standards go to CLAUDE.md (<200 lines), subdir CLAUDE.md loads on demand (refs: `code.claude.com/docs/en/memory.md`, `.../large-codebases.md`)

## 2. Scan-root establishment (spec: Scan-root establishment (git optional))

- [x] 2.1 Write the SKILL.md step that establishes the scan root: in a git work tree default to `git rev-parse --show-toplevel` (scan from the repo root even when invoked in a subdirectory, and say which root was chosen); do not rely on a bare `.git` name check (`.git` is a file, not a directory, in linked worktrees and submodules)
- [x] 2.2 Handle the non-git case: use the current directory (or an explicit path the user gives) as the scan root and proceed — do not refuse on a non-git folder
- [x] 2.3 Document the opt-in subtree override, and require the output to record the reduced scope when it is used

## 3. Analysis procedure (spec: Whole-repo analysis; Config reconciliation)

- [x] 3.1 Structural tier: instruct discovery over the scannable file set — `git ls-files` in a git work tree, else a tree walk honoring `.gitignore` plus a bundled default ignore list — mapping subtrees/packages, language mix, test placement, and naming shapes
- [x] 3.1a Ignore layering: in both modes, subtract patterns from `~/.claude/rules-ignore` (user) then `.claude/rules-ignore` (repo) in `.gitignore` syntax so tracked-but-irrelevant directories are excluded; report the excluded top-level directories
- [x] 3.2 Config-signal tier: detect and read `eslint.config.*`, `tsconfig.json`, `pyproject.toml`, `.editorconfig`, and formatter configs as declared-convention evidence; also mine `README`/`CONTRIBUTING` and other agents' rule files (`.cursor/rules`, `.cursorrules`, `AGENTS.md`, `.github/copilot-instructions.md`) as read-only evidence (still write only Claude rules)
- [x] 3.3 LSP/symbol tier: use the `LSP` tool where available to confirm recurring symbol/layering/error-handling patterns from real usage; define graceful fallback to structural+config when unavailable, and require the output to state the reduced confidence
- [x] 3.4 Encode the reconciliation order (declared config > LSP-confirmed usage > single-file inference) and the config-vs-code conflict surfacing behavior
- [x] 3.5 Per-subtree attribution: require rules to be scoped to the subtree they were observed in for monorepo/polyglot trees, not asserted repo-wide

## 4. Evidence discipline (spec: Evidence-backed rules only)

- [x] 4.1 Require every candidate rule to carry a citation of the files/symbols/config it was inferred from
- [x] 4.2 Add the self-refute pass: seek counter-examples per candidate; downgrade thin-support candidates to low-confidence observations (report as "N of M places", where M is the sites the convention could apply, not the whole repo) and drop unsupported ones (reuse `pr-description` claim-ledger house style)
- [x] 4.3 Add the utility test (from `/init`): drop well-evidenced but obvious candidates Claude would already honor unprompted — the "would omitting this rule cause a mistake?" gate — so the rule set stays small

## 5. Interactive elicitation (spec: Interactive, user-confirmed rule building)

- [x] 5.1 Turn the analysis output into a *candidate list* grouped by area/concern, evidence-ranked, presented to the user in batches rather than one giant prompt
- [x] 5.2 For each candidate, ask the user the three questions: is this a real convention, how should the rule read, and which paths/subtrees it applies to; only write rules the user confirms
- [x] 5.3 Honor rejections (write nothing for a rejected candidate) and honor user-narrowed scope (the written scope matches exactly what the user specified)

## 6. Output routing per Claude Code docs (spec: Documented rule placement; `paths:` frontmatter; Non-destructive merge)

- [x] 6.1 Route each confirmed rule: path-specific → a file under `.claude/rules/` (create dir if absent); genuinely repo-wide → a concise `CLAUDE.md`/`.claude/CLAUDE.md` entry or a no-`paths:` launch-loaded rule file. Never push path-specific guidance into `CLAUDE.md`. Report every path written
- [x] 6.2 Give each path-specific rule file a `paths:` frontmatter glob list covering exactly the confirmed area (docs glob syntax, e.g. `src/**/*.{ts,tsx}`); omit `paths:` for always-on rules; specify the file shape — a `.md` kebab-case named after its concern, `---`-delimited frontmatter, rule under a body heading — and anchor globs so a whole-subtree scope also matches root-level files (pair `dir/*.{ts,tsx}` with `dir/**/*.{ts,tsx}`), avoiding a bare `dir/**` that over-broadens to every file
- [x] 6.3 Merge non-destructively at every target: when `.claude/rules/` files or a `CLAUDE.md` already exist, update/merge rather than overwrite, preserving still-valid rules and flagging existing-rule-vs-observed-reality conflicts; specify the mechanics — edit the same-concern file (union `paths:` globs, revise the matching section in place), add a sibling file only when no existing file covers the concern, leave unrelated files untouched

## 7. Docs and marketplace

- [x] 7.1 Add the skill to `plugins/funbox/README.md` (human-facing: what it does, the interactive flow, the repo-root requirement, and the output routing — `.claude/rules/` with `paths:` plus repo-wide entries in CLAUDE.md)
- [x] 7.2 Add a `plugins/funbox/CHANGELOG.md` entry
- [x] 7.3 Update the `funbox` entry `description` in `.claude-plugin/marketplace.json` only if the current one-liner no longer covers rules generation

## 8. Validation

- [x] 8.1 Run `claude plugin validate` for the funbox plugin and fix any findings (frontmatter, structure)
- [x] 8.2 Run `openspec validate --strict --all` and confirm green
- [x] 8.3 Smoke-test the procedure against 2–3 real repos of differing shape (e.g. a TypeScript monorepo, a Python service, and a polyglot full-stack layout) plus one non-git folder and confirm: scan-root selection works in both git and non-git targets, a `.claude/rules-ignore` entry excludes a tracked directory, the interactive walkthrough elicits confirmations, per-subtree attribution holds, rules carry citations, path-specific rules land under `.claude/rules/` with correct `paths:` globs, and any repo-wide entry is merged into CLAUDE.md non-destructively
- [x] 8.4 Verify the emitted `paths:` frontmatter actually triggers contextual loading in Claude Code (a rule scoped to a subtree loads when a file in that subtree is read, and not otherwise) — verified 2026-08-15 on CLI 2.1.233 via an `InstructionsLoaded` hook log: a fresh session loaded a `paths:`-scoped canary rule with `load_reason: path_glob_match` on reading a matching file (`trigger_file_path` confirmed), and a headless agent recited the rule's user-set secret; the `dir/*` glob matched a root-level file. Note: rules are scanned at session start, so a rule added mid-session only loads in a NEW session, not a resumed/reloaded one
