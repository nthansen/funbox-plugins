# Contributing to funbox

Thanks for wanting to add to **funbox**. Every plugin passes the same automated checks: CI
([`.github/workflows/validate.yml`](.github/workflows/validate.yml)) runs them on every pull
request, and a PR can't merge until they pass and a maintainer approves. Run the same checks
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

## Validation

The gate is the **official** [`claude plugin validate`](https://code.claude.com/docs/en/plugins-reference),
which checks each `plugin.json`, skill/agent/command frontmatter, and `hooks/hooks.json` against
the real schema. Each `plugin.json` also references the published schema via `$schema`, so
editors validate it as you type. (CI runs it without `--strict`, since `--strict` flags our
intentionally-omitted `version` — see [Versioning](#versioning).)

## Local checks

Run the same check CI runs:

```sh
claude plugin validate ./plugins/<your-plugin>   # official schema/frontmatter
```

Optionally enable the pre-commit hook so it runs automatically (it runs `claude plugin validate`
if the CLI is installed):

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
2. Run `claude plugin validate ./plugins/<your-plugin>` until it's green.
3. Open a PR and fill out the template. A maintainer reviews every change
   ([CODEOWNERS](.github/CODEOWNERS)); structural and safety checks must pass first.
