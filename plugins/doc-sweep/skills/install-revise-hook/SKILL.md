---
name: install-revise-hook
description: Install (or remove) an opt-in push/commit-time guard that prompts /doc-sweep:revise-docs-and-mark before `git push` or `git commit` when docs look stale. Use to set up, reconfigure, or uninstall the revise-docs push/commit hook.
allowed-tools:
  - Read
  - Write
  - Edit
  - AskUserQuestion
  - Bash(git rev-parse*)
  - Bash(mkdir -p*)
  - Bash(cp *)
  - Bash(rm -f*)
  - Bash(git config*)
  - Bash(git submodule*)
  - Bash(git ls-files*)
disable-model-invocation: true
---

# Install the revise-docs push/commit guard

Set up an opt-in Claude Code `PreToolUse` hook that blocks a `git push` (or `git commit`,
if configured) when documentation looks stale (a non-doc file changed since docs were last
reviewed), prompting you to run `/doc-sweep:revise-docs-and-mark` first (it reviews docs via
the unchanged `revise-docs` skill, then records the review snapshot the hook checks).
**Nothing is installed until you run this and confirm.** The hook uses `node` (not `jq`) to
parse the event JSON.

## Steps

1. **Detect an existing install.** Look for a `revise-push-guard` entry in the user
   (`~/.claude/settings.json`) and project (`${CLAUDE_PROJECT_DIR}/.claude/settings.json`)
   hooks by scanning for any `command` value that contains `doc-sweep-revise-push.sh`.

   - If **no install** is found → proceed to step 2 (fresh install).
   - If an install **is found**, offer three choices via `AskUserQuestion`:
     - **Reconfigure** — re-ask all choices from step 2 pre-filled with the values read from
       the existing config JSON; then rewrite the config (re-copy the hook script only if the
       target path changed); leave the review marker file untouched; print the structured
       summary (step 6). Stop.
     - **Uninstall** — follow the Uninstall section below. Stop.
     - **Cancel** — do nothing and exit. Stop.

2. **Collect scope (AskUserQuestion).** Ask all of the following in one prompt, with
   recommended defaults called out:

   - **Settings location** — user-global (`~/.claude/settings.json`, guards every repo) vs
     this project (`${CLAUDE_PROJECT_DIR}/.claude/settings.json`). Recommend user-global for
     shared setups; project for per-repo opt-in.
   - **Repo applicability** — `all` (guard fires in every repo) vs `doc-sweep-only` (the hook
     self-skips repos without a `CLAUDE.md` or `.claude/context/audience-rules.md`). Recommend
     `doc-sweep-only` for user-global installs.
   - **Doc-file set** — `default` (CLAUDE*.md, README*.md, CHANGELOG.md, docs/**),
     `with-skill` (also treats SKILL.md as a doc), or `minimal` (CLAUDE.md + README.md only).
     Recommend `default`.
   - **Trigger event** — exactly one of: `push` (recommended; one prompt per share) or
     `commit` (stricter; prompts on nearly every commit). Record as `trigger` in the config.
   - **Bypass + uninstall** — confirm the bypass tokens (`DOC_SWEEP_REVISE_SKIP=1` or
     `--no-verify`) and that re-running this skill can reconfigure or uninstall.

3. **Copy the hook to a stable path.** From this skill's bundle, copy
   `../../hooks/revise-push-guard.sh` to:
   - user-global → `~/.claude/hooks/doc-sweep-revise-push.sh`
   - project → `${CLAUDE_PROJECT_DIR}/.claude/hooks/doc-sweep-revise-push.sh`

   (`mkdir -p` the `hooks/` dir first.) Use an absolute path; do not rely on
   `${CLAUDE_PLUGIN_ROOT}` expanding inside settings.json.

4. **Scan for vendored directories and persist `excludeDirs`.**

   Before writing the config, check whether `.claude/context/audience-rules.md` already
   contains an `excludeDirs` list (look for a line matching `^excludeDirs:`). If it does,
   read the list silently — no prompt needed. If it does not:

   a. Scan the repository for likely-vendored directories using three signals:
      - **Git submodules**: run `git config --file .gitmodules --get-regexp path` (if
        `.gitmodules` exists) to extract submodule paths.
      - **Non-root package manifests**: run `git ls-files` and filter for files named
        `package.json`, `composer.json`, `Cargo.toml`, `go.mod`, `Gemfile`, `requirements.txt`,
        `pyproject.toml`, `pom.xml`, or `build.gradle` that are **not** at the repo root
        (i.e. their dirname is not `.`). Collect their parent directories.
      - **Known vendor names**: check whether any of `vendor`, `third_party`, `Pods`,
        `bower_components`, `node_modules` exist as directories at the repo root.

   b. De-duplicate the candidates and present them to the user via `AskUserQuestion`:
      list each candidate and ask which to exclude. The user may remove any, add others,
      or confirm all.

   c. Persist the confirmed list as an `excludeDirs` block in
      `.claude/context/audience-rules.md`. If the file already exists, append the block
      (do not overwrite unrelated content); if it does not exist, create it with a brief
      header comment explaining the purpose. Format:

      ```
      excludeDirs:
        - vendor
        - third_party
      ```

5. **Write the config** next to the copied hook as `doc-sweep-revise.json`:
   ```json
   { "docMode": "<chosen>", "repoScope": "<chosen>", "trigger": "<chosen>", "excludeDirs": [<confirmed>] }
   ```
   The `excludeDirs` array must match the list persisted in step 4.

6. **Merge the hook into settings.json (idempotent).** Read the chosen settings.json
   (create `{}` if absent). Under `.hooks.PreToolUse`, append (do not overwrite) one
   matcher block:
   ```json
   {
     "matcher": "Bash",
     "hooks": [
       { "type": "command", "command": "<ABS_HOOK_PATH> <ABS_CONFIG_PATH>" }
     ]
   }
   ```
   If a command containing `doc-sweep-revise-push.sh` already exists under any
   `PreToolUse` matcher, leave it unchanged (no duplicate). Preserve all other settings
   and hooks exactly.

7. **Seed the review marker (fresh install only).** Ask via `AskUserQuestion` — three
   choices:

   - **Seed now** → run `git rev-parse HEAD` and write its output to
     `"$(git rev-parse --git-common-dir)/doc-sweep-revise-marker"`. Report that this
     records HEAD as reviewed by assumption — no actual doc review was performed.
   - **Review now** → invoke `/doc-sweep:revise-docs-and-mark` (this performs a real doc
     review, commits any changes, and records the marker properly).
   - **Leave unseeded** → warn that the next guarded `git push` or `git commit` (depending
     on the configured trigger) will block until a marker exists or the bypass token is used.

8. **Print a structured summary.**

   ```
   revise-docs push/commit guard installed
   ─────────────────────────────────────────
   Settings file : <abs path to settings.json>
   Hook script   : <abs path to doc-sweep-revise-push.sh>
   Config file   : <abs path to doc-sweep-revise.json>
   Trigger       : <push|commit>
   Doc-file set  : <default|with-skill|minimal>
   Repo scope    : <all|doc-sweep-only>
   Excluded dirs : <comma-separated list, or "(none)">
   Marker state  : <seeded at <SHA> (assumption) | seeded by revise-docs-and-mark | unseeded (next gated action will block)>

   Caveats
   • Only Claude-driven git calls are gated (a terminal push won't trigger PreToolUse).
   • The hook requires `node` on PATH; it fails open (allows the action) on any error.
   • Project-scoped installs are per-worktree — clone a new worktree and re-run to guard it.

   Bypass tokens : DOC_SWEEP_REVISE_SKIP=1  (env prefix)  |  --no-verify  (flag)
   Edit/uninstall: re-run /doc-sweep:install-revise-hook
   ```

## Uninstall

Remove the `PreToolUse` matcher block whose `command` value contains
`doc-sweep-revise-push.sh` from the settings.json where it was found, then delete the
copied hook script and its config JSON. Leave all other settings, hooks, and the review
marker file untouched. Confirm what was removed (settings file path, hook path, config
path). The marker file is intentionally left in place so a reinstall can seed from it or
ignore it.
