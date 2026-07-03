## 1. Shipped check script

- [x] 1.1 Create `plugins/doc-sweep/hooks/docs-ci-check.sh` (LF; `#!/usr/bin/env bash`, `set -euo pipefail`) that: resolves the merge base, lists changed files, classifies doc vs non-doc vs excluded using the default doc-set (`CLAUDE*.md`, `README*.md`, `CHANGELOG.md`, `docs/**`), and exits non-zero only when non-doc changed, no doc changed, and no ack is present
- [x] 1.2 Parse the GitHub event + diff with `node` (not `jq`); read config for doc-set/excluded overrides consistent with the push-guard's config shape
- [x] 1.3 Recognize the `[skip docs]` ack in any commit message in the PR range OR in the PR body; treat any doc-set change as an implicit pass
- [x] 1.4 On failure, print a message naming the offending non-doc paths and every way to clear it (update docs, or add `[skip docs]` to a commit message or the PR body)
- [x] 1.5 Add `plugins/doc-sweep/hooks/test-docs-ci-check.sh` covering the scenario matrix: code-only→fail; code+docs→pass; docs-only→pass; excluded-only→pass; commit-message ack→pass; PR-body ack→pass
- [x] 1.6 Confirm `bash -n` and ShellCheck pass on both scripts (keep them LF per `.gitattributes`)

## 2. Install skill

- [x] 2.1 Create `plugins/doc-sweep/skills/install-docs-ci/SKILL.md` with `disable-model-invocation: true` and scoped `allowed-tools` (mirroring `install-revise-hook`)
- [x] 2.2 Implement fresh-install flow: collect doc-set/excluded choices, scaffold a `pull_request` workflow into `.github/workflows/` that invokes the shipped check script, and print the structured summary (workflow path, doc-set, `[skip docs]` token, branch-protection note, reconfigure/uninstall instructions)
- [x] 2.3 Implement idempotent detect + Reconfigure / Uninstall / Cancel; ensure re-run does not duplicate the workflow and uninstall removes only the scaffolded workflow
- [x] 2.4 Add the skill's `/`-command entry so it is invocable as `/doc-sweep:install-docs-ci`

## 3. Unify the push-guard ack

- [x] 3.1 Update `plugins/doc-sweep/hooks/revise-push-guard.sh` to additionally allow when every non-doc commit in the gated range carries `[skip docs]` in its commit message (keep existing `DOC_SWEEP_REVISE_SKIP=1` / `--no-verify` bypass and fail-open behavior)
- [x] 3.2 Extend `plugins/doc-sweep/hooks/test-revise-push-guard.sh` with a `[skip docs]`-clears-the-hook case; re-run `bash -n` + ShellCheck

## 4. Dogfood in funbox

- [x] 4.1 Scaffold the docs-staleness workflow into funbox's own `.github/workflows/` (or add it as a job) wired to the shipped check script
- [x] 4.2 Remove the required local revise-docs push hook from funbox `.claude/settings.json` (CI becomes the primary guard)
- [x] 4.3 Update funbox `CLAUDE.md`: document the CI docs guard + the `[skip docs]` token, and add a "considered / revisit-if" note that retiring the push-guard hook is a deferred decision pending experience with CI

## 5. Docs, quality gate, validation

- [x] 5.1 Update `plugins/doc-sweep/README.md` (new CI check + install skill + `[skip docs]`) and `CHANGELOG.md`
- [x] 5.2 Generate the `install-docs-ci` skill's `evals/benchmark.json` via `/skill-gate` so it clears the threshold; confirm `node scripts/check-skill-gate.mjs` passes
- [x] 5.3 Run `node scripts/validate-marketplace.mjs`, `claude plugin validate plugins/doc-sweep`, and `openspec validate --strict --all`; fix any findings
- [x] 5.4 Verify `node scripts/check-openspec-hygiene.mjs` is clean, then archive the change with `/opsx:archive`
