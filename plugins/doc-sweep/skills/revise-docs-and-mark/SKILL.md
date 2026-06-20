---
name: revise-docs-and-mark
description: Review this session's docs and then record the review snapshot the push guard checks. Use when a `git push` was blocked by the doc-staleness guard, or before pushing, to run revise-docs and mark docs reviewed up to HEAD.
allowed-tools:
  - Skill
  - Bash(git rev-parse*)
---

# Revise docs, then snapshot the review

This is the push guard's entry point. It runs the normal documentation review and then
records the **review snapshot** that the guard reads. `revise-docs` itself stays
completely unaware of the guard — this wrapper owns the snapshot mechanism, layered on
top of the unchanged skill.

## Steps

1. **Review docs (skill as-is).** Invoke the `doc-sweep:revise-docs` skill via the Skill
   tool and let it run to completion exactly as normal (load audience rules, update
   CLAUDE.md/README.md, etc.). Do not change how it works.

2. **Record the snapshot.** After revise-docs has finished and any doc commits are made,
   record that documentation has been reviewed up to the current commit — **even if
   revise-docs changed nothing** (that still means "reviewed to here, nothing needed"):

   ```sh
   git rev-parse HEAD > "$(git rev-parse --git-common-dir)/doc-sweep-revise-marker"
   ```

   This per-clone marker (inside the git directory, not committed) is exactly what the
   push guard checks. Advancing it to HEAD is what lets a previously-blocked `git push`
   proceed.

3. **Report** that docs were reviewed and the snapshot recorded, and that `git push` can
   be retried.
