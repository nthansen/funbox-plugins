#!/usr/bin/env bash
# Scenario tests for docs-ci-check.sh. Run: bash test-docs-ci-check.sh
set -uo pipefail
SCRIPT="$(cd "$(dirname "$0")" && pwd)/docs-ci-check.sh"
fail=0

mkrepo(){ d="$(mktemp -d)"; ( cd "$d" && git init -q && git config user.email a@b.c && git config user.name t \
  && echo x > f.txt && git add . && git commit -qm init ) ; echo "$d"; }
basesha(){ git -C "$1" rev-parse HEAD; }
# commitfile REPO PATH [MESSAGE]
commitfile(){ local d="$1" f="$2" m="${3:-change $2}"; mkdir -p "$d/$(dirname "$f")"; echo x >> "$d/$f"; git -C "$d" add -A; git -C "$d" commit -qm "$m"; }
# run BASE REPO [PR_BODY] [CFG] -> exit code of the check
run(){ ( cd "$2" && DOCS_CI_BASE="$1" DOCS_CI_PR_BODY="${3:-}" bash "$SCRIPT" "${4:-}" >/dev/null 2>&1 ); }
assert_fail(){ if [ "$1" -ne 0 ]; then echo "ok: $2"; else echo "FAIL(expected fail): $2"; fail=1; fi; }
assert_pass(){ if [ "$1" -eq 0 ]; then echo "ok: $2"; else echo "FAIL(expected pass): $2"; fail=1; fi; }

# 1. code-only → fail
repo="$(mkrepo)"; base="$(basesha "$repo")"; commitfile "$repo" src/app.js
run "$base" "$repo"; assert_fail $? "code-only change fails"

# 2. code + docs → pass
repo="$(mkrepo)"; base="$(basesha "$repo")"; commitfile "$repo" src/app.js; commitfile "$repo" README.md
run "$base" "$repo"; assert_pass $? "code + docs passes"

# 3. docs-only → pass
repo="$(mkrepo)"; base="$(basesha "$repo")"; commitfile "$repo" README.md
run "$base" "$repo"; assert_pass $? "docs-only passes"

# 4. deep docs path → pass
repo="$(mkrepo)"; base="$(basesha "$repo")"; commitfile "$repo" docs/api/ref.md
run "$base" "$repo"; assert_pass $? "deep docs/ path passes"

# 5. excluded-only → pass
repo="$(mkrepo)"; base="$(basesha "$repo")"; commitfile "$repo" vendor/lib/main.js
cfg="$(mktemp)"; echo '{"excludeDirs":["vendor"]}' > "$cfg"
run "$base" "$repo" "" "$cfg"; assert_pass $? "excluded-only change passes"

# 6. commit-message ack → pass
repo="$(mkrepo)"; base="$(basesha "$repo")"; commitfile "$repo" src/app.js "fix: bug [skip docs]"
run "$base" "$repo"; assert_pass $? "commit-message [skip docs] passes"

# 7. PR-body ack → pass
repo="$(mkrepo)"; base="$(basesha "$repo")"; commitfile "$repo" src/app.js
run "$base" "$repo" "Small fix. [skip docs] no docs needed."; assert_pass $? "PR-body [skip docs] passes"

# 8. ack is case-insensitive → pass
repo="$(mkrepo)"; base="$(basesha "$repo")"; commitfile "$repo" src/app.js
run "$base" "$repo" "[SKIP DOCS]"; assert_pass $? "ack is case-insensitive"

# 9. nothing changed (base = HEAD) → pass
repo="$(mkrepo)"; base="$(basesha "$repo")"
run "$base" "$repo"; assert_pass $? "no changes passes"

# 10. unresolvable base → fail-open (pass)
repo="$(mkrepo)"; commitfile "$repo" src/app.js
run "deadbeefdeadbeefdeadbeefdeadbeefdeadbeef" "$repo"; assert_pass $? "unresolvable base fails open"

# 11. custom docPatterns config: CHANGELOG no longer in the doc set → fail
repo="$(mkrepo)"; base="$(basesha "$repo")"; commitfile "$repo" CHANGELOG.md
cfg="$(mktemp)"; echo '{"docPatterns":["**/CLAUDE*.md","**/README*.md"]}' > "$cfg"
run "$base" "$repo" "" "$cfg"; assert_fail $? "custom docPatterns: CHANGELOG is non-doc"

# .claude markdown counts as a doc (regression: was misclassified non-doc)
repo="$(mkrepo)"; base="$(basesha "$repo")"; commitfile "$repo" src/app.js; commitfile "$repo" .claude/context/audience-rules.md
run "$base" "$repo"; assert_pass $? ".claude/*.md change satisfies the check"

# test-only change is exempt → passes without an ack
repo="$(mkrepo)"; base="$(basesha "$repo")"; commitfile "$repo" src/app.test.js
run "$base" "$repo"; assert_pass $? "test-only change passes (exempt)"

# tests + real code still enforces
repo="$(mkrepo)"; base="$(basesha "$repo")"; commitfile "$repo" src/app.test.js; commitfile "$repo" src/app.js
run "$base" "$repo"; assert_fail $? "tests + src still enforces"

exit $fail
