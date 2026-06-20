# Retrospective: skill-quality-gate

> Written: 2026-06-20 (after verify passed)
> Commit range: `ffec17b..HEAD`
> Worktree: branch `skill-quality-gate` (in-place; no worktree — see §4)

---

## 0. Evidence

- **Commit range**: `ffec17b..24b1839` (14 commits)
- **Diff size**: +5595 lines across 50 files (includes opsx scaffolding + the superpowers-bridge schema vendored under `openspec/schemas/`)
- **Tasks done**: 27/28 (`grep -cE '^- \[x\]' tasks.md` → 27; only 7.3 "CI green on branch" pending post-push)
- **Active hours**: ~1 session (single continuous apply)
- **Subagent dispatches**: 8 (3 infra implementers, 2 reviewers, 1 final review, 2 fix implementers + 4 eval run/grade agents = actually: lib, lib-review, script, script-review, command+docs, discoverSkills-fix, eol-fix, integrity-fix, final-review, init-eval, audit-eval, revise-eval×2 — ~13 total)
- **New external dependencies**: none (CI path is pure Node builtins; skill-creator is an author-time-only tool, not a code dependency)
- **Bugs encountered post-merge**: none yet (pre-merge)
- **OpenSpec validate state at archive**: pass (`openspec validate skill-quality-gate` → valid)
- **Test coverage signal**: 15 unit tests pass (`node --test scripts/skill-gate-lib.test.mjs`); gate green 4/4; 2 negative tests (stale-hash, below-threshold) confirmed fail-closed

Commit chain (chronological):

```
91f362f chore(openspec): adopt OpenSpec + superpowers-bridge scaffolding
b853370 docs(skill-quality-gate): add change artifacts (proposal/design/specs/tasks/plan)
e36a3ed feat(skill-gate): add source_hash algorithm + tests
d451f59 feat(skill-gate): add discovery, threshold, and per-skill check
fbb19b9 feat(skill-gate): add deterministic CI check script
648f6da feat(skill-gate): add threshold config and ignore run workspaces
e0ff599 feat(skill-gate): add /skill-gate command and document the gate
6b0e3eb fix(skill-gate): discoverSkills skips *-workspace run dirs
ba77a55 test(skill-gate): backfill eval artifacts + benchmarks for all 4 skills
800e86a fix(skill-gate): normalize line endings in source_hash for cross-platform CI
e86a3b5 test(skill-gate): regenerate benchmark hashes with normalized algorithm
8d75875 ci(skill-gate): run unit tests and quality gate in validate.yml
eea43d2 fix(skill-gate): reject empty/inconsistent results and zero-skill runs
24b1839 test(skill-gate): record accurate session model id in benchmarks
```

---

## 1. Wins

- [evidence: §0 tests, gate 4/4] The decouple-LLM-from-CI design held up: all expensive evaluation happened author-time and froze into committed `benchmark.json`; CI verification is pure-Node, deterministic, dependency-free.
- [evidence: commit e36a3ed/d451f59, 15 tests] TDD via subagents produced the core lib cleanly — every check branch (missing/invalid/empty/stale/below-threshold/override) is unit-tested and non-tautological.
- [evidence: commit 800e86a] The cross-platform hash risk was caught *before* push by actually inspecting `.gitattributes` + working-tree line endings, not after a red CI. The empirical LF-vs-CRLF hash-equality check in final review confirmed the fix.
- [evidence: research turn] Anti-reinvention paid off: reused skill-creator's eval engine and built only the missing threshold/freshness/glue, exactly per the user's "don't reinvent the wheel" steer.
- [evidence: revise-docs iter-1 vs iter-2] Honest evaluation surfaced an incomplete run (README not updated) rather than rubber-stamping — re-ran faithfully instead of weakening the assertion.

## 2. Misses

- 🟡 [painful | evidence: commit 6b0e3eb] `discoverSkills` originally treated the gitignored `*-workspace/` run dir as a skill — a design gap (workspaces live *under* `skills/`, not as true siblings) that only surfaced when the first real benchmark run created one. Cost a fix cycle.
- 🟡 [painful | evidence: commit 800e86a, e86a3b5] The first 4 benchmarks were committed with byte-exact hashes, then immediately invalidated by the EOL-normalization fix and had to be regenerated. Ordering the portability analysis before the first backfill would have saved a commit.
- 📌 [nit | evidence: final review §Minor] Initial gate let an empty/`pass_rate`-inconsistent `results` array pass; tightened in eea43d2. Caught by the final reviewer, not by the original spec scenarios.
- 📌 [nit | evidence: first backfill] Benchmarks first recorded `model: "claude-opus-4-8"` rather than the true session id `claude-opus-4-8[1m]` (commit 24b1839).

## 3. Plan deviations

| Plan task | What changed | Why |
|-----------|--------------|-----|
| Task 6 (backfill) | Executed by the orchestrator, not the subagent executor | Honest benchmarks require real LLM eval runs; a code-writing subagent must not fabricate `pass_rate`. Split explicitly. |
| Task 7 (CI wiring) | Done after backfill, not in plan order | Its verification ("4 skill(s) passed") depends on the backfilled benchmarks existing. |
| New work (not in plan) | EOL normalization (800e86a), `discoverSkills` workspace skip (6b0e3eb), results-integrity checks (eea43d2) | Discovered during implementation/review; each strengthens the gate's correctness or portability. |

## 4. Skill / workflow compliance

| Skill                                            | Used |
|--------------------------------------------------|------|
| superpowers:brainstorming                        | ✓    |
| superpowers:writing-plans                        | ✓    |
| superpowers:using-git-worktrees                  | ✓ (ran; chose in-place branch — see below) |
| superpowers:subagent-driven-development          | ✓    |
| (transitive) superpowers:test-driven-development | ✓    |
| (transitive) superpowers:requesting-code-review  | ✓    |
| superpowers:finishing-a-development-branch       | ✓ (pending — final apply step) |

### Deliberately Skipped Skills

- **`superpowers:using-git-worktrees` (worktree creation sub-step)**
  - **What was skipped**: The skill was invoked and its detection steps run, but the actual `EnterWorktree`/`git worktree add` was *not* performed; work proceeded on an in-place feature branch instead.
  - **Why this cycle**: The entire `openspec/` tree (config, the `superpowers-bridge` schema, and all change artifacts) plus `.claude/commands/opsx` were **untracked** at apply start (`git status` showed `?? openspec/`), and the change's `.openspec.yaml` embeds this repo's absolute path. A fresh worktree carries only committed history, so it would have contained none of the planning artifacts the executor must read, and `openspec` CLI commands would resolve against the wrong root.
  - **How to prevent recurrence**: `scope-judgment rule` — when the opsx change artifacts and schema are still untracked (first opsx cycle in a repo), branch in place; only use a worktree once the opsx scaffolding is committed. (Candidate for the adopter CLAUDE.md fragment — see §6.)

## 5. Surprises

- `.gitattributes` actively forces *opposite* line endings per file type (`*.sh`=LF, `*.ps1`=CRLF) with `core.autocrlf=true`. A byte-exact content hash is therefore inherently non-portable in this repo — an assumption ("hash the bytes") that would have silently passed locally and failed only in Linux CI.
- The `git show :file` blob for the `.sh` scripts showed CRLF despite `eol=lf` in `.gitattributes` — i.e. the committed blobs predate or bypassed normalization. Reinforced that normalization belongs in the hash, not in assumptions about repo state.
- A subagent asked to "run the skill" can stop partway (revise-docs updated CLAUDE.md but not README) — faithful evaluation needs the full documented process spelled out, not just the skill path.

## 6. Promote candidates → long-term learning

- [ ] 🟡 **First opsx cycle with untracked scaffolding → branch in place, not a worktree** → **Promote to** project CLAUDE.md (`CLAUDE.md` Workflow-routing section) and/or adopter fragment
  > **Why**: This cycle a worktree would have excluded the untracked `openspec/` artifacts and broken `openspec` CLI path resolution; the in-place branch was the only workable isolation.
  > **How to apply**: At `/opsx:apply` when `git status` shows the opsx scaffolding/change dir as untracked, choose an in-place feature branch over `EnterWorktree`.

- [ ] 🟡 **Content/identity hashes must normalize line endings in mixed-EOL repos** → **Promote to** memory (type: feedback)
  > **Why**: `.gitattributes` here forces per-type EOLs + autocrlf, so a byte-exact `source_hash` passed locally but would fail on Linux CI; normalization (commit 800e86a) fixed it.
  > **How to apply**: Whenever building a file-content hash that must agree across platforms/CI, normalize CRLF/CR→LF before hashing, and verify by hashing both an LF and a CRLF copy.

- [ ] 📌 **Run portability/format analysis before generating committed artifacts derived from file bytes** → **One-off** (process note)
  > **Why**: Backfilling 4 benchmarks before the EOL fix forced an immediate regeneration commit.
  > **How to apply**: When an artifact embeds a hash/checksum of repo files, settle the hashing rules before mass-generating the artifacts.

- [ ] 📌 **Integrity gates should validate internal consistency, not just a single scalar** → **Promote to** memory (type: feedback)
  > **Why**: The gate first accepted `pass_rate:1, results:[]`; a reviewer caught it (eea43d2). The headline number must be cross-checked against its supporting data.
  > **How to apply**: When a check trusts a committed metric, also assert the metric is derivable from committed evidence (non-empty results, derived ratio matches).
