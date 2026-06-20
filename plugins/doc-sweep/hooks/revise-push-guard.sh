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
printf '%s' "$cmd" | grep -Eq '(^|[^[:alnum:]_])git([[:space:]]+-[^[:space:]]*([[:space:]]+[^-[:space:]][^[:space:]]*)?)*[[:space:]]+push([[:space:]]|$)' || allow
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
  # shellcheck disable=SC2086
  is_doc "$f" || nondoc="$nondoc $f"
done <<EOF
$changed
EOF

if [ -n "$nondoc" ]; then
  # shellcheck disable=SC2086
  emit_deny "Docs may be stale — non-doc file(s) changed since the last revise-docs run:${nondoc}. Run /doc-sweep:revise-docs to capture this session's doc learnings, commit any changes, then push again. (Add DOC_SWEEP_REVISE_SKIP=1 before the command, or --no-verify, to bypass.)"
fi
allow
