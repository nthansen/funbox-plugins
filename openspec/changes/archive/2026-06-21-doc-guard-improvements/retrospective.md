# Retrospective: doc-guard-improvements

> Written: 2026-06-20 (after verify passed)
> Commit range: `25af52e..74bddf8` (change scope; full branch `e17979a..74bddf8`)
> Worktree: worked in place on `revise-docs-push-guard` (user declined a separate worktree)

---

## 0. Evidence

- **Commit range**: `25af52e..74bddf8` (11 commits, excludes the openspec-proposal commit `25af52e` itself)
- **Diff size**: +557 / -172 across 13 files
- **Tasks done**: 23/23
- **Active hours**: ~1 session (single sitting)
- **Subagent dispatches**: ~17 (3 implementers + 3 task reviewers + 2 fix subagents; eval engine: 3 executors + 3 graders + 1 failed re-run executor + 1 re-grader; 1 final whole-branch review)
- **New external dependencies**: none (skill-creator is an author-time eval tool, not a runtime dep)
- **Bugs encountered post-merge**: none (not yet merged)
- **OpenSpec validate state at archive**: pass (`openspec validate --strict --all` → 3/3)
- **Test coverage signal**: hook scenario harness 14/14; skill-gate 6/6 skills ≥ 0.9 (install-revise-hook 16/17, revise-docs 14/14, revise-docs-and-mark 7/7)

Commit chain (時序):

```
de9341b feat(doc-sweep): configurable push/commit trigger for the guard hook
7757e5f feat(doc-sweep): guard hook honors excludeDirs (skip vendored paths)
c43ca40 feat(doc-sweep): installer trigger choice, marker seeding, summary, reconfigure, vendor scan
de99f35 fix(doc-sweep): correct installer step refs + reconfigure matcher update
3fa150a feat(doc-sweep): revise-docs tracked-only discovery with vendor exclusion
d514418 feat(doc-sweep): wrapper owns a single review commit
98ed32f fix(doc-sweep): commit only doc paths in wrapper; clarify local-twin discovery
bf7a191 test(doc-sweep): eval cases for trigger, marker, summary, reconfigure, exclusion, single-commit
5258ed5 docs(doc-sweep): changelog for guard improvements
237d3ac test(doc-sweep): regenerate eval benchmarks for the 3 modified skills
74bddf8 chore(doc-sweep): drop inert SC2086 disable; mark change tasks complete
```

---

## 1. Wins

- [evidence: `de9341b`, `7757e5f`, test-revise-push-guard.sh 14/14] The hook tasks had a real bash scenario harness, so trigger and excludeDir behavior were genuinely TDD-tested (commit-mode ignores push; `vendor-extra` not matched by `vendor`).
- [evidence: `de99f35`, `98ed32f`] Per-task review caught two issues the implementers missed: a stale `(step 6)` cross-ref + a missing reconfigure matcher-update (installer), and `git add -A` sweeping in-flight non-doc edits (wrapper). Both are real correctness/UX bugs, fixed before the final review.
- [evidence: brainstorm.md Q1/Q3, design.md D1] Surfacing the commit-cadence + push-subsumption analysis during brainstorming turned an ambiguous "push and/or commit" ask into a cleaner "exactly one trigger" design.
- [evidence: skill-gate 6/6, benchmarks committed `237d3ac`] Benchmarks were regenerated from real with-skill eval runs + independent grading rather than hand-written.

## 2. Misses

- 🟡 [painful | evidence: skill-gate preflight, install-revise-hook benchmark 16/17] The installed skill-creator was initially a stripped copy missing the eval engine (`agents/grader.md`, `scripts/aggregate_benchmark.py`), blocking benchmark regen mid-pipeline until the user reinstalled it.
- 🟡 [painful | evidence: revise-docs-and-mark eval-1 first run] Subagent executors can't sandbox a skill that uses the Skill tool — the re-run invoked `revise-docs` against the *real* repo instead of the sandbox. Resolved by executing the eval's documented steps directly in a sandbox and re-grading.
- 📌 [nit | evidence: install-revise-hook eval 1 idempotency = fail] The eval executor stated rather than demonstrated the idempotent re-run, costing one assertion (16/17). Real, but a benchmark-demonstration gap, not a code gap.

## 3. Plan deviations

| Plan task | What changed | Why |
|-----------|--------------|-----|
| 1 + 2 | Combined into one hook implementer dispatch | Same file + same test harness; tightly coupled |
| 4 + 5 | Combined into one implementer dispatch | Both small SKILL edits, independent files |
| 6.3 | `/skill-gate` not runnable as-is | Installed skill-creator lacked the engine; ran executor+grader subagents directly via the engine once reinstalled |
| 7.2 worktree | Verified the invariant via a scratch repo + `git worktree`, not a full guard install in a worktree | The marker-sharing invariant (`--git-common-dir`) is the load-bearing part; full install adds nothing to the proof |

## 4. Skill / workflow compliance

| Skill                                            | Used |
|--------------------------------------------------|------|
| superpowers:brainstorming                        | ✓    |
| superpowers:writing-plans                        | ✓    |
| superpowers:using-git-worktrees                  | ✓ (ran; user chose work-in-place) |
| superpowers:subagent-driven-development          | ✓    |
| (transitive) superpowers:test-driven-development | ✓ (hook tasks; SKILL tasks validated via `claude plugin validate`) |
| (transitive) superpowers:requesting-code-review  | ✓    |
| superpowers:finishing-a-development-branch       | ✓ (pending — final step) |

### Deliberately Skipped Skills

- **`superpowers:using-git-worktrees` (worktree creation sub-step)**
  - **What was skipped**: Ran the skill, but did not create an isolated worktree — worked in place.
  - **Why this cycle**: The branch `revise-docs-push-guard` already existed for exactly this work and nothing else was in progress on it; the user explicitly chose "work in place" when asked.
  - **How to prevent recurrence**: `scope-judgment rule` — when already on the dedicated feature branch with a clean tree and explicit user consent to work in place, in-place is the correct call; no prevention needed.

## 5. Surprises

- The external `claude-md-management:revise-claude-md` is `Read/Edit/Glob` only (no git) — so the "we keep committing" problem was never the sub-skill; it was the orchestrating session committing piecemeal. This made the single-commit fix cleaner than feared (the wrapper can simply own it).
- Editing the bash hook does NOT invalidate any skill benchmark — the hook lives under `hooks/`, outside every skill's `source_hash` walk. That made the final SC2086 polish free.

## 6. Promote candidates → long-term learning

- [ ] 🟡 **funbox skill-gate needs the full skill-creator (engine files), not the stripped marketplace copy** → **Promote to project CLAUDE.md** (`CLAUDE.md` validation section)
  > **Why**: This cycle lost time when `/skill-gate` preflight failed because the installed skill-creator had only `SKILL.md`, missing `agents/grader.md` + `scripts/aggregate_benchmark.py`.
  > **How to apply**: Before regenerating benchmarks, verify those engine files exist under the skill-creator plugin; if missing, reinstall skill-creator first.

- [ ] 🟡 **Subagent executors can't sandbox skills that call the Skill tool** → **One-off** (record only)
  > **Why**: The eval re-run invoked `revise-docs` against the live repo, not the sandbox, because a subagent's Skill tool runs in the live session context.
  > **How to apply**: When eval-running a skill whose key behavior is "invokes another skill," execute the documented steps directly in the sandbox and grade that, rather than relying on a subagent to invoke the sub-skill in isolation.

- [ ] 📌 **Benchmark `source_hash` excludes files outside the skill dir** → **One-off**
  > **Why**: Hook edits under `hooks/` don't touch skill benchmarks, but SKILL.md edits do — knowing which edits invalidate which benchmark avoids needless regen.
  > **How to apply**: Before a late polish edit, check whether the file is inside a skill dir; if not, benchmarks are safe.
