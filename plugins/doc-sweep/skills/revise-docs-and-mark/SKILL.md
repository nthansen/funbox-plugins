---
name: revise-docs-and-mark
description: Review this session's docs and then record the review snapshot the push guard checks. Use when a `git push` was blocked by the doc-staleness guard, or before pushing, to run revise-docs and mark docs reviewed up to HEAD.
allowed-tools:
  - Skill
  - Bash(git rev-parse*)
  - Bash(git add*)
  - Bash(git commit*)
---

# Revise docs, then snapshot the review

This is the push guard's entry point. It runs the normal documentation review and then
records the **review snapshot** that the guard reads. `revise-docs` itself stays
completely unaware of the guard — this wrapper owns the snapshot mechanism, layered on
top of the unchanged skill.

## Steps

1. **Review docs (skill as-is).** Invoke the `doc-sweep:revise-docs` skill via the Skill
   tool and let it run to completion exactly as normal (load audience rules, update
   CLAUDE.md/README.md, etc.). `revise-docs` and the delegated
   `claude-md-management:revise-claude-md` skill stay **edit-only** — they must not
   commit. All committing is done here in the wrapper.

2. **Make exactly one commit of only the doc files changed this run.** After `revise-docs`
   finishes, the agent knows exactly which files it (and the delegated `revise-claude-md`)
   just edited — stage those explicit paths and no others:

   ```sh
   git add CLAUDE.md plugins/doc-sweep/README.md   # example — use the actual paths
   # if the audience-rules exclusion list was written, also add:
   git add .claude/context/audience-rules.md
   ```

   **Do NOT use `git add -A` or `git add .`** — those commands would capture any
   unrelated working-tree changes the user had in progress (e.g. code edits or feature
   work started before running the review) and bundle them into the doc commit. Stage
   only the documentation paths that `revise-docs` / `revise-claude-md` actually
   modified in this run (CLAUDE.md files, README.md files, and
   `.claude/context/audience-rules.md` if the exclusion list was written).

   Check whether anything is staged. If there are staged changes, make **one** commit
   with a short, context-aware `docs:`-type message that describes what actually changed
   — for example:

   ```sh
   git commit -m "docs: update push-guard hook notes in CLAUDE.md and doc-sweep README"
   ```

   The message should reflect the real changes (which files, what was added/corrected),
   not a fixed boilerplate string.

   If nothing is staged (revise-docs determined no updates were needed), skip the
   commit entirely — do not make an empty commit.

3. **Record the snapshot.** After the commit step (whether or not a commit was made),
   write the current HEAD to the per-clone marker — **even when no changes were committed**
   (that still means "reviewed to here, nothing needed"):

   ```sh
   git rev-parse HEAD > "$(git rev-parse --git-common-dir)/doc-sweep-revise-marker"
   ```

   This marker (inside the git directory, not committed) is exactly what the push guard
   checks. Advancing it to HEAD is what lets a previously-blocked `git push` proceed.

4. **Report** that docs were reviewed, whether a commit was made (and its SHA if so), and
   that the snapshot was recorded. Confirm that `git push` can be retried.
