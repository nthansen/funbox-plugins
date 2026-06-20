# revise-docs Push Guard Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** An opt-in `PreToolUse` hook that blocks a Claude-driven `git push` when documentation looks stale (non-doc files changed since the last `revise-docs` marker), prompting Claude to run `revise-docs` and commit before re-pushing.

**Architecture:** A pure-shell decision engine (`revise-push-guard.sh`) reads the PreToolUse stdin JSON, and for a `git push` denies (JSON `permissionDecision:"deny"`) iff a non-doc file changed in `marker..HEAD`, else allows. `revise-docs` advances the per-clone marker on completion (even with no changes) to close the loop. An opt-in, interactive installer skill copies the hook to a stable path, writes a small config, and idempotently merges the hook into the user's chosen `settings.json`.

**Tech Stack:** bash + **`node`** (for JSON parse/emit — present wherever Claude Code runs; **no `jq` dependency**) + `git`; Claude Code hooks (`PreToolUse`/`Bash`); doc-sweep skills are Markdown `SKILL.md`.

## Global Constraints

- Shell scripts MUST be **LF** line endings (`.gitattributes` `*.sh eol=lf`) and **ShellCheck-clean**; they pass `bash -n` and the validator danger-pattern scan.
- The hook parses/emits JSON via **`node`** (NOT `jq`) — `jq` is not guaranteed on a user's machine; `node` is (Claude Code is a Node CLI).
- `allowed-tools` in any SKILL.md MUST be **scoped** (no bare/wildcard `Bash`/`PowerShell`).
- The hook MUST **fail open**: any internal error ⇒ allow the push.
- No default activation: nothing registers a hook until the installer is run.
- Doc-file default set: `CLAUDE*.md`, `README*.md`, `CHANGELOG.md`, `docs/**`.
- Marker path: `$(git rev-parse --git-common-dir)/doc-sweep-revise-marker` (per-clone, not committed).
- Deny output: `{"hookSpecificOutput":{"hookEventName":"PreToolUse","permissionDecision":"deny","permissionDecisionReason":"…"}}`; allow = exit 0 with no stdout.

---

### Task 1: Hook decision engine + test harness

**Files:**
- Create: `plugins/doc-sweep/hooks/revise-push-guard.sh`
- Test: `plugins/doc-sweep/hooks/test-revise-push-guard.sh`

**Interfaces:**
- Produces: an executable hook invoked as `revise-push-guard.sh [CONFIG_JSON_PATH]`, reading the PreToolUse event JSON on **stdin**. Config JSON (optional) shape: `{"docMode":"default"|"with-skill"|"minimal","repoScope":"all"|"doc-sweep-only"}`. Defaults when absent: `docMode=default`, `repoScope=all`.
- Decision contract: prints nothing and exits 0 to **allow**; prints the deny JSON and exits 0 to **deny**.

- [ ] **Step 1: Write the failing test harness**

Create `plugins/doc-sweep/hooks/test-revise-push-guard.sh`:

```bash
#!/usr/bin/env bash
# Test harness for revise-push-guard.sh — builds temp git repos, feeds crafted
# PreToolUse stdin JSON, asserts allow (empty stdout) vs deny (JSON with "deny").
# Uses node (not jq) to build the stdin JSON, matching the hook.
set -uo pipefail
HOOK="$(cd "$(dirname "$0")" && pwd)/revise-push-guard.sh"
pass=0; fail=0
ok(){ pass=$((pass+1)); printf 'PASS %s\n' "$1"; }
no(){ fail=$((fail+1)); printf 'FAIL %s\n' "$1"; }

# run <name> <config-or-empty> <stdin-json> <expect: allow|deny>
run(){
  local name="$1" cfg="$2" json="$3" expect="$4" out
  out="$(printf '%s' "$json" | bash "$HOOK" $cfg 2>/dev/null)"
  if printf '%s' "$out" | grep -q '"permissionDecision":"deny"'; then
    [ "$expect" = deny ] && ok "$name" || no "$name (got deny, want allow)"
  else
    [ "$expect" = allow ] && ok "$name" || no "$name (got allow, want deny)"
  fi
}

mk_repo(){
  local d; d="$(mktemp -d)"
  git -C "$d" init -q
  git -C "$d" config user.email t@t; git -C "$d" config user.name t
  echo "# CLAUDE.md" > "$d/CLAUDE.md"
  git -C "$d" add -A; git -C "$d" commit -qm init
  echo "$d"
}
mark(){ local d="$1" gd; gd="$(git -C "$d" rev-parse --git-common-dir)"; case "$gd" in /*) :;; *) gd="$d/$gd";; esac; git -C "$d" rev-parse HEAD > "$gd/doc-sweep-revise-marker"; }
commitfile(){ local d="$1" f="$2"; mkdir -p "$d/$(dirname "$f")"; echo x >> "$d/$f"; git -C "$d" add -A; git -C "$d" commit -qm "change $f"; }
js(){ node -e 'process.stdout.write(JSON.stringify({tool_name:"Bash",cwd:process.argv[1],tool_input:{command:process.argv[2]}}))' "$1" "$2"; }

# 1. non-Bash → allow
run "non-bash" "" '{"tool_name":"Read","cwd":"/tmp","tool_input":{}}' allow
# 2. bash non-push → allow
R="$(mk_repo)"; run "non-push" "" "$(js "$R" 'git status')" allow
# 3. non-doc change since marker → deny
R="$(mk_repo)"; mark "$R"; commitfile "$R" src/app.js; run "non-doc-deny" "" "$(js "$R" 'git push')" deny
# 4. doc-only change since marker → allow
R="$(mk_repo)"; mark "$R"; commitfile "$R" README.md; run "doc-only-allow" "" "$(js "$R" 'git push origin main')" allow
# 5. bypass token → allow despite non-doc
R="$(mk_repo)"; mark "$R"; commitfile "$R" src/app.js; run "bypass" "" "$(js "$R" 'DOC_SWEEP_REVISE_SKIP=1 git push')" allow
# 6. doc-sweep-only self-skip in repo without markers → allow
R2="$(mktemp -d)"; git -C "$R2" init -q; git -C "$R2" config user.email t@t; git -C "$R2" config user.name t; echo x>"$R2/a.js"; git -C "$R2" add -A; git -C "$R2" commit -qm i
printf %s '{"docMode":"default","repoScope":"doc-sweep-only"}' > /tmp/cfg6.json
run "self-skip" "/tmp/cfg6.json" "$(js "$R2" 'git push')" allow
# 7. error/fail-open: cwd not a repo → allow
run "fail-open" "" "$(js "/nonexistent-xyz" 'git push')" allow

printf '\n%d passed, %d failed\n' "$pass" "$fail"
[ "$fail" -eq 0 ]
```

- [ ] **Step 2: Run the harness to verify it fails**

Run: `bash plugins/doc-sweep/hooks/test-revise-push-guard.sh`
Expected: FAIL — `revise-push-guard.sh` does not exist yet.

- [ ] **Step 3: Implement the hook**

Create `plugins/doc-sweep/hooks/revise-push-guard.sh`:

```bash
#!/usr/bin/env bash
# revise-push-guard.sh — Claude Code PreToolUse/Bash hook.
# Blocks `git push` when docs look stale: a non-doc file changed since the last
# revise-docs marker. Reads the event JSON on stdin. Usage:
#   revise-push-guard.sh [CONFIG_JSON_PATH]
# Allow = exit 0, no stdout. Deny = print hookSpecificOutput JSON, exit 0.
# Fails OPEN: any internal error allows the push. Uses `node` for JSON (no jq).
set -uo pipefail

allow(){ exit 0; }
emit_deny(){ # $1 = reason text
  node -e 'process.stdout.write(JSON.stringify({hookSpecificOutput:{hookEventName:"PreToolUse",permissionDecision:"deny",permissionDecisionReason:process.argv[1]}}))' "$1" 2>/dev/null
  exit 0
}

input="$(cat 2>/dev/null)" || allow
[ -n "$input" ] || allow

# Extract a dotted-path field from $input via node; exit 3 on parse error.
getfield(){
  printf '%s' "$input" | node -e 'let s="";process.stdin.on("data",d=>s+=d).on("end",()=>{try{const o=JSON.parse(s);const v=process.argv[1].split(".").reduce((a,k)=>(a==null?a:a[k]),o);process.stdout.write(v==null?"":String(v))}catch(e){process.exit(3)}})' "$1" 2>/dev/null
}

tool="$(getfield tool_name)" || allow
[ "$tool" = "Bash" ] || allow
cmd="$(getfield tool_input.command)" || allow
cwd="$(getfield cwd)" || allow

# Only gate git push (git, optional global flags, then the push subcommand).
printf '%s' "$cmd" | grep -Eq '(^|[^[:alnum:]_])git([[:space:]]+-[^[:space:]]+)*[[:space:]]+push([[:space:]]|$)' || allow
# Explicit bypass.
printf '%s' "$cmd" | grep -Eq 'DOC_SWEEP_REVISE_SKIP=1|--no-verify' && allow

# Config (optional) via node.
docmode="default"; reposcope="all"
cfg="${1:-}"
if [ -n "$cfg" ] && [ -f "$cfg" ]; then
  docmode="$(node -e 'try{process.stdout.write(JSON.parse(require("fs").readFileSync(process.argv[1],"utf8")).docMode||"default")}catch(e){process.stdout.write("default")}' "$cfg" 2>/dev/null || echo default)"
  reposcope="$(node -e 'try{process.stdout.write(JSON.parse(require("fs").readFileSync(process.argv[1],"utf8")).repoScope||"all")}catch(e){process.stdout.write("all")}' "$cfg" 2>/dev/null || echo all)"
fi

[ -n "$cwd" ] && [ -d "$cwd" ] || allow
cd "$cwd" 2>/dev/null || allow
git rev-parse --is-inside-work-tree >/dev/null 2>&1 || allow

# Self-skip: doc-sweep-only scope in a repo without doc-sweep markers.
if [ "$reposcope" = "doc-sweep-only" ]; then
  top="$(git rev-parse --show-toplevel 2>/dev/null || echo)"
  [ -n "$top" ] || allow
  { [ -f "$top/CLAUDE.md" ] || [ -f "$top/.claude/context/audience-rules.md" ]; } || allow
fi

# Resolve the review marker → range.
gcd="$(git rev-parse --git-common-dir 2>/dev/null)" || allow
case "$gcd" in /*) : ;; *) gcd="$(pwd)/$gcd" ;; esac
marker_file="$gcd/doc-sweep-revise-marker"
range=""
if [ -f "$marker_file" ]; then
  msha="$(tr -d '[:space:]' < "$marker_file" 2>/dev/null)"
  if [ -n "$msha" ] && git cat-file -e "${msha}^{commit}" 2>/dev/null; then
    range="${msha}..HEAD"
  fi
fi
if [ -z "$range" ]; then
  base="$(git merge-base HEAD origin/HEAD 2>/dev/null || git merge-base HEAD origin/main 2>/dev/null || echo)"
  [ -n "$base" ] && range="${base}..HEAD" || allow   # can't determine → fail open
fi

changed="$(git diff --name-only "$range" 2>/dev/null)" || allow
[ -n "$changed" ] || allow   # nothing new since marker

is_doc(){ # $1 = path; doc per $docmode
  case "$docmode" in
    minimal)
      case "$1" in CLAUDE.md|*/CLAUDE.md|README.md|*/README.md) return 0;; esac ;;
    with-skill)
      case "$1" in SKILL.md|*/SKILL.md) return 0;; esac
      case "$1" in CLAUDE*.md|*/CLAUDE*.md|README*.md|*/README*.md|CHANGELOG.md|*/CHANGELOG.md|docs/*|*/docs/*) return 0;; esac ;;
    *) # default
      case "$1" in CLAUDE*.md|*/CLAUDE*.md|README*.md|*/README*.md|CHANGELOG.md|*/CHANGELOG.md|docs/*|*/docs/*) return 0;; esac ;;
  esac
  return 1
}

nondoc=""
while IFS= read -r f; do
  [ -n "$f" ] || continue
  is_doc "$f" || nondoc="$nondoc $f"
done <<EOF
$changed
EOF

if [ -n "$nondoc" ]; then
  emit_deny "Docs may be stale — non-doc file(s) changed since the last revise-docs run:${nondoc}. Run /doc-sweep:revise-docs to capture this session's doc learnings, commit any changes, then push again. (Add DOC_SWEEP_REVISE_SKIP=1 before the command, or --no-verify, to bypass.)"
fi
allow
```

- [ ] **Step 4: Run the harness to verify it passes**

Run: `bash plugins/doc-sweep/hooks/test-revise-push-guard.sh`
Expected: `7 passed, 0 failed`.

- [ ] **Step 5: ShellCheck + syntax** (CI has shellcheck; if absent locally, note it and rely on CI)

Run: `shellcheck plugins/doc-sweep/hooks/revise-push-guard.sh plugins/doc-sweep/hooks/test-revise-push-guard.sh && bash -n plugins/doc-sweep/hooks/revise-push-guard.sh`
Expected: no output, exit 0. The `$nondoc` and `$cfg` word-splits are intentional — add a targeted `# shellcheck disable=SC2086` only where flagged.

- [ ] **Step 6: Ensure LF, commit**

```bash
cd /c/git/funbox-plugins
git add plugins/doc-sweep/hooks/revise-push-guard.sh plugins/doc-sweep/hooks/test-revise-push-guard.sh
git commit -m "$(printf 'feat(doc-sweep): add revise-push-guard PreToolUse hook + tests (node, no jq)\n\nCo-Authored-By: Claude Opus 4.8 (1M context) <noreply@anthropic.com>')"
```

---

### Task 2: Snapshot wrapper — revise-docs-and-mark (SUPERSEDED framing)

> **Design B (final):** the snapshot is owned by the **guard**, not the base skill.
> Instead of editing `revise-docs`, create a wrapper skill
> `plugins/doc-sweep/skills/revise-docs-and-mark/SKILL.md` that invokes the *unchanged*
> `doc-sweep:revise-docs` via the Skill tool and then writes the marker (HEAD) to
> `$(git rev-parse --git-common-dir)/doc-sweep-revise-marker` (even with no doc changes).
> `revise-docs` is left untouched. The marker-write command below is unchanged; only its
> home moved from revise-docs into the wrapper. See design.md §D4 and the spec's
> "Snapshot owned by a guard wrapper" requirement.

**Files:**
- Create: `plugins/doc-sweep/skills/revise-docs-and-mark/SKILL.md` (the wrapper)
- (NOT modified: `plugins/doc-sweep/skills/revise-docs/SKILL.md` — stays as-is)

**Interfaces:**
- Produces: a documented final step that writes HEAD to `$(git rev-parse --git-common-dir)/doc-sweep-revise-marker`, which Task 1's hook reads.

- [ ] **Step 1: Add the marker step to the skill**

Append to `plugins/doc-sweep/skills/revise-docs/SKILL.md` (after the README.md process step):

```markdown
## After updating docs — advance the review marker

So the optional push-time guard (`/doc-sweep:install-revise-hook`) can tell reviewed
history from unreviewed, record that this session reviewed docs up to the current
commit — **even if you made no doc changes** (that still means "reviewed to here,
nothing needed"):

​```sh
git rev-parse HEAD > "$(git rev-parse --git-common-dir)/doc-sweep-revise-marker"
​```

Run this as the final step, after any doc commits. The marker lives inside the git
directory (per-clone, not committed) and is inert if the guard is not installed.
```

(Replace the `​```` fences above with real triple backticks when writing the file.)

- [ ] **Step 2: Verify the documented command works**

Run (scratch repo):
```bash
d=$(mktemp -d); git -C "$d" init -q; git -C "$d" config user.email t@t; git -C "$d" config user.name t; (cd "$d" && echo x>f && git add -A && git commit -qm i && git rev-parse HEAD > "$(git rev-parse --git-common-dir)/doc-sweep-revise-marker" && test "$(cat "$(git rev-parse --git-common-dir)/doc-sweep-revise-marker")" = "$(git rev-parse HEAD)" && echo MARKER_OK)
```
Expected: `MARKER_OK`.

- [ ] **Step 3: Commit**

```bash
cd /c/git/funbox-plugins
git add plugins/doc-sweep/skills/revise-docs/SKILL.md
git commit -m "$(printf 'feat(doc-sweep): revise-docs advances the review marker on completion\n\nCo-Authored-By: Claude Opus 4.8 (1M context) <noreply@anthropic.com>')"
```

---

### Task 3: Opt-in interactive installer skill

**Files:**
- Create: `plugins/doc-sweep/skills/install-revise-hook/SKILL.md`

**Interfaces:**
- Consumes: the hook script from Task 1 (copies it to a stable path). Produces: a `PreToolUse`/`Bash` entry in the user's settings.json referencing `COPIED_HOOK_PATH CONFIG_PATH`, and a config JSON `{docMode,repoScope}`.

- [ ] **Step 1: Write the installer SKILL.md**

Create `plugins/doc-sweep/skills/install-revise-hook/SKILL.md`:

````markdown
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
   ​```json
   {
     "matcher": "Bash",
     "hooks": [
       { "type": "command", "command": "<ABS_HOOK_PATH> <ABS_CONFIG_PATH>" }
     ]
   }
   ​```
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
````

(Replace the `​```` inner fences with real triple backticks when writing the file.)

- [ ] **Step 2: Validate frontmatter + policy**

Run: `node scripts/validate-marketplace.mjs`
Expected: `✓ funbox validation passed` (scoped `allowed-tools`; name matches dir).

- [ ] **Step 3: Commit**

```bash
cd /c/git/funbox-plugins
git add plugins/doc-sweep/skills/install-revise-hook/SKILL.md
git commit -m "$(printf 'feat(doc-sweep): add opt-in install-revise-hook installer skill\n\nCo-Authored-By: Claude Opus 4.8 (1M context) <noreply@anthropic.com>')"
```

---

### Task 4: Docs + final verification

**Files:**
- Modify: `plugins/doc-sweep/README.md`, `plugins/doc-sweep/CHANGELOG.md`

- [ ] **Step 1: Document the guard in the plugin README**

Add a section to `plugins/doc-sweep/README.md` (human-facing): what the push guard does,
that it's opt-in via `/doc-sweep:install-revise-hook`, the four scope choices, the
bypass token, the "only Claude-driven pushes" + "needs node" caveats, and how to
uninstall. Usage-focused (no Claude-only internals).

- [ ] **Step 2: Update the CHANGELOG**

Add an entry to `plugins/doc-sweep/CHANGELOG.md` noting the new opt-in push guard +
installer and the `revise-docs` marker behavior.

- [ ] **Step 3: Full local gate suite**

Run:
```bash
cd /c/git/funbox-plugins
bash plugins/doc-sweep/hooks/test-revise-push-guard.sh
find plugins -name '*.sh' -print0 | xargs -0 -n1 bash -n
node scripts/validate-marketplace.mjs
node scripts/check-openspec-hygiene.mjs
```
Expected: hook tests `7 passed, 0 failed`; `bash -n` clean; validator passes; hygiene clean. (Run `shellcheck plugins/doc-sweep/hooks/*.sh` too if available; otherwise CI covers it.)

- [ ] **Step 4: Manual end-to-end (throwaway repo)**

In a scratch repo with the hook wired to a local settings.json: a non-doc commit →
`git push` denied with the reason; run the marker command (simulating revise-docs) →
push allowed; doc-only commit → allowed; `DOC_SWEEP_REVISE_SKIP=1 git push` → allowed;
uninstall → push ungated. Record observed outcomes.

- [ ] **Step 5: Commit**

```bash
cd /c/git/funbox-plugins
git add plugins/doc-sweep/README.md plugins/doc-sweep/CHANGELOG.md
git commit -m "$(printf 'docs(doc-sweep): document the opt-in revise-docs push guard\n\nCo-Authored-By: Claude Opus 4.8 (1M context) <noreply@anthropic.com>')"
```

---

## Self-Review

- **Spec coverage:** Installer (Task 3) ↔ "Opt-in interactive installer"; hook deny/allow (Task 1) ↔ "Push-time staleness gate"; marker (Task 2) ↔ "Marker advanced by revise-docs"; self-skip/bypass/fail-open (Task 1 + tests 5–7) ↔ "Self-skip, bypass, and fail-open"; no-default-activation ↔ `disable-model-invocation` installer + inert marker; doc-file set ↔ `docMode` (`is_doc`). All requirements mapped.
- **Placeholders:** none — hook + harness code complete; SKILL.md content complete (inner fences noted).
- **Type/name consistency:** config keys `docMode`/`repoScope`, marker `doc-sweep-revise-marker`, copied hook `doc-sweep-revise-push.sh`, bypass `DOC_SWEEP_REVISE_SKIP=1`, deny-JSON shape, and **node (not jq)** for JSON are consistent across Tasks 1–4.
