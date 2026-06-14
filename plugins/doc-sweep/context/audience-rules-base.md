# Documentation audience rules — base

These are the **invariant** audience rules — the file boundary doc-sweep exists to enforce.
They are always in effect and are **not overridable** by a project. An overlay (the bundled
default overlay, or a project's `.claude/context/audience-rules.md`) may **add file types** and
**refine the per-file contents guidance and shell/path conventions** on top of this base — but
it never reassigns a file's audience or scope.

| File | Audience | Scope | Baseline contents |
|---|---|---|---|
| `CLAUDE.md` | Claude only | Team-shared, checked into git | Commands, gotchas, non-obvious patterns, architectural constraints, tool config warnings. Never human-facing content. |
| `CLAUDE.local.md` | Claude only | Personal/local, gitignored | Local paths, personal deploy scripts, machine-specific config, anything that varies per developer. If it references a path on a specific machine or a personal tool, it belongs here, not in `CLAUDE.md`. |
| `README.md` | Humans only | Team-shared, checked into git | How to build, run, and use the software. Keep commands accurate. Never include Claude-specific guidance. |
| `README.local.md` | Humans only | Personal/local, gitignored | Machine-specific human-facing notes: local setup commands, personal paths, per-developer run instructions. The README's `.local` twin. |

Glob for CLAUDE.md files: `**/CLAUDE*.md` — covers all subdirectories including `CLAUDE.local.md` variants.

**Key rule (invariant):** If content is meant for a human reading the repo, it goes in a
human-facing file (`README.md`, or a human-facing file type an overlay adds). If it's meant to
orient Claude during a session, it goes in a `CLAUDE.md` file. These are never mixed. An overlay
may add file types on either side of this line, but every file stays on one side of it.

## The `.local.md` convention

Each documentation audience has a **shared** file (committed) and an optional **local** companion
(`<name>.local.md`, gitignored) for machine-specific content that varies per developer. This
applies to both audiences — it is not Claude-only:

- `CLAUDE.md` → `CLAUDE.local.md` — Claude Code auto-loads both.
- `README.md` → `README.local.md` — human-facing; the local one holds setup commands or notes
  specific to your machine.

The rule is the same for both: anything per-developer (local paths, personal setup commands,
machine config) lives in the `.local.md` twin, not the committed file. When revising or
auditing, push such content into the matching `.local.md` and keep the shared doc clean and
general. (This is the documentation scope — `.local.md` here means the `CLAUDE`/`README` twins,
not arbitrary `*.local` files.)

## .claude/ files

All `*.md` files under `.claude/` are Claude-facing operational files. Review them for stale
commands, renamed targets, or missing context — same approval process as CLAUDE.md changes.
