# Retrospective: revise-docs-push-guard

> Written: 2026-06-20 (after verify passed)
> Commit range: `e17979a..HEAD`
> Worktree: branch `revise-docs-push-guard` (in-place; no worktree — see §4)

---

## 0. Evidence

- **Commit range**: `e17979a..7868f8f` (10 commits)
- **Diff size**: +1208 / -3 across 16 files (incl. carried doc fix + opsx artifacts)
- **Tasks done**: 23/23
- **Active hours**: part of one continuous session
- **Subagent dispatches**: ~6 (1 hook implementer, 1 hook reviewer, 1 regex-fix, 3 doc/skill implementers, 1 final whole-branch review)
- **New external dependencies**: none (hook uses `node` + `git`; no `jq`)
- **Bugs encountered post-merge**: none (pre-merge)
- **OpenSpec validate state at archive**: pass (`openspec validate --all` → 2 passed)
- **Test coverage signal**: `test-revise-push-guard.sh` 11/11; validator + openspec-hygiene (modulo the transient unarchived flag, §2) pass

Commit chain (chronological):

```
4e40ef6 docs: capture session learnings (revise-docs)        [carried from prior cycle]
bf7de70 docs(revise-docs-push-guard): add change proposal (brainstorm→plan)
4e78f0e docs(...): drop jq for node in hook
26f601a feat(doc-sweep): add revise-push-guard hook + tests (node, no jq)
d14eeba fix(doc-sweep): detect git push behind space-separated global opts + tests
64b1e2f feat(doc-sweep): revise-docs advances the review marker        [later superseded]
b1e2cc0 feat(doc-sweep): add install-revise-hook installer skill
296865f docs(doc-sweep): document the opt-in push guard
6b10906 refactor(doc-sweep): decouple revise-docs marker from the guard
7868f8f refactor(doc-sweep): snapshot owned by revise-docs-and-mark wrapper (design B)
```

---

## 1. Wins

- [§0] Prior-art research (user-prompted) **prevented building a whole generic `push-gate` plugin** that would have reinvented `hookify` (Claude PreToolUse pattern-block) + pre-commit/Husky/Lefthook (terminal pre-push). Scope stayed a focused doc-sweep feature.
- [commit 4e78f0e] The **jq→node** design issue was caught at apply pre-flight (jq absent on the machine) — *before* shipping a hook that would silently fail-open (never guard) on jq-less machines.
- [commit d14eeba] Task review caught a real **`git -C <dir> push` regex false-negative**; verified empirically and fixed (and disproved the reviewer's companion "docs/** depth" finding with a test).
- [hook + 11-case harness] The executable core is genuinely TDD-tested and fails-open by construction (verified across error paths in the final review → SHIP).

## 2. Misses

- 🟡 [painful | commits 64b1e2f→6b10906→7868f8f] **Three design pivots on the marker's home** (in revise-docs → decoupled framing → wrapper-owned) churned the same code/artifacts repeatedly. The wrapper (design B) was reachable from the brainstorm; the staleness-vs-ownership question wasn't fully resolved before implementing Task 2.
- 🟡 [painful | self-inflicted] The **openspec-hygiene "completed-but-unarchived" check I shipped in PR #4** fails locally during this very apply (tasks 23/23 but not yet archived) — a transient window between task-completion and archive that the guard treats as a defect. Process friction from my own tool.
- 📌 [nit | §7] Installer settings.json merge + the wrapper are **skill-as-instructions, not unit-tested** — inherent to skills, but a residual correctness gap.

## 3. Plan deviations

| Plan task | What changed | Why |
|---|---|---|
| Global (jq) | Hook + tests use `node`, not `jq` | jq not guaranteed on user machines (absent here); would silently fail-open |
| Task 2 (revise-docs marker) | Replaced by wrapper skill `revise-docs-and-mark`; revise-docs left pure | Design B (user): snapshot mechanism abstracted from the base skill |
| (whole change) | Considered then rejected a generic `push-gate` plugin | Prior-art research: would reinvent hookify + pre-commit/husky/lefthook |

## 4. Skill / workflow compliance

| Skill | Used |
|---|---|
| superpowers:brainstorming | ✓ |
| superpowers:writing-plans | ✓ |
| superpowers:using-git-worktrees | ✓ (ran; chose in-place branch) |
| superpowers:subagent-driven-development | ✓ |
| (transitive) superpowers:test-driven-development | ✓ |
| (transitive) superpowers:requesting-code-review | ✓ (per-task + final whole-branch) |
| superpowers:finishing-a-development-branch | ✓ (pending — final step) |

### Deliberately Skipped Skills

- **`superpowers:using-git-worktrees` (worktree creation sub-step)**
  - **What was skipped**: detection ran; the worktree was not created — worked in-place on the feature branch.
  - **Why this cycle**: the change artifacts (and the carried doc commit `4e40ef6`) are committed only on this local branch, not `origin/main`; a fresh worktree (default base `origin/main`) would lack them, and openspec metadata embeds absolute paths. Same condition as the prior cycle's retrospective.
  - **How to prevent recurrence**: `scope-judgment rule` — when the opsx change artifacts live only on the local feature branch (not yet on origin/main), branch in place. (Recurring across cycles → candidate to encode in the schema's apply instruction or the adopter CLAUDE.md.)

## 5. Surprises

- A guard I shipped last cycle (openspec-hygiene unarchived check) **bit the very next cycle** mid-apply. Tools that gate "completed but unarchived" need to tolerate the in-flight apply window (tasks done, archive imminent), or the apply order must mark tasks complete only at/after archive.
- The "generic mechanism" instinct was strong and reasonable, but the ecosystem is crowded (hookify; three mature git-hook managers). The novel slice (git-marker staleness + Claude-in-loop action) is genuinely small.

## 6. Promote candidates → long-term learning

- [ ] 🟡 **Resolve "where does state live (skill vs wrapper)" before implementing, not after** → **Promote to** memory (type: feedback)
  > **Why**: three pivots on the marker's home (64b1e2f→6b10906→7868f8f) re-churned code/artifacts.
  > **How to apply**: in brainstorming, when a feature adds state/IO to an existing component, decide ownership (in-component vs wrapper-over) as an explicit fork before writing the plan.

- [ ] 🟡 **"Don't reinvent the wheel" research belongs in brainstorming, before propose** → **Promote to** project CLAUDE.md (workflow routing)
  > **Why**: the prior-art check (hookify, pre-commit/husky/lefthook) arrived only after a full propose+apply pivot toward a generic plugin; doing it during brainstorming would have pre-empted the detour. (The repo already values this — CLAUDE.local.md "considered & rejected".)
  > **How to apply**: for any "build a general mechanism / new plugin" idea, run an ecosystem prior-art search during brainstorming and record the result before /opsx:propose.

- [ ] 🟡 **openspec-hygiene unarchived-check should tolerate the in-apply window** → **Promote to** a follow-up change on `scripts/check-openspec-hygiene.mjs`
  > **Why**: it fails locally between task-completion and archive within a normal apply, flagging a non-defect.
  > **How to apply**: only flag "completed-but-unarchived" when there is no `verify.md` (or it's FAIL), so a change mid-cycle (verify written, archive imminent) isn't reported.

- [ ] 📌 **Hooks that run on user machines must not assume `jq`** → **Promote to** memory (type: feedback)
  > **Why**: jq absent here would have made the guard silently fail-open; `node` is reliably present where Claude Code runs.
  > **How to apply**: when writing a shell hook that ships to users, parse JSON with `node`, not `jq`.
