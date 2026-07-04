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
exempt = common test globs.

Both installers (`install-docs-ci`, `install-revise-hook`) offer a doc-file-set choice of
`default`, `with-skill`, or `minimal`. When a project keeps the **default**, `docPatterns` is
omitted from the per-install config JSON entirely (and nothing is written here) — the classifier
falls back to its built-in default list above. When a project picks a **custom** set
(`with-skill` or `minimal`), the installer persists the chosen glob list here, the same way
`excludeDirs` is persisted, and mirrors the identical list into the per-install config JSON. For
example, `with-skill` would be persisted as:

    docPatterns:
      - "**/CLAUDE*.md"
      - "**/README*.md"
      - "**/CHANGELOG.md"
      - "docs/**"
      - ".claude/**/*.md"
      - "**/SKILL.md"

`exemptPatterns` (first-party paths that don't require docs) is not currently exposed as an
installer choice; only the built-in default applies:

    exemptPatterns:
      - "**/*.test.*"
      - "**/*.spec.*"
      - "**/test/**"
      - "**/tests/**"
      - "**/__tests__/**"
      - "**/*_test.go"
      - "**/*_test.py"
