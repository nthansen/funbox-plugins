## Why

doc-sweep's `revise-docs` captures a session's doc learnings but is manual and easy to
forget — a recent change merged with an un-filled spec Purpose for exactly that reason.
The natural moment to run it is session wrap-up (`git push`), not every commit. We want
an opt-in guard that nudges `revise-docs` at push time when docs look stale, and that
gets any generated doc files committed into the push. Hooks can't run the model, so the
mechanism is block-and-remind with Claude in the loop.

## What Changes

**revise-docs marker**
- From: `revise-docs` only edits docs.
- To: on completion it also advances a per-clone marker (HEAD SHA) at
  `$(git rev-parse --git-common-dir)/doc-sweep-revise-marker`, even when it makes no
  doc changes.
- Reason: lets a deterministic shell hook tell reviewed history from unreviewed.
- Impact: non-breaking; the marker is inert unless the hook is installed.

**New opt-in installer skill**
- A manual `doc-sweep:install-revise-hook` skill (`disable-model-invocation: true`)
  that interactively (AskUserQuestion) collects four scoping choices — settings
  location, repo applicability, doc-file set, bypass/uninstall — copies the hook script
  to a stable path, writes a small config, and idempotently merges a `PreToolUse`/`Bash`
  hook into the chosen `settings.json`. Re-run updates or uninstalls.

**New bundled hook script**
- `hooks/revise-push-guard.sh`: on a `git push`, denies (with a message to run
  `revise-docs`, commit, then push) iff a non-doc file changed since the marker; allows
  otherwise; self-skips non-doc-sweep repos; honors a bypass token; fails open.

## Capabilities

### New Capabilities
- `revise-docs-push-guard`: An opt-in, interactive installer plus a deterministic
  `PreToolUse` hook that blocks a Claude-driven `git push` when documentation looks
  stale (non-doc files changed since the last `revise-docs` marker), prompting Claude to
  run `revise-docs` and commit before re-pushing; includes the marker that `revise-docs`
  advances to close the loop, repo self-skip, a bypass token, fail-open behavior, and
  uninstall.

### Modified Capabilities
<!-- None at the spec level. revise-docs gains marker-writing behavior, but doc-sweep
has no existing OpenSpec capability spec to amend; it's covered by the new capability's
requirements. -->

## Impact

- **New files:** `plugins/doc-sweep/skills/install-revise-hook/SKILL.md`,
  `plugins/doc-sweep/hooks/revise-push-guard.sh`, hook unit tests.
- **Modified files:** `plugins/doc-sweep/skills/revise-docs/SKILL.md` (marker write),
  `plugins/doc-sweep/README.md` + `CHANGELOG.md` (opt-in install/uninstall docs).
- **Tooling/CI:** the new shell script is covered by existing gates (validate-marketplace
  scoped `allowed-tools` + danger-scan, `bash -n`, ShellCheck, LF via `.gitattributes`).
- **Runtime:** no default behavior change — nothing activates until a user opts in via
  the installer. Only Claude-driven pushes are affected; raw-terminal pushes are out of
  scope.
- **Dependencies:** none new (pure shell + `jq`, which the hook contract already uses).
