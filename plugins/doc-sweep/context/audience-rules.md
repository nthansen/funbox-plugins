# Documentation audience rules — default overlay

Layered on top of the invariant base (`audience-rules-base.md`). These are the **tunable**
conventions doc-sweep applies when a project hasn't supplied its own. A project replaces this
overlay by adding `.claude/context/audience-rules.md` (see the `init-audience-rules` skill); the
base still applies underneath either way.

An overlay may **add file types** (rows beyond the base four) and **refine the per-file contents
guidance and shell/path conventions** — but it never reassigns a file's audience or scope; that
boundary lives in the base.

## Shell + path conventions

Shared files (`CLAUDE.md`, `README.md`, scripts, code comments) should target the project's
primary environment and stay consistent with it. As a default, prefer POSIX `sh`/`bash` syntax
and paths; keep machine-specific or OS-specific snippets (Windows drive letters, PowerShell,
personal tool paths) in the `.local.md` twin rather than the shared files.
