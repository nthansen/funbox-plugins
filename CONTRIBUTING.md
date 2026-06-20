# Contributing to funbox

Thanks for wanting to add to **funbox**. To keep the marketplace trustworthy, every plugin
meets an **auditable, automated bar**: the checks below are enforced by CI
([`.github/workflows/validate.yml`](.github/workflows/validate.yml)) on every pull request,
and a PR can't merge until they pass and a maintainer approves. You can run the same checks
locally — see [Local checks](#local-checks).

## What a plugin must look like

Each plugin is a self-contained directory under [`plugins/`](plugins/):

```
plugins/<plugin-name>/
  .claude-plugin/plugin.json     # name (== <plugin-name>) + description
  README.md                      # required — what it is, how to use it
  CHANGELOG.md                   # required — notable changes
  skills/<skill-name>/SKILL.md   # if it ships skills
  context/ , scripts/ , ...      # supporting files as needed
```

And it must be listed in [`.claude-plugin/marketplace.json`](.claude-plugin/marketplace.json)
with a `source` of `./plugins/<plugin-name>` and a `description`.

## The criteria (all enforced by CI)

**Structure**
- `marketplace.json` is valid and has `name`, `owner.name`, and a `plugins` array.
- Every marketplace entry has `name`, `description`, and `source` starting `./plugins/`.
- Each plugin dir has a valid `.claude-plugin/plugin.json` whose `name` matches the entry.
- Each plugin has a **`README.md`** and a **`CHANGELOG.md`** (hard requirements).
- No orphan `plugins/<dir>` that isn't listed; no listed source that doesn't exist.
- Plugin `dependencies` (if any) are well-formed; a dependency in a **different** marketplace
  must be allowlisted via `allowCrossMarketplaceDependenciesOn` in `marketplace.json`.

**Skills**
- Each `skills/<name>/SKILL.md` has YAML frontmatter with `name` (matching its directory) and
  a non-empty `description` (≤ 1024 chars).
- `allowed-tools`, if present, must be **scoped** — no bare `Bash` / `PowerShell` or
  wildcard-everything grants like `Bash(*)`. Scope to specific commands or files, e.g.
  `Bash(bash *my-script.sh*)`.

**Safety**
- Scripts (`*.sh`, `*.ps1`) pass syntax checks (`bash -n`, ShellCheck, PowerShell parse).
- No secrets (gitleaks scan).
- No download-piped-into-a-shell (`curl … | sh`), no `rm -rf` on `/` or `$HOME`, no
  `base64 -d | sh`. These are flagged for maintainer review.

**Licensing** — funbox is public domain ([The Unlicense](LICENSE)). By contributing you agree
your contribution is released the same way.

## Versioning

Plugins **omit `version`** in `plugin.json` while pre-1.0, so `main` is a rolling channel
(every commit is a new version). Don't add a `version` field unless you're cutting a stable,
pinnable release for a plugin you maintain. See each plugin's `CHANGELOG.md`.

## Validation: two layers

1. **Official** — [`claude plugin validate`](https://code.claude.com/docs/en/plugins-reference)
   checks each `plugin.json`, skill/agent/command frontmatter, and `hooks/hooks.json` against
   the real schema. Each `plugin.json` also references the published schema via `$schema`, so
   editors validate it as you type. (CI runs it without `--strict`, since `--strict` flags our
   intentionally-omitted `version` — see [Versioning](#versioning).)
2. **Repo policy** — `scripts/validate-marketplace.mjs` enforces the funbox-specific criteria
   the official validator doesn't: required README+CHANGELOG, scoped `allowed-tools`,
   danger-pattern scan, cross-marketplace allowlist, and orphan checks.

## Local checks

Run both, the same as CI:

```sh
claude plugin validate ./plugins/<your-plugin>   # official schema/frontmatter
node scripts/validate-marketplace.mjs            # repo policy
```

Optionally enable the pre-commit hook so they run automatically (it runs the policy validator
always, and `claude plugin validate` if the CLI is installed):

```sh
git config core.hooksPath .githooks
```

(The hook is convenience only — it's bypassable and not present for everyone. CI is the gate.)

## Try it locally

Test a plugin straight from your working clone — no need to push or publish first.

With `make` (uses the `claude` CLI under the hood):

```sh
make install-local    # point the funbox marketplace at this clone, then install its plugins
make install-remote   # switch back to the published GitHub version
make remove           # uninstall the plugins and remove the marketplace
```

Or drive it by hand. Both sources share the marketplace name `funbox`, so remove an existing
one first to avoid a clash:

```text
/plugin marketplace remove funbox                          # only if previously added
/plugin marketplace add /absolute/path/to/funbox-plugins   # add your clone as a marketplace
/plugin install <plugin-name>@funbox                       # install from it
```

After editing plugin files (SKILL.md, scripts, hooks), run `/reload-plugins` to pick up the
changes without restarting — reload the VS Code window if something isn't reflected.

## Submitting

1. Fork, branch, add your plugin under `plugins/` and list it in `marketplace.json`.
2. Run `node scripts/validate-marketplace.mjs` until it's green.
3. Open a PR and fill out the template. A maintainer reviews every change
   ([CODEOWNERS](.github/CODEOWNERS)); structural and safety checks must pass first.

## Skill quality gate

Every skill under `plugins/*/skills/*/` must carry committed evaluation artifacts,
enforced in CI by `scripts/check-skill-gate.mjs` (pure Node, no LLM).

### Artifacts (per skill, under `evals/`)

`evals/evals.json` — eval inputs (reuses skill-creator's schema):

```json
{
  "skill_name": "<skill>",
  "threshold": 0.9,
  "evals": [
    { "id": 1, "prompt": "a realistic user request", "assertions": ["an objectively checkable claim"], "files": [] }
  ]
}
```

`threshold` is optional and overrides the repo default for that one skill.

`evals/benchmark.json` — the recorded result (generated by `/skill-gate`, committed):

```json
{
  "skill": "<skill>",
  "pass_rate": 1.0,
  "threshold": 0.9,
  "model": "<session model id>",
  "source_hash": "sha256:...",
  "results": [ { "eval_id": 1, "text": "the assertion", "passed": true, "evidence": "why" } ]
}
```

Run transcripts/outputs go to a gitignored `<skill>-workspace/` sibling — never committed.

### Generating or refreshing a benchmark

Run `/skill-gate <path-to-skill-dir>` (requires the `skill-creator` plugin
installed). It runs each eval case against the skill, grades the assertions,
computes `source_hash`, and writes `benchmark.json`. Then `git add` the `evals/`
artifacts and run `node scripts/check-skill-gate.mjs` to confirm the gate passes.

### Threshold

Default 0.9, in `.claude/skill-gate.json`. A skill may override it via `threshold`
in its `evals.json`. CI fails if `pass_rate < threshold`.

### Freshness

`benchmark.json` stores `source_hash` (sha256 over the skill source including
`evals.json`, excluding `benchmark.json` and `*-workspace/`). Editing the SKILL.md,
bundled files, or the assertions flips the hash, so CI demands a fresh `/skill-gate`
run.

### Limitation: author-trust, not tamper-proof

CI cannot re-run the LLM, so it only verifies the committed benchmark is internally
consistent and hash-fresh — not that it was produced honestly. Weakening assertions
to pass is visible in the `evals.json` diff, so reviewers should inspect it.
