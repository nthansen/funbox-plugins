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
  out="$(printf '%s' "$json" | bash "$HOOK" "$cfg" 2>/dev/null)"
  if printf '%s' "$out" | grep -q '"permissionDecision":"deny"'; then
    if [ "$expect" = deny ]; then ok "$name"; else no "$name (got deny, want allow)"; fi
  else
    if [ "$expect" = allow ]; then ok "$name"; else no "$name (got allow, want deny)"; fi
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

# 8. git -C <path> push with non-doc change → deny (space-separated global opt)
R="$(mk_repo)"; mark "$R"; commitfile "$R" src/app.js; run "dash-C-deny" "" "$(js "$R" "git -C $R push")" deny
# 9. --no-verify bypass → allow despite non-doc
R="$(mk_repo)"; mark "$R"; commitfile "$R" src/app.js; run "no-verify-bypass" "" "$(js "$R" 'git push --no-verify')" allow
# 10. multi-level docs-only change → allow (case glob docs/* matches any depth)
R="$(mk_repo)"; mark "$R"; commitfile "$R" docs/api/ref.md; run "deep-docs-allow" "" "$(js "$R" 'git push')" allow
# 11. minimal docMode: CHANGELOG change is non-doc → deny
R="$(mk_repo)"; mark "$R"; commitfile "$R" CHANGELOG.md; printf %s '{"docMode":"minimal","repoScope":"all"}' > /tmp/cfg11.json; run "minimal-changelog-deny" "/tmp/cfg11.json" "$(js "$R" 'git push')" deny

printf '\n%d passed, %d failed\n' "$pass" "$fail"
[ "$fail" -eq 0 ]
