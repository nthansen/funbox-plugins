## 1. Hook: configurable trigger + exclusions

- [x] 1.1 Add a `trigger` field (`push`|`commit`, default `push`) to the config read in `revise-push-guard.sh`; select the git-subcommand grep accordingly (reuse the existing push regex shape for commit).
- [x] 1.2 Make the deny message name the gated verb ("before you push" / "before you commit") and reference `revise-docs-and-mark`.
- [x] 1.3 Read `excludeDirs` from the hook config; in the changed-file loop, drop any path under an excluded dir before doc/non-doc classification (counts as neither).
- [x] 1.4 Keep `node`-only parsing, fail-open, self-skip, and bypass behavior intact; preserve the intentional `SC2086` disables and LF line endings.
- [x] 1.5 Verify worktree marker resolution via `git rev-parse --git-common-dir` is unchanged.

## 2. Installer: trigger, marker, summary, reconfigure

- [x] 2.1 Add a single-choice **Trigger event** question (push default, or commit) to the install `AskUserQuestion`; write `trigger` into the config JSON.
- [x] 2.2 Add the fresh-install marker step: three-way prompt (seed HEAD now / run `revise-docs-and-mark` now / leave unseeded) using `git rev-parse --git-common-dir`; report seeding as an assumption.
- [x] 2.3 Replace the thin Report step with a structured summary block (settings/hook/config paths, trigger, doc-set, repo scope, marker state, caveats, bypass tokens, edit/uninstall instructions, worktree note for project-scoped installs).
- [x] 2.4 Flesh out the existing-install branch into Reconfigure / Uninstall / Cancel; Reconfigure re-asks pre-filled, rewrites config (matcher only if hook path changed), leaves the marker alone.
- [x] 2.5 Add the vendor scan-and-confirm at install: detect submodules / non-root manifests / known vendor names, confirm with the user, persist `excludeDirs` to `.claude/context/audience-rules.md` and mirror into the hook config.
- [x] 2.6 Update SKILL frontmatter/wording: "push guard" → "push/commit guard"; add any newly-needed scoped `allowed-tools` (e.g. for the overlay write).

## 3. revise-docs: tracked-only discovery + exclusions

- [x] 3.1 Replace the `**/README.md` glob with `git ls-files`-based discovery; add `Bash(git ls-files*)` to `revise-docs` allowed-tools.
- [x] 3.2 Add explicit existence-checks for local twins (`audience-rules.local.md`, `CLAUDE.local.md`, `*.local.md`); never blanket-include untracked.
- [x] 3.3 Read `excludeDirs` from `.claude/context/audience-rules.md` and exclude those paths; if absent on first run, run the scan-confirm-persist flow.

## 4. revise-docs-and-mark: single commit

- [x] 4.1 Add `Bash(git add*)` and `Bash(git commit*)` to allowed-tools.
- [x] 4.2 After `revise-docs` completes, make exactly one commit of all CLAUDE.md + README changes; if nothing changed, skip the commit but still advance the marker.
- [x] 4.3 Ensure the marker is written after the commit; confirm `revise-docs` and `revise-claude-md` stay edit-only.

## 5. Tests, validation, docs

- [x] 5.1 Update `install-revise-hook` evals: trigger choice, marker step, structured summary, reconfigure flow, exclusion scan/persist.
- [x] 5.2 Update `revise-docs` evals: tracked-only discovery, local-twin inclusion, vendor exclusion.
- [x] 5.3 Regenerate the hash-verified benchmark via `/skill-gate` and confirm `check-skill-gate.mjs` passes the per-skill threshold.
- [x] 5.4 Run `node scripts/validate-marketplace.mjs`, `claude plugin validate` per plugin, `bash -n` + ShellCheck on the hook, and `openspec validate --strict --all`; fix any findings.
- [x] 5.5 Manually verify worktree behavior: install in a worktree, confirm marker is shared per-clone and exclusions resolve; capture in verify.md.
- [x] 5.6 Update `plugins/doc-sweep/CHANGELOG.md`.
