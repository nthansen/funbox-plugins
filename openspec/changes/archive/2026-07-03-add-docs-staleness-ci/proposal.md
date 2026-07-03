## Why

doc-sweep's only drift guard today is a local `PreToolUse` push hook: it catches **only
Claude-driven pushes, only in the clone where it's installed**. It structurally cannot enforce
docs review on human commits, on contributors who don't run doc-sweep, or on **any pull request
from a fork**. A PR-time CI check is the one layer that catches everyone — and doc-sweep, being
the documentation-drift plugin, is the natural home for it.

## What Changes

- **New CI docs-staleness check.** A deterministic (no-LLM, no API secret) script that, on a
  pull request, fails when non-doc files changed but no doc file changed — *unless* the author
  acknowledges "docs considered, none needed." Baseline is the PR's **merge base**, so it needs
  no committed marker or state file.
- **Explicit ack token** so a legitimate bug fix is never a hard blocker: a single
  `[skip docs]` token (mirroring the familiar `[skip ci]` convention) placed in **any commit
  message in the PR range** *or* in the **PR body** (the forgot-it fallback, editable in-browser
  with no history rewrite) — or an actual doc change (implicit pass).
- **New manual install skill** `install-docs-ci` (`disable-model-invocation: true`, mirroring
  `install-revise-hook`) that scaffolds a `.github/workflows/*.yml` into a user's repo calling a
  doc-sweep-shipped script; supports reconfigure/uninstall.
- **Unify the existing push-guard's ack vocabulary** with the CI check: the same `[skip docs]`
  token that clears CI also clears the local hook, so the two guards speak one language.
- **Reposition the push-guard as optional/secondary** (CI becomes the primary guard). The hook
  stays shipped; **funbox itself stops requiring it** locally. Retiring the hook entirely is a
  deliberately deferred follow-up, recorded as a note — not done in this change.
- funbox **dogfoods** the new check (adds the workflow to this repo).

Non-goals (out of scope): removing/deleting the push-guard hook; any LLM-in-CI judgement;
`vscode-thinking-display`; release/changelog automation.

## Capabilities

### New Capabilities
- `docs-staleness-ci`: a PR-time, deterministic docs-vs-code drift check plus its manual
  installer skill and shipped script; defines the pass/fail logic, the ack vocabulary, and the
  install/reconfigure/uninstall contract.

### Modified Capabilities
- `revise-docs-push-guard`: the local hook SHALL recognize the shared `[skip docs]` ack
  token defined by `docs-staleness-ci`, and is repositioned as an optional secondary guard
  (funbox no longer requires it). No change to its marker/snapshot mechanism.

## Impact

- **New files**: `plugins/doc-sweep/hooks/docs-ci-check.sh` (+ a test harness alongside the
  existing `test-revise-push-guard.sh`), `plugins/doc-sweep/skills/install-docs-ci/SKILL.md`,
  a scaffolded workflow under funbox's own `.github/workflows/`.
- **Modified**: doc-sweep `README.md`/`CHANGELOG.md`; the push-guard hook script + its spec
  (shared ack); funbox `.claude/settings.json` (drop the required local hook); funbox `CLAUDE.md`
  (document CI guard + deferred-retirement note).
- **Validation surface**: new skill must pass `claude plugin validate`, the marketplace policy
  validator (scoped `allowed-tools`), and its `/skill-gate` benchmark; new shell must pass
  `bash -n` + ShellCheck. No new dependencies, no new secrets.
