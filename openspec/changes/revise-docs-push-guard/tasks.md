## 1. Hook script (the decision engine)

- [ ] 1.1 Create `plugins/doc-sweep/hooks/revise-push-guard.sh` (LF, `set -uo pipefail`, **`node`** for stdin JSON — no `jq`) — read `tool_name`, `tool_input.command`, `cwd` from stdin
- [ ] 1.2 Early-allow when `tool_name` != `Bash` or the command is not a `git push`
- [ ] 1.3 Early-allow on bypass token in the command (`DOC_SWEEP_REVISE_SKIP=1` or `--no-verify`)
- [ ] 1.4 Resolve repo from `cwd`; when repo-scope is "doc-sweep-only", allow if no `.claude/context/audience-rules.md` and no `CLAUDE.md`
- [ ] 1.5 Read marker at `$(git -C <cwd> rev-parse --git-common-dir)/doc-sweep-revise-marker`; compute changed files `marker..HEAD` (fallback `merge-base origin/<default>..HEAD` when marker absent/invalid)
- [ ] 1.6 Load doc-glob set from config (default `CLAUDE*.md`,`README*.md`,`CHANGELOG.md`,`docs/**`); deny via JSON `permissionDecision:deny` + reason if any changed path is non-doc, else allow
- [ ] 1.7 Wrap all logic so any error → allow (fail-open) with a one-line stderr note
- [ ] 1.8 ShellCheck-clean; passes `bash -n` and the validator danger-pattern scan

## 2. Hook unit tests

- [ ] 2.1 Add a test harness (feed crafted stdin JSON + a temp git repo) covering: non-Bash/non-push → allow; doc-only change → allow; non-doc change → deny; missing marker → fallback; bypass token → allow; doc-sweep-only self-skip → allow; git/marker error → fail-open
- [ ] 2.2 Assert the deny output is valid `hookSpecificOutput` JSON with a `permissionDecisionReason` naming the offending file(s)

## 3. revise-docs marker

- [ ] 3.1 Modify `plugins/doc-sweep/skills/revise-docs/SKILL.md` to write HEAD to `$(git rev-parse --git-common-dir)/doc-sweep-revise-marker` on completion, including when no doc changes are made
- [ ] 3.2 State the marker path + "advance even with no changes" rationale in the skill so the loop-closure is explicit

## 4. Installer skill

- [ ] 4.1 Create `plugins/doc-sweep/skills/install-revise-hook/SKILL.md` (`disable-model-invocation: true`, scoped `allowed-tools`)
- [ ] 4.2 Interactively collect the four scoping choices (settings location; repo applicability; doc-file set; bypass/uninstall) with recommended defaults
- [ ] 4.3 Copy the hook script to a stable absolute path (user-global → `~/.claude/hooks/…`; project → `${CLAUDE_PROJECT_DIR}/.claude/hooks/…`) and write the config (`doc-sweep-revise.json`: `docGlobs`, `repoScope`)
- [ ] 4.4 Idempotently merge the `PreToolUse`/`Bash` entry into the chosen settings.json (append; never clobber); detect an existing install and offer update/uninstall
- [ ] 4.5 Implement uninstall (remove entry + copied script + config)

## 5. Docs & packaging

- [ ] 5.1 Update `plugins/doc-sweep/README.md` — opt-in install/uninstall, what it guards, bypass, "only Claude-driven pushes" caveat
- [ ] 5.2 Update `plugins/doc-sweep/CHANGELOG.md`
- [ ] 5.3 Confirm `node scripts/validate-marketplace.mjs` passes (scoped allowed-tools, danger-scan, required docs)

## 6. Verification

- [ ] 6.1 Run the hook unit tests — all pass
- [ ] 6.2 Manual end-to-end in a throwaway repo: install → make a non-doc commit → `git push` is denied → run revise-docs (marker advances) → push allowed; doc-only commit → push allowed; bypass token → allowed; uninstall → push ungated
- [ ] 6.3 Full local gate suite green (validate-marketplace, shellcheck, openspec validate + hygiene)
