# Brainstorm — unify doc classification

Raw capture of the design conversation (adversarial review → decision chain). Reorganized into
structured sections in `design.md`.

## Background

Triggered by an adversarial review of the just-merged `docs-staleness-ci` feature. The reviewer
asked: is `docs-ci-check.sh` useful, is it too specific, should it be node, and does it "miss out
on boundaries" — ideally the doc-sweep skills and scripts should share the same pattern logic.

Grounding the review in the files surfaced a concrete bug, not just a smell. "What is a doc?" is
currently defined in **three** places that disagree:

| Source | Used by | `.claude/**/*.md` | `CHANGELOG.md` | `docs/**` |
|---|---|---|---|---|
| `audience-rules-base.md` (prose) | the skills (revise/audit) | doc ("all `*.md` under `.claude/`") | overlay-only | overlay-only |
| `is_doc()` in `revise-push-guard.sh` | the hook | NOT a doc | doc | doc |
| `is_doc()` in `docs-ci-check.sh` | the CI check | NOT a doc | doc | doc |

Consequences:
- **Divergence bug**: a PR that edits only `.claude/context/audience-rules.md` — doc-sweep's own
  canonical doc — is classified as a non-doc change with no docs touched, so `docs-ci-check.sh`
  **fails it**. The guard flags you for editing the file that defines what a doc is. Untested.
- **Copy-paste**: `is_doc` + the excludeDirs loop are duplicated verbatim in the two shell files;
  they will drift.
- **Hybrid bash+node smell**: `docs-ci-check.sh` wraps four separate `node -e` one-liners around
  bash (re-parsing the config JSON twice) — worst of both.
- **Crudeness**: the check only knows "a non-doc changed and no doc was touched"; it can't tell if
  docs were actually *warranted*. The `[skip docs]` hatch is the tell. Real value only for the
  cases the local hook can't reach (humans, fork PRs, non-doc-sweep contributors); marginal on a
  solo repo. Kept as advisory, not a required blocker.

Nuance that shaped scope: the **skills** and **scripts** don't do the same classification. Scripts
answer a binary *is this path a doc?* (doc vs non-doc). Skills answer *which audience does this
known doc serve?* (Claude vs human), driven by the prose table — they have no `is_doc`/`docMode`.
So "one function for everything" is a category error; the genuinely shareable thing is the
**doc-file-set** (which globs count as docs) + `excludeDirs`.

## Decision chain

**Q1 — Direction: unify up, simplify down, or leave it?**
Two directions weighed. (A) Unify up: one shared declarative doc-file-set + one classifier module,
fixing the divergence. (B) Simplify down: accept it's a crude nag, drop `docMode`, classify docs as
"any `*.md` or under `docs/`", delete the enum. Absent the divergence bug, B would win for a solo
repo — but the bug tips it: the fix and the unification are the same work.
→ **Decision: A (unify up), scoped tightly.**

**Q2 — Scope: where does the single source live, and does it touch skill runtime?**
Options: (1) scripts + shared source only; (2) also wire the skills to read `docPatterns`
programmatically; (3) just dedupe the scripts + fix `.claude/**`, no declarative source.
Option 2 rejected — the skills don't do doc-vs-non-doc classification, so wiring them to
`docPatterns` is a forced fit and would churn their eval benchmarks. Option 3 leaves two
definitions.
→ **Decision: (1)** — add a machine-readable `docPatterns` block to the audience-rules
(base + overlay) as the single doc-file-set source; one shared `doc-classify.mjs` consumed by
BOTH scripts; fix `.claude/**`; retire `docMode`. Skills stay prose-driven (unchanged runtime)
with a consistent machine-readable twin.

**Q3 — Where do the patterns physically live at runtime? (single source vs no new parser)**
Reading `docPatterns` straight from `audience-rules.md` would need a markdown-embedded-YAML parser
in node (new complexity). But `excludeDirs` already establishes the pattern: install persists it in
`audience-rules.md` (human-authoritative) and **mirrors** it into the per-install config JSON, which
the scripts read via `JSON.parse`. Reuse that exact mechanism for `docPatterns`.
→ **Decision:** `audience-rules.md` is the human source (install reads/writes it); the config JSON
is the machine-read mirror; the classifier reads `docPatterns`/`excludeDirs` from the config, else a
built-in default. No new parser; consistent with today's `excludeDirs` flow. The CI vendored
`docs-ci.json` carries the mirrored patterns; funbox's own no-config dogfood run uses the built-in
default (which now includes `.claude/**`).

**Q4 — `docMode` retirement: alias, hard-retire, or keep both?**
→ **Decision: hard retire.** The classifier understands only `docPatterns` + a built-in default;
`docMode` removed from both scripts, the config schema, and both install skills (which now write
`docPatterns`). Accepted risk: an old config still carrying `docMode` silently falls back to the
default set until regenerated — fine, effectively single-user.

**Q5 — node vs bash.**
→ **Decision:** git plumbing (merge-base, diff, log, per-commit `[skip docs]`) stays bash; the
classification + JSON + glob matching move into one `doc-classify.mjs` module both scripts shell
into once. Node is already a hard dependency ("no jq"); a module is unit-testable and shared rather
than copy-pasted. A reusable `uses:` action was previously rejected on supply-chain grounds; the
classifier is vendored alongside the check script instead.

## Design shape (validated)

- **`doc-classify.mjs`** — file list on stdin, optional `--config <path>`; reads
  `docPatterns` + `excludeDirs` (or built-in default: `CLAUDE*.md`, `README*.md`, `CHANGELOG.md`,
  `docs/**`, `.claude/**/*.md`); emits `{"nonDoc":[…],"docChanged":bool}`. Tiny in-house glob
  matcher (`*`, `**`), no external deps. Unit-tested with `node --test`.
- **`revise-push-guard.sh` / `docs-ci-check.sh`** — become thin git wrappers that pipe changed
  files to the classifier; drop their duplicated `is_doc`/`docMode`/config-parsing.
- **audience-rules** — gains a `docPatterns:` block co-located with `excludeDirs`.
- **Install skills** — copy `doc-classify.mjs` alongside their script; write `docPatterns` instead
  of `docMode`.

## Trade-offs / risks

- Hard-retire `docMode` → stale configs fall back to default until regenerated (accepted).
- Both scripts now depend on invoking a node **script file** (not just `node -e`) — vendored copies
  must ship `doc-classify.mjs`.
- Per-commit `[skip docs]` logic in the hook may call the classifier per commit; ranges are small,
  acceptable.
- The underlying "crude nag" limitation is unchanged — this change fixes correctness + duplication,
  not the heuristic's inherent imprecision. Staleness check stays advisory.

## Non-goals

Wiring skills' runtime to `docPatterns`; changing `[skip docs]` semantics; any LLM-in-CI judgement;
altering the merge-base baseline or advisory/blocking posture.
