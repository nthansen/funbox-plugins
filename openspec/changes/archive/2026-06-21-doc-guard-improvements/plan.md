# doc-staleness guard improvements — Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Make the doc-sweep staleness guard installer flexible and self-explanatory, keep doc review/guard inside repo boundaries, and produce a single review commit.

**Architecture:** Four files change in concert — the hook (`revise-push-guard.sh`) gains a configurable trigger and `excludeDirs` honoring; the installer SKILL gains a trigger question, marker-seeding, a structured summary, a reconfigure flow, and a vendor scan; `revise-docs` switches to tracked-only discovery; `revise-docs-and-mark` takes ownership of a single commit. Config is a JSON file beside the copied hook plus an `excludeDirs` list persisted in the tracked overlay `.claude/context/audience-rules.md`.

**Tech Stack:** Bash (POSIX-ish, `node` for JSON, no `jq`), Claude Code SKILL.md (frontmatter + prose), JSON config, the repo's `validate-marketplace.mjs` + `check-skill-gate.mjs` + `openspec` CLI, ShellCheck.

## Global Constraints

- `allowed-tools` MUST be scoped — no bare or wildcard `Bash`/`PowerShell` (validator-enforced).
- The hook stays `node`-only (no `jq`), deterministic, and fails OPEN on any error.
- `*.sh`, `.githooks/*`, `Makefile` stay LF (`.gitattributes`); do not introduce CRLF.
- Preserve the intentional `# shellcheck disable=SC2086` lines in the hook.
- Plugins omit `version` in `plugin.json` (rolling `main`) — do not add one.
- Keep the copied hook filename `doc-sweep-revise-push.sh` (no rename).
- Hook config gains `trigger` (`"push"` default | `"commit"`) and `excludeDirs` (string array).
- Marker path is always `"$(git rev-parse --git-common-dir)/doc-sweep-revise-marker"`.
- Bypass tokens unchanged: `DOC_SWEEP_REVISE_SKIP=1`, `--no-verify`.
- Validation gates that must pass at the end: `node scripts/validate-marketplace.mjs`; `claude plugin validate` per plugin; `bash -n` + ShellCheck on the hook; `npx @fission-ai/openspec@1.4.1 validate --strict --all`; `node scripts/check-skill-gate.mjs`.

---

### Task 1: Hook — configurable trigger

**Files:**
- Modify: `plugins/doc-sweep/hooks/revise-push-guard.sh` (trigger read + subcommand match + deny text, around lines 30, 35-40, 96)
- Test: `plugins/doc-sweep/hooks/test-revise-push-guard.sh` (new scenario harness)

**Interfaces:**
- Consumes: event JSON on stdin (`tool_name`, `tool_input.command`, `cwd`); config path as `$1`.
- Produces: config field `trigger` (`"push"`|`"commit"`, default `"push"`); deny JSON via existing `emit_deny`.

- [ ] **Step 1: Write the failing scenario test**

Create `plugins/doc-sweep/hooks/test-revise-push-guard.sh` — a self-contained harness that builds a throwaway git repo, writes a config, and pipes synthetic events into the hook:

```bash
#!/usr/bin/env bash
# Scenario tests for revise-push-guard.sh. Run: bash test-revise-push-guard.sh
set -uo pipefail
HOOK="$(cd "$(dirname "$0")" && pwd)/revise-push-guard.sh"
fail=0
mkrepo(){ d="$(mktemp -d)"; ( cd "$d" && git init -q && git config user.email a@b.c && git config user.name t \
  && echo x > f.txt && git add . && git commit -qm init ) ; echo "$d"; }
event(){ # $1=cmd $2=cwd
  node -e 'process.stdout.write(JSON.stringify({tool_name:"Bash",tool_input:{command:process.argv[1]},cwd:process.argv[2]}))' "$1" "$2"; }
run(){ event "$1" "$2" | bash "$HOOK" "$3" 2>/dev/null; }
assert_deny(){ [ -n "$1" ] && echo "ok: $2" || { echo "FAIL(expected deny): $2"; fail=1; }; }
assert_allow(){ [ -z "$1" ] && echo "ok: $2" || { echo "FAIL(expected allow): $2"; fail=1; }; }

# commit-trigger: a git push must be IGNORED
repo="$(mkrepo)"; cfg="$repo/cfg.json"; echo '{"trigger":"commit"}' > "$cfg"
( cd "$repo" && echo y > new.js && git add . && git commit -qm feat )
out="$(run 'git push' "$repo" "$cfg")"; assert_allow "$out" "commit-trigger ignores push"

exit $fail
```

- [ ] **Step 2: Run it to verify it fails**

Run: `bash plugins/doc-sweep/hooks/test-revise-push-guard.sh`
Expected: the "commit-trigger ignores push" case FAILs (hook currently always treats push as the trigger).

- [ ] **Step 3: Implement the trigger read + subcommand match**

In `revise-push-guard.sh`, after the config block (after line 40), add `trigger`:

```sh
trigger="push"
if [ -n "$cfg" ] && [ -f "$cfg" ]; then
  trigger="$(node -e 'try{process.stdout.write(JSON.parse(require("fs").readFileSync(process.argv[1],"utf8")).trigger||"push")}catch(e){process.stdout.write("push")}' "$cfg" 2>/dev/null || echo push)"
fi
```

Replace the hard-coded push grep (line 30) with a trigger-driven match:

```sh
case "$trigger" in
  commit) sub='commit' ;;
  *)      sub='push' ;;
esac
printf '%s' "$cmd" | grep -Eq "(^|[^[:alnum:]_])git([[:space:]]+-[^[:space:]]*([[:space:]]+[^-[:space:]][^[:space:]]*)?)*[[:space:]]+${sub}([[:space:]]|$)" || allow
```

- [ ] **Step 4: Make the deny message name the gated verb**

In `emit_deny` call (line 96) build the verb from `$trigger`:

```sh
verb="push"; [ "$trigger" = "commit" ] && verb="commit"
emit_deny "Docs may be stale — non-doc file(s) changed since docs were last reviewed:${nondoc}. Run /doc-sweep:revise-docs-and-mark to review docs and record the review snapshot, commit any changes, then ${verb} again. (Add DOC_SWEEP_REVISE_SKIP=1 before the command, or --no-verify, to bypass.)"
```

- [ ] **Step 5: Run the scenario test + ShellCheck + bash -n**

Run: `bash plugins/doc-sweep/hooks/test-revise-push-guard.sh && bash -n plugins/doc-sweep/hooks/revise-push-guard.sh && shellcheck plugins/doc-sweep/hooks/revise-push-guard.sh`
Expected: test PASSes; `bash -n` clean; ShellCheck clean (preserve existing SC2086 disables).

- [ ] **Step 6: Commit**

```bash
git add plugins/doc-sweep/hooks/revise-push-guard.sh plugins/doc-sweep/hooks/test-revise-push-guard.sh
git commit -m "feat(doc-sweep): configurable push/commit trigger for the guard hook"
```

---

### Task 2: Hook — honor excludeDirs

**Files:**
- Modify: `plugins/doc-sweep/hooks/revise-push-guard.sh` (config read + `is_doc`/loop, lines 35-92)
- Test: `plugins/doc-sweep/hooks/test-revise-push-guard.sh` (add cases)

**Interfaces:**
- Consumes: config field `excludeDirs` (JSON string array).
- Produces: changed files under an excluded dir are dropped before classification.

- [ ] **Step 1: Add failing tests for exclusion**

Append to the harness two cases (push trigger, default config plus excludeDirs):

```bash
# excluded vendored source change must NOT block
repo="$(mkrepo)"; cfg="$repo/cfg.json"; echo '{"trigger":"push","excludeDirs":["vendor"]}' > "$cfg"
git -C "$repo" rev-parse HEAD > "$(git -C "$repo" rev-parse --git-common-dir)/doc-sweep-revise-marker"
( cd "$repo" && mkdir -p vendor/lib && echo z > vendor/lib/main.js && git add . && git commit -qm vendor )
out="$(run 'git push' "$repo" "$cfg")"; assert_allow "$out" "excluded vendor source does not block"

# first-party non-doc still blocks even with an excluded README also changed
( cd "$repo" && echo a > app.js && echo b > vendor/lib/README.md && git add . && git commit -qm mix )
out="$(run 'git push' "$repo" "$cfg")"; assert_deny "$out" "vendor README does not satisfy doc review"
```

- [ ] **Step 2: Run to verify the new cases fail**

Run: `bash plugins/doc-sweep/hooks/test-revise-push-guard.sh`
Expected: the two new cases FAIL (hook ignores `excludeDirs`).

- [ ] **Step 3: Read excludeDirs from config**

After the `trigger` read, add:

```sh
excludes="$(node -e 'try{const a=JSON.parse(require("fs").readFileSync(process.argv[1],"utf8")).excludeDirs;process.stdout.write(Array.isArray(a)?a.join("\n"):"")}catch(e){}' "$cfg" 2>/dev/null || echo)"
```

- [ ] **Step 4: Drop excluded paths in the classification loop**

In the `while read -r f` loop (lines 86-92), before `is_doc`, skip excluded paths:

```sh
skip=0
if [ -n "$excludes" ]; then
  while IFS= read -r ex; do
    [ -n "$ex" ] || continue
    case "$f" in "$ex"/*|"$ex") skip=1; break;; esac
  done <<EX
$excludes
EX
fi
[ "$skip" = 1 ] && continue
```

- [ ] **Step 5: Run tests + ShellCheck + bash -n**

Run: `bash plugins/doc-sweep/hooks/test-revise-push-guard.sh && bash -n plugins/doc-sweep/hooks/revise-push-guard.sh && shellcheck plugins/doc-sweep/hooks/revise-push-guard.sh`
Expected: all cases PASS; clean ShellCheck/`bash -n`.

- [ ] **Step 6: Commit**

```bash
git add plugins/doc-sweep/hooks/revise-push-guard.sh plugins/doc-sweep/hooks/test-revise-push-guard.sh
git commit -m "feat(doc-sweep): guard hook honors excludeDirs (skip vendored paths)"
```

---

### Task 3: Installer — trigger, marker, summary, reconfigure, scan

**Files:**
- Modify: `plugins/doc-sweep/skills/install-revise-hook/SKILL.md` (frontmatter + steps 1-6 + Uninstall)

**Interfaces:**
- Consumes: `AskUserQuestion`, `git rev-parse --git-common-dir`, the copied hook + config paths.
- Produces: config JSON with `trigger` + `excludeDirs`; `excludeDirs` in `.claude/context/audience-rules.md`; marker (optionally seeded); a structured summary.

- [ ] **Step 1: Generalize wording + frontmatter**

In the frontmatter `description`, change "push-time guard" → "push/commit-time guard". Keep `disable-model-invocation: true`. Add any newly-needed scoped tools for writing the overlay (Edit/Write already present).

- [ ] **Step 2: Add the Trigger event question**

In step 2 (Collect scope), add a fifth bullet:

```markdown
- **Trigger event** — exactly one of: `push` (recommended; one prompt per share) or
  `commit` (stricter; prompts on nearly every commit). Record as `trigger` in the config.
```

- [ ] **Step 3: Write trigger into the config**

Update step 4 so the config JSON is `{ "docMode": "<chosen>", "repoScope": "<chosen>", "trigger": "<chosen>", "excludeDirs": [<confirmed>] }`.

- [ ] **Step 4: Add the vendor scan-confirm-persist sub-step**

Add a new step (before writing config) describing: scan for git submodules (`git config --file .gitmodules --get-regexp path` / `.gitmodules`), directories with a non-root package manifest (`package.json`, `composer.json`, `Cargo.toml`, etc.), and known names (`vendor`, `third_party`, `Pods`, `bower_components`); present candidates via `AskUserQuestion`; persist the confirmed list as an `excludeDirs` block in `.claude/context/audience-rules.md` (create/append) and mirror it into the hook config.

- [ ] **Step 5: Add the marker-seeding step (fresh install only)**

Add a step after the settings merge:

```markdown
N. **Seed the review marker (fresh install).** Ask (AskUserQuestion): seed now / review now /
   leave. Seed now → `git rev-parse HEAD > "$(git rev-parse --git-common-dir)/doc-sweep-revise-marker"`
   and report it's an assumption (no review performed). Review now → invoke
   `/doc-sweep:revise-docs-and-mark`. Leave → warn the next guarded action blocks.
```

- [ ] **Step 6: Replace the Report step with a structured summary**

Rewrite step 6 to always print: settings file, hook path, config path, trigger, doc-set, repo scope, marker state, caveats (Claude-driven git only, needs `node`, fails open, project-scoped installs are per-worktree), bypass tokens, and "re-run `/doc-sweep:install-revise-hook` to edit/uninstall."

- [ ] **Step 7: Flesh out the reconfigure flow**

Rewrite step 1 (Detect) so an existing install offers Reconfigure / Uninstall / Cancel: Reconfigure re-asks pre-filled, rewrites the config (matcher only if hook path changed), leaves the marker alone, then prints the summary.

- [ ] **Step 8: Validate the SKILL frontmatter**

Run: `claude plugin validate plugins/doc-sweep`
Expected: valid (no bare Bash, frontmatter parses).

- [ ] **Step 9: Commit**

```bash
git add plugins/doc-sweep/skills/install-revise-hook/SKILL.md
git commit -m "feat(doc-sweep): installer trigger choice, marker seeding, summary, reconfigure, vendor scan"
```

---

### Task 4: revise-docs — tracked-only discovery + exclusions

**Files:**
- Modify: `plugins/doc-sweep/skills/revise-docs/SKILL.md` (frontmatter `allowed-tools`; README discovery step 47)

**Interfaces:**
- Consumes: `git ls-files`, `.claude/context/audience-rules.md` `excludeDirs`.
- Produces: a discovery procedure that is tracked-only + local-twin inclusion + exclusion-aware.

- [ ] **Step 1: Add the tool**

In `allowed-tools`, add `Bash(git ls-files*)` (keep the list scoped).

- [ ] **Step 2: Rewrite the README discovery step**

Replace the `**/README.md` glob (line 47) with:

```markdown
- Discover docs from tracked files: `git ls-files '*README.md' 'README.md'` (honors .gitignore,
  so node_modules/dist drop out). Also include local twins if present on disk:
  `audience-rules.local.md`, `CLAUDE.local.md`, `*.local.md`. Then drop any path under an
  `excludeDirs` entry read from `.claude/context/audience-rules.md`. Never blanket-include
  untracked files. If `excludeDirs` is absent on first run, run the scan-confirm-persist flow.
```

- [ ] **Step 3: Validate**

Run: `claude plugin validate plugins/doc-sweep`
Expected: valid.

- [ ] **Step 4: Commit**

```bash
git add plugins/doc-sweep/skills/revise-docs/SKILL.md
git commit -m "feat(doc-sweep): revise-docs tracked-only discovery with vendor exclusion"
```

---

### Task 5: revise-docs-and-mark — single commit

**Files:**
- Modify: `plugins/doc-sweep/skills/revise-docs-and-mark/SKILL.md` (frontmatter + steps)

**Interfaces:**
- Consumes: `revise-docs` (edits only), `git add`, `git commit`, `git rev-parse`.
- Produces: exactly one doc commit per review, then the advanced marker.

- [ ] **Step 1: Add commit tools**

In `allowed-tools`, add `Bash(git add*)` and `Bash(git commit*)` (keep scoped).

- [ ] **Step 2: Rewrite the commit/marker steps**

Make step 2 explicit: after `revise-docs` finishes, stage all doc changes and make **one** commit (skip if nothing changed); then write `git rev-parse HEAD` to the common-dir marker. State that `revise-docs`/`revise-claude-md` stay edit-only.

- [ ] **Step 3: Validate**

Run: `claude plugin validate plugins/doc-sweep`
Expected: valid.

- [ ] **Step 4: Commit**

```bash
git add plugins/doc-sweep/skills/revise-docs-and-mark/SKILL.md
git commit -m "feat(doc-sweep): wrapper owns a single review commit"
```

---

### Task 6: Evals + skill-gate

**Files:**
- Modify: `plugins/doc-sweep/skills/install-revise-hook/evals/evals.json`
- Modify: `plugins/doc-sweep/skills/revise-docs/evals/evals.json` (create if absent)
- Modify: `evals/benchmark.json` (regenerated via `/skill-gate`)

**Interfaces:**
- Consumes: the `/skill-gate` command (needs `skill-creator`), `check-skill-gate.mjs`.
- Produces: updated, hash-verified benchmark passing the threshold.

- [ ] **Step 1: Extend install-revise-hook evals**

Add eval entries asserting: a trigger choice is collected and written to config; the marker step is offered/seeded; a structured summary with edit/uninstall guidance is printed; an existing install offers reconfigure; the vendor scan persists `excludeDirs`.

- [ ] **Step 2: Add/extend revise-docs evals**

Add assertions: discovery uses `git ls-files` (tracked-only); gitignored deps excluded; local twins included; `excludeDirs` honored.

- [ ] **Step 3: Regenerate the benchmark**

Run the `/skill-gate` command for `install-revise-hook` and `revise-docs` to (re)generate `evals/benchmark.json`.

- [ ] **Step 4: Run the gate**

Run: `node scripts/check-skill-gate.mjs`
Expected: every touched skill ≥ threshold (0.9 default).

- [ ] **Step 5: Commit**

```bash
git add plugins/doc-sweep/skills/*/evals/evals.json evals/benchmark.json
git commit -m "test(doc-sweep): evals for trigger, marker, summary, reconfigure, exclusion"
```

---

### Task 7: Validate, worktree verify, changelog

**Files:**
- Modify: `plugins/doc-sweep/CHANGELOG.md`
- Modify: `openspec/changes/doc-guard-improvements/verify.md` (during /opsx:verify)

**Interfaces:**
- Consumes: all repo validators.
- Produces: a green tree and a recorded worktree verification.

- [ ] **Step 1: Run the full validation suite**

Run: `node scripts/validate-marketplace.mjs && claude plugin validate plugins/doc-sweep && bash -n plugins/doc-sweep/hooks/revise-push-guard.sh && shellcheck plugins/doc-sweep/hooks/revise-push-guard.sh && npx --yes @fission-ai/openspec@1.4.1 validate --strict --all && node scripts/check-skill-gate.mjs`
Expected: all pass.

- [ ] **Step 2: Verify worktree behavior manually**

In a scratch clone: `git worktree add ../wt-test`; install the guard (project scope) in the worktree; confirm the marker resolves to the main `.git` (shared) and `excludeDirs` from the tracked overlay applies. Note results for `verify.md`.

- [ ] **Step 3: Update the changelog**

Add a CHANGELOG entry summarizing: configurable trigger, marker seeding, structured summary + reconfigure, vendor/external exclusion, single review commit, worktree note.

- [ ] **Step 4: Commit**

```bash
git add plugins/doc-sweep/CHANGELOG.md
git commit -m "docs(doc-sweep): changelog for guard improvements"
```

---

## Self-Review

- **Spec coverage:** `revise-docs-push-guard` MODIFIED (installer/trigger → Tasks 1,3; gate → Tasks 1,2; wrapper single-commit → Task 5) and `doc-scope-exclusion` ADDED (tracked-only discovery → Task 4; scan/persist → Task 3; hook honors list → Task 2). Worktree requirement → Task 7 Step 2. All requirements map to a task.
- **Placeholder scan:** no TBD/TODO; every code step shows the actual snippet or command.
- **Type/name consistency:** config keys (`trigger`, `excludeDirs`, `docMode`, `repoScope`), marker path (`$(git rev-parse --git-common-dir)/doc-sweep-revise-marker`), and bypass tokens are used identically across Tasks 1-7.
