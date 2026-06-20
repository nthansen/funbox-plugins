# CLAUDE.md — funbox-plugins

**funbox** is a Claude Code **plugin marketplace**. Repo name `funbox-plugins`; marketplace
name is `funbox` (the `name` in `.claude-plugin/marketplace.json`). Each plugin is
self-contained under `plugins/`.

## Layout

- `.claude-plugin/marketplace.json` — the catalog. Each entry: `{ name, source: "./plugins/<name>", description }`.
- `plugins/<name>/.claude-plugin/plugin.json` — plugin manifest; `name` must match the directory **and** the catalog entry.
- `plugins/<name>/{README.md,CHANGELOG.md}` — required for every plugin.
- `plugins/<name>/skills/<skill>/SKILL.md` — skills; frontmatter `name` must match the skill directory.
- `scripts/validate-marketplace.mjs` — the validator; `.github/workflows/validate.yml` runs it in CI.
- `.claude/context/audience-rules.md` — funbox dogfoods **doc-sweep**; this is the repo's
  documentation **audience-rules overlay**, layered on doc-sweep's bundled base
  (`plugins/doc-sweep/context/audience-rules-base.md`). It holds only funbox's deltas; the base
  owns the CLAUDE-vs-README boundary law.
- `doc-sweep`'s `init-audience-rules` skill is **`disable-model-invocation: true` on purpose**
  (manual-only `/`-command): auto-invocation over-triggers on ordinary CLAUDE.md-vs-README doc
  talk. Don't remove it — `revise-docs`/`audit-docs` stay model-invocable.

## Versioning — read before touching a version

- Plugins **omit `version`** in `plugin.json` on purpose → `main` is a rolling channel (every
  commit is a new version, resolved by commit SHA). Adding a `version` **pins** the plugin
  (consumers stop auto-updating until it's bumped). Only add one to cut a stable, pinnable release.
- No tags or releases — distribution is the git repo + `marketplace.json`, resolved by commit
  SHA (the same model as the official marketplace). Each plugin's `CHANGELOG.md` points at its
  commit history rather than enumerating versions.

## Validation (CI gate — keep it green)

- Run `node scripts/validate-marketplace.mjs` before committing. Optional local hook:
  `git config core.hooksPath .githooks`.
- It enforces: marketplace/plugin structure; **required README + CHANGELOG per plugin**;
  SKILL.md frontmatter; **`allowed-tools` must be scoped** (no bare or wildcard
  `Bash`/`PowerShell`); cross-marketplace deps must be allowlisted; orphan plugin dirs; a
  danger-pattern scan.
- CI also runs the **official `claude plugin validate`** per plugin (no `--strict`, so the
  intentionally-omitted `version` isn't flagged), plus `bash -n`, ShellCheck, PowerShell
  parse, and gitleaks.
- The validator checks SKILL.md frontmatter with **regex, not a YAML parser** — it can pass
  malformed YAML (e.g. an unquoted `key: value` colon-space inside a `description`) that fails
  at load time. Rely on `claude plugin validate` for frontmatter correctness, and keep `: ` and
  other YAML-significant punctuation out of unquoted frontmatter scalars.
- `scripts/check-skill-gate.mjs` enforces a **per-skill functional eval pass-rate ≥
  threshold** (default 0.9 in `.claude/skill-gate.json`) via a committed,
  hash-verified `evals/benchmark.json`; (re)generate benchmarks with the
  `/skill-gate` command (needs `skill-creator` installed). Run artifacts live in
  gitignored `*-workspace/`. See CONTRIBUTING.md.
- CI also runs **`openspec validate --strict --all`** (structural spec/change rules)
  plus `scripts/check-openspec-hygiene.mjs`, which catches two things `validate`
  accepts: a **TBD/placeholder `## Purpose`** in `openspec/specs/**` (archive seeds it
  and `validate` passes it), and a **fully-implemented change left un-archived**
  (`tasks.md` all `[x]` but still under `openspec/changes/`). Both **self-scope** — no
  specs / no active changes ⇒ no findings — so OpenSpec is never forced onto a PR that
  doesn't use it (bug fixes / docs / config tweaks stay direct-PR per the routing table).

## Local testing

- `make install-local` points the **funbox** marketplace at this working clone (via
  `claude plugin marketplace add "$(CURDIR)"`) and installs both plugins; `make install-remote`
  switches the source back to the GitHub repo; `make remove` tears it down.
- Gotcha: the local clone and the GitHub repo both resolve to the same marketplace name
  `funbox`, so they can't be added at once — each `make` target removes the marketplace before
  re-adding it. After edits, `/reload-plugins` (or reload the VS Code window).

## Dependencies

A plugin depending on another marketplace (e.g. `doc-sweep` →
`claude-md-management@claude-plugins-official`) needs **both** the `dependencies` entry in its
`plugin.json` **and** the target marketplace listed in `allowCrossMarketplaceDependenciesOn`
in `marketplace.json`. The validator rejects an un-allowlisted cross-marketplace dependency.

## Script gotchas

- `*.sh`, `.githooks/*`, and the `Makefile` must stay **LF** (`.gitattributes`) or they break
  on Linux/macOS (CRLF appends a stray `\r` to each Makefile recipe command).
- The version-sort `printf $_v` in the patch scripts is an **intentional** word-split;
  `SC2086` is disabled there on purpose — do not "fix" it by quoting.
- grep probes that begin with `-` (e.g. `--thinking-display`) must be passed via `grep -e`,
  or grep parses them as options and aborts.

<!-- Source: superpowers-bridge/templates/adopters/CLAUDE.md.fragment.md -->
<!-- Drop this section into your project's CLAUDE.md so Claude routes future work using this schema correctly. -->
<!-- Adjust the schema name and bridge repo URL if you customized them; otherwise keep as-is. -->

## Workflow routing (read on session start)

This repo uses [`superpowers-bridge`](https://github.com/JiangWay/openspec-schemas/tree/main/superpowers-bridge) to bridge OpenSpec and Superpowers. Integration rules (language, artifact paths, PRECHECK) follow that bridge's README; this section is the routing guidance for Claude.

### Entry routing

| Trigger you observe | What to do |
|---|---|
| User starts a narrative "design discussion / let's brainstorm" | Run verbal `superpowers:brainstorming`, but **do NOT** write to `docs/superpowers/specs/`. Once the conversation converges per the 5 criteria below, promote to `/opsx:propose` |
| User invokes `/opsx:new` / `/opsx:ff` / `/opsx:propose` directly | Follow the schema's flow; artifact instructions inject at each step |
| User explicitly says bug fix / typo / config tweak / doc update | Direct PR — **do NOT** open a change (see skip rules below) |
| User is mid-change | Advance with `/opsx:continue`, `/opsx:apply`, `/opsx:verify`, or `/opsx:archive` |

### When NOT to use opsx (direct PR)

| Scenario | Direct PR? |
|---|---|
| New feature / new capability / architectural change / breaking change | ❌ Use opsx |
| Bug fix (no contract change) / test backfill / linter tweak / non-breaking upgrade / typo / docs / config value tweak | ✅ Direct PR |

Principle: **process ceremony scales with risk**. External contracts / schema / cross-system integration / compliance → opsx. Otherwise → direct PR.

### Verbal brainstorm → opsx promotion criteria

All 5 must hold before promoting (any missing → keep brainstorming, **never** write to `docs/superpowers/specs/`):

1. **Scope locked** — one sentence describes what's in / out
2. **Major design forks resolved** — alternatives weighed; remaining TBDs have an owner and impact-scope statement
3. **Cross-system dependencies mapped** — ready / mockable / genuinely unknown — pick one per dep
4. **Acceptance criteria stateable** — concrete pass conditions (e.g., `./mvnw clean verify` passes + N deliverables)
5. **Conversation converging** — recent turns are confirmations, not new alternatives

When all 5 hold → proactively suggest "ready to `/opsx:propose`?" — wait for user ack. Never auto-trigger.

### Front-door anti-patterns (don't do)

- Letting brainstorming write to `docs/superpowers/specs/`
- Letting writing-plans write to `docs/superpowers/plans/`
- Promoting to opsx with unresolved blocking TBDs
- Opening a change for bug fix / typo

Full detail: [superpowers-bridge README §Entry & exit gates](https://github.com/JiangWay/openspec-schemas/blob/main/superpowers-bridge/README.md#entry--exit-gates).
