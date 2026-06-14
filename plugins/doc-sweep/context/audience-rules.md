# Documentation audience rules

These rules are strictly enforced across all doc skills.

| File | Audience | Scope | Contents |
|---|---|---|---|
| `CLAUDE.md` | Claude only | Team-shared, checked into git | Commands, gotchas, non-obvious patterns, architectural constraints, tool config warnings. Never human-facing content. |
| `CLAUDE.local.md` | Claude only | Personal/local, gitignored | Local paths, personal deploy scripts, machine-specific config, anything that varies per developer. If it references a path on a specific machine or a personal tool, it belongs here not in `CLAUDE.md`. |
| `README.md` | Humans only | — | How to build, run, and use the software. Keep commands accurate. Never include Claude-specific guidance. |

Glob for CLAUDE.md files: `**/CLAUDE*.md` — covers all subdirectories including `CLAUDE.local.md` variants.

**Key rule:** If content is meant for a human reading the repo, it goes in README.md. If it's meant to orient Claude during a session, it goes in a CLAUDE.md file. These are never mixed.

## The `.local.md` convention

Each documentation audience has a **shared** file (committed) and an optional **local** companion (`<name>.local.md`, gitignored) for machine-specific content that varies per developer. This applies to both audiences — it is not Claude-only:

- `CLAUDE.md` → `CLAUDE.local.md` — Claude Code auto-loads both.
- `README.md` → `README.local.md` — human-facing; the local one holds setup commands or notes specific to your machine.

The rule is the same for both: anything per-developer (local paths, personal setup commands, machine config) lives in the `.local.md` twin, not the committed file. When revising or auditing, push such content into the matching `.local.md` and keep the shared doc clean and general. (This is the documentation scope — `.local.md` here means the `CLAUDE`/`README` twins, not arbitrary `*.local` files.)

## .claude/ files

All `*.md` files under `.claude/` are Claude-facing operational files. Review them for stale commands, renamed targets, or missing context — same approval process as CLAUDE.md changes.

## Shell + path conventions

Shared files (`CLAUDE.md`, `README.md`, scripts, code comments) should target the project's
primary environment and stay consistent with it. As a default, prefer POSIX `sh`/`bash`
syntax and paths; keep machine-specific or OS-specific snippets (Windows drive letters,
PowerShell, personal tool paths) in `CLAUDE.local.md` rather than the shared files.

> This is the bundled default ruleset. A consuming project can override it by adding its own
> `.claude/context/audience-rules.md` (see each skill's instructions).
