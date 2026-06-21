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
cfg6="$(mktemp)"; echo '{"docMode":"default","repoScope":"doc-sweep-only"}' > "$cfg6"
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

# 11. minimal docMode: CHANGELOG change is non-doc → deny
repo="$(mkrepo)"; mark "$repo"; commitfile "$repo" CHANGELOG.md
cfg11="$(mktemp)"; echo '{"docMode":"minimal","repoScope":"all"}' > "$cfg11"
out="$(run 'git push' "$repo" "$cfg11")"; assert_deny "$out" "minimal docMode: CHANGELOG is non-doc"

# --- Task 1: configurable trigger ---

# commit-trigger: a git push must be IGNORED even when non-doc files changed since marker
repo="$(mkrepo)"; cfg="$(mktemp)"; echo '{"trigger":"commit"}' > "$cfg"
mark "$repo"
( cd "$repo" && echo y > new.js && git add . && git commit -qm feat )
out="$(run 'git push' "$repo" "$cfg")"; assert_allow "$out" "commit-trigger ignores push"

exit $fail
