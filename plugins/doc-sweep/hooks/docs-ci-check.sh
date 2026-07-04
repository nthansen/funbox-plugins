#!/usr/bin/env bash
# docs-ci-check.sh — doc-sweep PR-time docs-staleness check for GitHub Actions.
# Fails (exit 1) only when non-doc files changed in the PR but no doc file changed
# AND no `[skip docs]` acknowledgment is present. Otherwise passes (exit 0).
#
# Usage (in a `pull_request` workflow):
#   plugins/doc-sweep/hooks/docs-ci-check.sh [CONFIG_JSON_PATH]
#
# Baseline is the PR's merge base — no committed marker or state file.
# Inputs (first available wins):
#   - DOCS_CI_BASE       : explicit base ref/sha (override; used by tests)
#   - GITHUB_EVENT_PATH  : the pull_request event payload (real GHA)
#   - GITHUB_BASE_REF    : the target branch name (real GHA fallback)
#   - DOCS_CI_PR_BODY    : PR body override (tests); else read from the event payload
# Uses `node` for JSON (no jq), matching revise-push-guard.sh. Fails OPEN (passes with a
# warning on stderr) if the base cannot be resolved, so infra hiccups never block a PR.
set -uo pipefail

warn(){ printf 'docs-ci-check: %s\n' "$1" >&2; }
pass(){ exit 0; }

here="$(cd "$(dirname "$0")" && pwd)"

git rev-parse --is-inside-work-tree >/dev/null 2>&1 || { warn "not a git work tree; passing"; pass; }

# --- resolve the PR body (for the [skip docs] ack) ---
pr_body="${DOCS_CI_PR_BODY:-}"
if [ -z "$pr_body" ] && [ -n "${GITHUB_EVENT_PATH:-}" ] && [ -f "${GITHUB_EVENT_PATH}" ]; then
  pr_body="$(node -e 'try{const e=JSON.parse(require("fs").readFileSync(process.argv[1],"utf8"));process.stdout.write((e.pull_request&&e.pull_request.body)||"")}catch(x){}' "$GITHUB_EVENT_PATH" 2>/dev/null || echo)"
fi

# --- resolve the base commit (merge base of the PR) ---
base_ref=""
if [ -n "${DOCS_CI_BASE:-}" ]; then
  base_ref="$DOCS_CI_BASE"
elif [ -n "${GITHUB_EVENT_PATH:-}" ] && [ -f "${GITHUB_EVENT_PATH}" ]; then
  base_ref="$(node -e 'try{const e=JSON.parse(require("fs").readFileSync(process.argv[1],"utf8"));process.stdout.write((e.pull_request&&e.pull_request.base&&e.pull_request.base.sha)||"")}catch(x){}' "$GITHUB_EVENT_PATH" 2>/dev/null || echo)"
elif [ -n "${GITHUB_BASE_REF:-}" ]; then
  base_ref="origin/${GITHUB_BASE_REF}"
fi
[ -n "$base_ref" ] || { warn "cannot determine PR base ref; passing (fail-open)"; pass; }

base_sha="$(git rev-parse --verify "${base_ref}^{commit}" 2>/dev/null || echo)"
[ -n "$base_sha" ] || { warn "base ref '${base_ref}' not found; passing (fail-open)"; pass; }
mb="$(git merge-base "$base_sha" HEAD 2>/dev/null || echo "$base_sha")"

# --- the [skip docs] acknowledgment: PR body OR any commit message in range ---
# Case-insensitive substring match via node (no grep: avoids fixed-string/locale quirks).
has_ack(){
  local text
  text="$pr_body
$(git log --format=%B "${mb}..HEAD" 2>/dev/null || true)"
  printf '%s' "$text" | node -e 'let s="";process.stdin.on("data",d=>s+=d).on("end",()=>{process.exit(/\[skip docs\]/i.test(s)?0:1)})' 2>/dev/null
}

changed="$(git diff --name-only "${mb}..HEAD" 2>/dev/null)" || { warn "cannot diff ${mb}..HEAD; passing (fail-open)"; pass; }
[ -n "$changed" ] || pass   # nothing changed

# --- classify via the shared module (delegates docPatterns/excludeDirs/exemptPatterns) ---
cfg_arg=(); [ -n "${1:-}" ] && [ -f "$1" ] && cfg_arg=(--config "$1")
result="$(printf '%s\n' "$changed" | node "$here/doc-classify.mjs" "${cfg_arg[@]}" 2>/dev/null)" || { warn "classify failed; passing (fail-open)"; pass; }
parsed="$(printf '%s' "$result" | node -e 'let s="";process.stdin.on("data",d=>s+=d).on("end",()=>{try{const o=JSON.parse(s);process.stdout.write(String(o.docChanged)+"\n"+((o.nonDoc||[]).join("\n")))}catch(e){process.exit(1)}})' 2>/dev/null)" || { warn "classify produced unexpected output; passing (fail-open)"; pass; }
docchanged="$(printf '%s' "$parsed" | head -1)"
nondoc="$(printf '%s' "$parsed" | tail -n +2)"

# Pass if no non-doc changed, or a doc changed, or the change is acknowledged.
[ -z "$nondoc" ] && pass
[ "$docchanged" = "true" ] && pass
has_ack && pass

# Otherwise: code changed, no docs, no ack → fail with guidance.
{
  echo "Docs staleness check failed."
  echo
  echo "Non-doc file(s) changed in this PR but no documentation was updated:"
  while IFS= read -r f; do [ -n "$f" ] && echo "  - $f"; done <<EOF
$nondoc
EOF
  echo
  echo "Clear this check by any one of:"
  echo "  * updating the relevant docs (CLAUDE.md for Claude, README.md for humans), or"
  echo "  * adding '[skip docs]' to a commit message in this PR, or"
  echo "  * adding '[skip docs]' to the PR description (editable in the browser — no rebase needed)."
} >&2
exit 1
