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

## Machine-readable doc-file-set

The guard scripts (CI check + push hook) classify paths via `doc-classify.mjs`, which reads a
`docPatterns` glob list (the machine-readable twin of the audience table above) and an
`exemptPatterns` list of first-party changes that don't require docs (default: tests). Defaults when
unset: docs = `**/CLAUDE*.md`, `**/README*.md`, `**/CHANGELOG.md`, `docs/**`, `.claude/**/*.md`;
exempt = common test globs. Installers persist the project's choices here (mirrored into the
per-install config JSON, like `excludeDirs`):

    docPatterns:
      - "**/CLAUDE*.md"
      - "**/README*.md"
      - "**/CHANGELOG.md"
      - "docs/**"
      - ".claude/**/*.md"
    exemptPatterns:      # first-party paths that don't require docs (default: tests)
      - "**/*.test.*"
      - "**/*.spec.*"
      - "**/test/**"
      - "**/tests/**"
      - "**/__tests__/**"
