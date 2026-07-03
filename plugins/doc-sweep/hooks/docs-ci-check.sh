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

# --- config (optional): docMode + excludeDirs, same shape as the push guard ---
docmode="default"; excludes=""
cfg="${1:-}"
if [ -n "$cfg" ] && [ -f "$cfg" ]; then
  docmode="$(node -e 'try{process.stdout.write(JSON.parse(require("fs").readFileSync(process.argv[1],"utf8")).docMode||"default")}catch(e){process.stdout.write("default")}' "$cfg" 2>/dev/null || echo default)"
  excludes="$(node -e 'try{const a=JSON.parse(require("fs").readFileSync(process.argv[1],"utf8")).excludeDirs;process.stdout.write(Array.isArray(a)?a.join("\n"):"")}catch(e){}' "$cfg" 2>/dev/null || echo)"
fi

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

is_doc(){ # $1 = path; doc per $docmode (identical classification to revise-push-guard.sh)
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

nondoc=""; docchanged=0
while IFS= read -r f; do
  [ -n "$f" ] || continue
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
  if is_doc "$f"; then
    docchanged=1
  else
    nondoc="$nondoc $f"
  fi
done <<EOF
$changed
EOF

# Pass if no non-doc changed, or a doc changed, or the change is acknowledged.
[ -z "$nondoc" ] && pass
[ "$docchanged" = 1 ] && pass
has_ack && pass

# Otherwise: code changed, no docs, no ack → fail with guidance.
{
  echo "Docs staleness check failed."
  echo
  echo "Non-doc file(s) changed in this PR but no documentation was updated:"
  # shellcheck disable=SC2086
  for f in $nondoc; do echo "  - $f"; done
  echo
  echo "Clear this check by any one of:"
  echo "  * updating the relevant docs (CLAUDE.md for Claude, README.md for humans), or"
  echo "  * adding '[skip docs]' to a commit message in this PR, or"
  echo "  * adding '[skip docs]' to the PR description (editable in the browser — no rebase needed)."
} >&2
exit 1
