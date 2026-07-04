---
name: install-docs-ci
description: Install (or remove) an opt-in GitHub Actions check that fails a pull request when code changed but docs did not, unless the author adds a [skip docs] acknowledgment. Use to set up, reconfigure, or uninstall the doc-sweep docs-staleness CI check.
allowed-tools:
  - Read
  - Write
  - Edit
  - AskUserQuestion
  - Bash(git rev-parse*)
  - Bash(mkdir -p*)
  - Bash(cp *)
  - Bash(rm -f*)
  - Bash(git config*)
  - Bash(git ls-files*)
disable-model-invocation: true
---

# Install the docs-staleness CI check

Set up an opt-in GitHub Actions workflow that runs on every pull request and **fails** when
non-doc files changed but no documentation did — unless the author acknowledges the change
doesn't need docs with a `[skip docs]` token (mirroring `[skip ci]`). Unlike the local
`revise-docs-push-guard` hook, this catches **everyone** — human commits, contributors without
doc-sweep, and **fork PRs**. It is deterministic: no LLM, no API key, no secret. The check
parses the event with `node` (not `jq`) and fails open (passes) if it can't resolve the PR base.

**Nothing is installed until you run this and confirm.** This scaffolds files into the target
repository; commit them yourself so the check runs on future PRs.

The check clears when any one of these is present in a PR: an updated doc-set file; a `[skip docs]`
token in any commit message in the PR; or a `[skip docs]` line in the PR description (editable in
the browser — no rebase needed). This is the **same `[skip docs]` token** the local push-guard
hook recognizes, so the two guards share one vocabulary.

## Steps

1. **Detect an existing install.** Look for the scaffolded workflow at
   `${CLAUDE_PROJECT_DIR}/.github/workflows/doc-sweep-docs.yml` (and the vendored script at
   `.github/doc-sweep/docs-ci-check.sh` plus its classifier at
   `.github/doc-sweep/doc-classify.mjs` — both files, not just the script, are part of what
   constitutes an install).

   - If **no install** is found → proceed to step 2 (fresh install).
   - If an install **is found**, offer three choices via `AskUserQuestion`:
     - **Reconfigure** — re-ask the choices in step 2 pre-filled from the existing
       `.github/doc-sweep/docs-ci.json`; rewrite that config, re-copy the script, and
       unconditionally re-copy `doc-classify.mjs` alongside it (idempotent — this self-heals a
       missing or stale classifier even when nothing else about the install changed); leave the
       workflow file in place (rewrite it only if its path/name changed); print the summary
       (step 6). Stop.
     - **Uninstall** — follow the Uninstall section below. Stop.
     - **Cancel** — do nothing and exit. Stop.

2. **Collect scope (AskUserQuestion).** Ask both in one prompt, with defaults called out:

   - **Doc-file set** — `default` (matches `doc-classify.mjs`'s built-in list: `CLAUDE*.md`,
     `README*.md`, `CHANGELOG.md`, files under `docs/`, and any `.md` under `.claude/`),
     `with-skill` (also treats SKILL.md as a doc), or `minimal` (CLAUDE.md + README.md only).
     Recommend `default`. If the user picks `default`, do **not** transcribe this parenthetical
     into a `docPatterns` list — omit `docPatterns` from the config JSON entirely (step 4) so
     `doc-classify.mjs`'s own built-in default (documented in `context/audience-rules.md`)
     applies. If the user picks `with-skill` or `minimal` (a custom set), record the concrete
     glob list as `docPatterns` and persist it into `.claude/context/audience-rules.md` the same
     way `excludeDirs` is persisted (step 4).
   - **Excluded directories** — confirm the vendored/generated dirs whose changes should be
     ignored (neither doc nor non-doc). Recorded as `excludeDirs`.

3. **Scan for vendored directories and resolve `excludeDirs`.**

   If `.claude/context/audience-rules.md` already contains an `excludeDirs:` list, read it
   silently. Otherwise scan the repo for likely-vendored dirs using three signals and present
   candidates via `AskUserQuestion` (the user may remove any, add others, or confirm all):
   - **Git submodules**: `git config --file .gitmodules --get-regexp path` (if `.gitmodules` exists).
   - **Non-root package manifests**: `git ls-files` filtered for `package.json`, `composer.json`,
     `Cargo.toml`, `go.mod`, `Gemfile`, `requirements.txt`, `pyproject.toml`, `pom.xml`, or
     `build.gradle` whose dirname is not `.`; collect their parent directories.
   - **Known vendor names**: any of `vendor`, `third_party`, `Pods`, `bower_components`,
     `node_modules` existing as a root directory.

4. **Copy the check script and classifier, and write the config.** `mkdir -p` `.github/doc-sweep/`, then:
   - Copy this skill's bundled `../../hooks/docs-ci-check.sh` to
     `${CLAUDE_PROJECT_DIR}/.github/doc-sweep/docs-ci-check.sh` (keep it executable; it must stay
     LF). Vendoring the script keeps the check self-contained — no external action ref, no
     runtime download.
   - Also copy this skill's bundled `../../hooks/doc-classify.mjs` to
     `${CLAUDE_PROJECT_DIR}/.github/doc-sweep/doc-classify.mjs` — the **same directory** as the
     script above, since `docs-ci-check.sh` resolves the classifier next to itself
     (`$here/doc-classify.mjs`). Without it the check fails open (passes) on every PR.
   - If the user chose a **custom** doc-file set in step 2 (`with-skill` or `minimal`), persist
     the chosen `docPatterns` glob list into `.claude/context/audience-rules.md` the same way
     `excludeDirs` is persisted: append a `docPatterns:` block if the file exists and doesn't
     already have one, update it in place if it does, or create the file with a brief header
     comment if it doesn't exist yet. If the user kept the **default**, leave `audience-rules.md`
     untouched for `docPatterns`.
   - Write `${CLAUDE_PROJECT_DIR}/.github/doc-sweep/docs-ci.json`:
     - Default doc-file set — omit `docPatterns` entirely:
       ```json
       { "excludeDirs": [<confirmed>] }
       ```
     - Custom doc-file set (`with-skill` or `minimal`) — include the concrete glob list,
       mirroring what was just persisted to `audience-rules.md`:
       ```json
       { "docPatterns": [<chosen>], "excludeDirs": [<confirmed>] }
       ```

5. **Scaffold the workflow (idempotent).** Write
   `${CLAUDE_PROJECT_DIR}/.github/workflows/doc-sweep-docs.yml` (do not overwrite an unrelated
   workflow of the same name — if the file exists and is not this check, choose a
   non-colliding name and report it):
   ```yaml
   name: doc-sweep docs check
   # Fails a PR when code changed but docs did not, unless a `[skip docs]` token is present in a
   # commit message or the PR body. Deterministic — no secrets. Managed by doc-sweep install-docs-ci.
   on:
     pull_request:
   permissions:
     contents: read
   jobs:
     docs-staleness:
       runs-on: ubuntu-latest
       steps:
         - uses: actions/checkout@v6
           with:
             fetch-depth: 0   # full history so the merge base and commit messages resolve
         - uses: actions/setup-node@v6
           with:
             node-version: '20'
         - name: Docs staleness check
           run: bash .github/doc-sweep/docs-ci-check.sh .github/doc-sweep/docs-ci.json
   ```
   Whether a failing check **blocks** merge is the maintainer's branch-protection choice (make
   the `docs-staleness` job a required status check to block); the job itself just exits non-zero.

6. **Print a structured summary.**

   ```
   doc-sweep docs-staleness CI check installed
   ───────────────────────────────────────────
   Workflow file : <abs path to .github/workflows/doc-sweep-docs.yml>
   Check script  : <abs path to .github/doc-sweep/docs-ci-check.sh>
   Classifier    : <abs path to .github/doc-sweep/doc-classify.mjs>
   Config file   : <abs path to .github/doc-sweep/docs-ci.json>
   Doc-file set  : <default|with-skill|minimal> (docPatterns: <glob list, or "(built-in default)">)
   Excluded dirs : <comma-separated list, or "(none)">
   Ack token     : [skip docs]  (in a commit message or the PR description)

   Next steps
   • Commit the scaffolded files so the check runs on future PRs.
   • To BLOCK merges on failure, make the `docs-staleness` job a required status check in
     branch protection. Otherwise the check is advisory (red X, merge still allowed).

   Clears a PR : update docs · or `[skip docs]` in a commit message · or `[skip docs]` in the PR body
   Edit/uninstall: re-run /doc-sweep:install-docs-ci
   ```

## Uninstall

Delete the scaffolded workflow `${CLAUDE_PROJECT_DIR}/.github/workflows/doc-sweep-docs.yml`, the
vendored `${CLAUDE_PROJECT_DIR}/.github/doc-sweep/docs-ci-check.sh` and its vendored
`doc-classify.mjs`, and the `docs-ci.json` config. Remove the now-empty `.github/doc-sweep/`
directory if nothing else remains. Leave all other workflows and files untouched. Confirm what
was removed (workflow path, script path, classifier path, config path). The change takes effect
once you commit the removal.
