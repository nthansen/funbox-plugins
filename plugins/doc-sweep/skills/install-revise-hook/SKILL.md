---
name: install-revise-hook
description: Install (or remove) an opt-in push-time guard that prompts /doc-sweep:revise-docs before `git push` when docs look stale. Use to set up, reconfigure, or uninstall the revise-docs push hook.
allowed-tools:
  - Read
  - Write
  - Edit
  - AskUserQuestion
  - Bash(git rev-parse*)
  - Bash(mkdir -p*)
  - Bash(cp *)
  - Bash(rm -f*)
disable-model-invocation: true
---

# Install the revise-docs push guard

Set up an opt-in Claude Code `PreToolUse` hook that blocks a `git push` when
documentation looks stale (a non-doc file changed since the last `revise-docs` run),
prompting you to run `/doc-sweep:revise-docs` first. **Nothing is installed until you
run this and confirm.** The hook uses `node` (not `jq`) to parse the event JSON.

## Steps

1. **Detect an existing install.** Look for a `revise-push-guard` entry in the user
   (`~/.claude/settings.json`) and project (`${CLAUDE_PROJECT_DIR}/.claude/settings.json`)
   hooks. If present, offer **update** or **uninstall** before a fresh install.

2. **Collect scope (AskUserQuestion).** Ask, with recommended defaults:
   - **Settings location** — user-global (`~/.claude/settings.json`, guards every repo)
     vs this project (`${CLAUDE_PROJECT_DIR}/.claude/settings.json`).
   - **Repo applicability** — all repos vs doc-sweep-enabled only (the hook self-skips
     repos without a `CLAUDE.md` or `.claude/context/audience-rules.md`). Recommend
     "doc-sweep-enabled only" for user-global installs.
   - **Doc-file set** — `default` (CLAUDE*/README*/CHANGELOG/docs), `with-skill`
     (also treat SKILL.md as a doc), or `minimal` (CLAUDE.md + README.md only).
   - **Bypass + uninstall** — confirm the bypass token (`DOC_SWEEP_REVISE_SKIP=1` or
     `--no-verify`) and that re-running this skill can uninstall.

3. **Copy the hook to a stable path.** From this skill's bundle, copy
   `../../hooks/revise-push-guard.sh` to:
   - user-global → `~/.claude/hooks/doc-sweep-revise-push.sh`
   - project → `${CLAUDE_PROJECT_DIR}/.claude/hooks/doc-sweep-revise-push.sh`
   (`mkdir -p` the `hooks/` dir first.) Use an absolute path; do not rely on
   `${CLAUDE_PLUGIN_ROOT}` expanding inside settings.json.

4. **Write the config** next to the copied hook (e.g. `doc-sweep-revise.json`):
   `{ "docMode": "<chosen>", "repoScope": "<chosen>" }`.

5. **Merge the hook into settings.json (idempotent).** Read the chosen settings.json
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
   If an identical `revise-push-guard` command already exists, leave it (no duplicate).
   Preserve all other settings and hooks exactly.

6. **Report** the install: which settings file, the hook + config paths, the scope, and
   how to bypass/uninstall. Remind the user that only **Claude-driven** `git push`
   calls are gated (a raw terminal push won't trigger a `PreToolUse` hook), and that the
   hook needs `node` on PATH (it fails open — allows the push — if anything errors).

## Uninstall

Remove the appended `PreToolUse` matcher block whose command references
`doc-sweep-revise-push.sh`, then delete the copied hook script and its config. Leave
all other settings untouched. Confirm what was removed.
