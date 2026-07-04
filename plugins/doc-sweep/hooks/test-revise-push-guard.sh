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
assert_deny(){ if [ -n "$1" ]; then echo "ok: $2"; else echo "FAIL(expected deny): $2"; fail=1; fi; }
assert_allow(){ if [ -z "$1" ]; then echo "ok: $2"; else echo "FAIL(expected allow): $2"; fail=1; fi; }

mark(){ local d="$1" gd; gd="$(git -C "$d" rev-parse --git-common-dir)"; case "$gd" in /*) :;; *) gd="$d/$gd";; esac; git -C "$d" rev-parse HEAD > "$gd/doc-sweep-revise-marker"; }
commitfile(){ local d="$1" f="$2"; mkdir -p "$d/$(dirname "$f")"; echo x >> "$d/$f"; git -C "$d" add -A; git -C "$d" commit -qm "change $f"; }
no_cfg=""

# --- baseline cases ---

# 1. non-Bash tool → allow
repo="$(mkrepo)"
out="$(printf '%s' '{"tool_name":"Read","cwd":"/tmp","tool_input":{}}' | bash "$HOOK" "$no_cfg" 2>/dev/null)"
assert_allow "$out" "non-bash tool allows"

# 2. bash non-push command → allow
repo="$(mkrepo)"
out="$(run 'git status' "$repo" "$no_cfg")"; assert_allow "$out" "non-push bash allows"

# 3. non-doc change since marker → deny
repo="$(mkrepo)"; mark "$repo"; commitfile "$repo" src/app.js
out="$(run 'git push' "$repo" "$no_cfg")"; assert_deny "$out" "non-doc change denies push"

# 4. doc-only change since marker → allow
repo="$(mkrepo)"; mark "$repo"; commitfile "$repo" README.md
out="$(run 'git push origin main' "$repo" "$no_cfg")"; assert_allow "$out" "doc-only change allows push"

# 5. bypass token DOC_SWEEP_REVISE_SKIP=1 → allow despite non-doc
repo="$(mkrepo)"; mark "$repo"; commitfile "$repo" src/app.js
out="$(run 'DOC_SWEEP_REVISE_SKIP=1 git push' "$repo" "$no_cfg")"; assert_allow "$out" "DOC_SWEEP_REVISE_SKIP bypass allows"

# 6. doc-sweep-only self-skip in repo without CLAUDE.md markers → allow
repo2="$(mktemp -d)"; git -C "$repo2" init -q; git -C "$repo2" config user.email t@t; git -C "$repo2" config user.name t
echo x > "$repo2/a.js"; git -C "$repo2" add -A; git -C "$repo2" commit -qm i
cfg6="$(mktemp)"; echo '{"repoScope":"doc-sweep-only"}' > "$cfg6"
out="$(run 'git push' "$repo2" "$cfg6")"; assert_allow "$out" "doc-sweep-only self-skip"

# 7. error/fail-open: cwd not a repo → allow
out="$(run 'git push' "/nonexistent-xyz" "$no_cfg")"; assert_allow "$out" "fail-open on bad cwd"

# 8. git -C <path> push (global flag) with non-doc change → deny
repo="$(mkrepo)"; mark "$repo"; commitfile "$repo" src/app.js
out="$(run "git -C $repo push" "$repo" "$no_cfg")"; assert_deny "$out" "git -C flag push denies"

# 9. --no-verify bypass → allow despite non-doc
repo="$(mkrepo)"; mark "$repo"; commitfile "$repo" src/app.js
out="$(run 'git push --no-verify' "$repo" "$no_cfg")"; assert_allow "$out" "--no-verify bypass allows"

# 10. multi-level docs-only change → allow
repo="$(mkrepo)"; mark "$repo"; commitfile "$repo" docs/api/ref.md
out="$(run 'git push' "$repo" "$no_cfg")"; assert_allow "$out" "deep docs/ path allows push"

# 11. custom docPatterns: CHANGELOG no longer in the doc set → deny (docMode is retired;
#     this is the docPatterns equivalent of the old "minimal" docMode)
repo="$(mkrepo)"; mark "$repo"; commitfile "$repo" CHANGELOG.md
cfg11="$(mktemp)"; echo '{"repoScope":"all","docPatterns":["**/CLAUDE*.md","**/README*.md"]}' > "$cfg11"
out="$(run 'git push' "$repo" "$cfg11")"; assert_deny "$out" "custom docPatterns: CHANGELOG is non-doc"

# --- Task 1: configurable trigger ---

# commit-trigger: a git push must be IGNORED even when non-doc files changed since marker
repo="$(mkrepo)"; cfg="$(mktemp)"; echo '{"trigger":"commit"}' > "$cfg"
mark "$repo"
( cd "$repo" && echo y > new.js && git add . && git commit -qm feat )
out="$(run 'git push' "$repo" "$cfg")"; assert_allow "$out" "commit-trigger ignores push"

# --- Task 2: excludeDirs ---

# excluded vendored source change must NOT block
repo="$(mkrepo)"; cfg="$(mktemp)"; echo '{"trigger":"push","excludeDirs":["vendor"]}' > "$cfg"
mark "$repo"
( cd "$repo" && mkdir -p vendor/lib && echo z > vendor/lib/main.js && git add . && git commit -qm vendor )
out="$(run 'git push' "$repo" "$cfg")"; assert_allow "$out" "excluded vendor source does not block"

# first-party non-doc still blocks even with an excluded README also changed
( cd "$repo" && echo a > app.js && echo b > vendor/lib/README.md && git add . && git commit -qm mix )
out="$(run 'git push' "$repo" "$cfg")"; assert_deny "$out" "vendor README does not satisfy doc review"

# --- shared [skip docs] acknowledgment clears the hook (parity with the CI check) ---

# non-doc change whose commit message carries [skip docs] → allow
repo="$(mkrepo)"; mark "$repo"
( cd "$repo" && echo y > new.js && git add . && git commit -qm "fix: bug [skip docs]" )
out="$(run 'git push' "$repo" "$no_cfg")"; assert_allow "$out" "[skip docs] in commit message allows push"

# a later un-acked non-doc commit still blocks (token must be present in the range)
commitfile "$repo" other.js
out="$(run 'git push' "$repo" "$no_cfg")"; assert_deny "$out" "un-acked later non-doc commit still denies"

# --- shared classifier (doc-classify.mjs) parity regressions ---

# .claude markdown-only change since marker → allow (regression)
repo="$(mkrepo)"; mark "$repo"; commitfile "$repo" .claude/context/audience-rules.md
out="$(run 'git push' "$repo" "$no_cfg")"; assert_allow "$out" ".claude/*.md change allows push"

# test-only change since marker → allow (exempt)
repo="$(mkrepo)"; mark "$repo"; commitfile "$repo" src/app.test.js
out="$(run 'git push' "$repo" "$no_cfg")"; assert_allow "$out" "test-only change allows push (exempt)"

# --- Finding 1 regression: merge-commit bypass in the per-commit [skip docs] loop ---
# `git diff-tree --no-commit-id --name-only -r <merge-sha>` prints nothing for merge commits,
# so a non-doc file introduced only by a merge (e.g. a conflict resolution) used to fall through
# to allow even though it's genuinely un-acked. Build two branches that truly conflict on
# README.md, merge with --no-ff, resolve the conflict AND introduce a new non-doc file
# (sneaky.js) in the merge commit itself.

# 12. merge-commit-introduced non-doc, no [skip docs] anywhere → deny
repo="$(mkrepo)"
( cd "$repo" && echo base > README.md && git add . && git commit -qm "add readme" )
mark "$repo"
base_branch="$(git -C "$repo" symbolic-ref --short HEAD)"
( cd "$repo" && git checkout -qb feature-a )
( cd "$repo" && echo line-a >> README.md && git commit -qam "readme change a" )
( cd "$repo" && git checkout -q "$base_branch" && git checkout -qb feature-b )
( cd "$repo" && echo line-b >> README.md && git commit -qam "readme change b" )
( cd "$repo" && git checkout -q "$base_branch" && git merge --no-ff -q feature-a -m "merge feature-a" )
( cd "$repo" && git merge --no-ff feature-b -m "merge feature-b" >/dev/null 2>&1
  echo resolved > README.md && echo sneaky > sneaky.js && git add -A \
    && git commit -qm "merge feature-b: resolve conflict, add sneaky.js" )
out="$(run 'git push' "$repo" "$no_cfg")"; assert_deny "$out" "merge-commit-introduced non-doc denies"

# 13. companion: identical conflict/merge, but every commit (branches + both merges) carries
#     [skip docs] → allow (proves this is the ack rule, not a blanket merge block)
repo="$(mkrepo)"
( cd "$repo" && echo base > README.md && git add . && git commit -qm "add readme" )
mark "$repo"
base_branch="$(git -C "$repo" symbolic-ref --short HEAD)"
( cd "$repo" && git checkout -qb feature-a )
( cd "$repo" && echo line-a >> README.md && git commit -qam "readme change a [skip docs]" )
( cd "$repo" && git checkout -q "$base_branch" && git checkout -qb feature-b )
( cd "$repo" && echo line-b >> README.md && git commit -qam "readme change b [skip docs]" )
( cd "$repo" && git checkout -q "$base_branch" && git merge --no-ff -q feature-a -m "merge feature-a [skip docs]" )
( cd "$repo" && git merge --no-ff feature-b -m "merge feature-b [skip docs]" >/dev/null 2>&1
  echo resolved > README.md && echo sneaky > sneaky.js && git add -A \
    && git commit -qm "merge feature-b: resolve conflict, add sneaky.js [skip docs]" )
out="$(run 'git push' "$repo" "$no_cfg")"; assert_allow "$out" "merge-commit non-doc with [skip docs] on every commit allows"

exit $fail
