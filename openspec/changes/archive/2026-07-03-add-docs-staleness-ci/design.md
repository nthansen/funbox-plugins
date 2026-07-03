## Context

doc-sweep's current drift guard is a local `PreToolUse` push hook (`revise-docs-push-guard`).
By construction it only gates **Claude-driven** pushes, **in the one clone** where it was
installed, and relies on a **per-clone, uncommitted marker** (`$(git rev-parse
--git-common-dir)/doc-sweep-revise-marker`). It therefore cannot enforce docs review on human
commits, on contributors who never installed doc-sweep, or on **fork PRs** — the cases where
drift most often slips in. The repo already runs a CI gate (`.github/workflows/validate.yml`)
that deliberately uses **no Anthropic auth** and stays deterministic; a docs check should fit
that same mold. doc-sweep is a published marketplace plugin whose install skills
(`install-revise-hook`) are manual-only (`disable-model-invocation: true`) because
auto-invocation over-triggers on ordinary doc talk.

## Goals / Non-Goals

**Goals:**
- A universal, PR-time enforcement layer that catches everyone the hook cannot (humans, forks,
  non-doc-sweep contributors).
- Zero false-positive friction for legitimate code-only PRs (bug fixes) via a cheap, in-browser
  ack that needs no history rewrite.
- Deterministic and secret-free, matching validate.yml's stance.
- One shared acknowledgment vocabulary across the hook and the CI check.
- Package it the doc-sweep way: a manual installer skill + a shipped script.

**Non-Goals:**
- Removing/deleting the push-guard hook (deferred, reversible follow-up — recorded as a note).
- Any LLM-in-CI judgement of doc necessity (needs a secret + tokens; rejected).
- `vscode-thinking-display`; release/changelog automation (anti-goals for a rolling-`main` repo).

## Decisions

**1. PR-time check keyed on the merge base — no committed marker.**
The hook needs a marker because it watches an ongoing working tree across many commits. A PR has
a natural baseline: its merge base. So the check is simply "in the merge-base..head diff, did
non-doc change without docs?" — no marker file, no advance ceremony, no merge conflicts.
*Alternative considered:* a committed "docs reviewed up to <sha>" marker mirroring the hook.
Rejected as needless churn and conflict surface once the merge base gives a free baseline.

**2. Block, but clear via a `[skip docs]` ack (block + escape hatch).**
The check asserts "docs staleness was *considered*," not "docs ARE stale" (unknowable without an
LLM, and wrong for bug fixes). A code-only PR fails until the author signals consideration.
*Alternatives:* advisory-only (too weak — ignored); path-scoped trigger (crude proxy); LLM-judged
(needs secret/tokens). Rejected in favor of the deterministic ack.

**3. Ack is a single `[skip docs]` token in a commit message OR the PR body.**
One token, placed in any commit message in the PR range (git-native) or in the PR body (the
forgot-it fallback — editable in-browser with **no history rewrite**). Chosen to mirror the
familiar `[skip ci]` convention, so there's nothing new to learn; a plain bracket token works
uniformly in both a commit message and a PR body, avoiding the trailer-vs-body split an earlier
`Docs-N/A:` trailer design would have forced. This is the direct answer to "what if someone does
a bunch of work and forgets the token." Docs actually changing is always an implicit pass.

**4. Shared token with the hook.**
The same `[skip docs]` token (in a commit message) also clears the local hook (added to its bypass
set). Two guards, one token — nothing new to learn, no divergence to document.

**5. Package as a manual install skill + shipped script (mirror `install-revise-hook`).**
New skill `install-docs-ci` (`disable-model-invocation: true`, scoped `allowed-tools`) scaffolds
`.github/workflows/*.yml` into the user's repo; the workflow calls
`plugins/doc-sweep/hooks/docs-ci-check.sh`. Parsing uses `node` (runners have it; consistent with
the hook's no-`jq` rule). *Alternatives:* a reusable/composite `uses:` action (couples users to
funbox's ref + pins — supply-chain surface the repo avoids); doc-only recipe (every user
reimplements the diff/ack parsing). Rejected.

**6. Reposition the hook as optional secondary; funbox stops requiring it.**
CI becomes the primary guard. The hook stays shipped for users who want fast pre-push feedback,
but funbox's own `.claude/settings.json` drops the required local hook so the sole maintainer
isn't carrying the marker ceremony day-to-day. Whether to retire the hook entirely is deferred
until CI has been lived with — recorded as a `CLAUDE.md` / "considered & revisit" note, not
decided here (deletion is the one hard-to-reverse move under current uncertainty).

## Risks / Trade-offs

- **Feedback moves from pre-push to PR time** (a few CI minutes later) → the hook remains
  available for anyone who wants the earlier local loop.
- **Ack could be used to rubber-stamp every PR** → a `[skip docs]` token is visible and auditable
  in the commit/PR, so waving it through shows up in review; acceptable for a solo/low-traffic
  repo, revisit if abused.
- **Two guards until the hook's fate is decided** → mitigated by the shared vocabulary and by
  funbox no longer requiring the hook, so there's no day-to-day double friction.
- **Doc-set drift between hook config and CI config** → both read the same doc-file-set default
  (`CLAUDE*.md`, `README*.md`, `CHANGELOG.md`, `docs/**`); keep them documented in one place.

## Migration Plan

1. Land the shipped script + `install-docs-ci` skill + push-guard shared-ack update (with tests).
2. Dogfood: scaffold the workflow into funbox's `.github/workflows/`; drop the required local hook
   from funbox `.claude/settings.json`; update funbox `CLAUDE.md` with the CI guard + deferred
   retirement note.
3. Update doc-sweep `README.md`/`CHANGELOG.md`; regenerate the new skill's `/skill-gate` benchmark.
4. Rollback: the change is additive and opt-in — remove the scaffolded workflow and revert the
   push-guard bypass addition; nothing else depends on it.

## Open Questions

- None blocking. The retire-vs-keep-the-hook decision is intentionally deferred (see Decision 6).
