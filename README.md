# funbox

A Claude Code plugin marketplace — a small, growing set of plugins for working in Claude Code.

## Add the marketplace

From inside Claude Code:

```text
/plugin marketplace add nthansen/funbox-plugins
```

Then install the plugin below, and update later with `/plugin marketplace update funbox`.

## Plugins

### [`funbox`](plugins/funbox/) — keep docs and Claude rules current

Your repo's docs serve two audiences: `CLAUDE.md` for Claude, `README.md` for humans — each with
a gitignored `.local.md` twin for machine-specific notes. After a working session they drift, and
content lands in the wrong file: a local path in a shared doc, or Claude-only notes in a `README`.

funbox keeps them sorted by audience and writes them from your **live session context** — what a
"doc must change when code changes" check can't do. Five skills: `revise-docs` (update from what
changed), `audit-docs` (check doc health), `init-audience-rules` (scaffold per-project rules),
`init-claude-rules` (build `.claude/rules` from your code), and `revise-claude-rules` (fold
session learnings in). →
[details](plugins/funbox/)

```text
/plugin install funbox@funbox
```

The plugin is self-contained under [`plugins/`](plugins/) with its own `plugin.json`, README, and
CHANGELOG. Plugins roll on `main` — every commit is the current version, and
`/plugin marketplace update funbox` pulls the latest.

## Layout

```
.claude-plugin/marketplace.json   # the funbox catalog (lists each plugin)
plugins/
  funbox/                         # plugin: documentation audit, revise, and rules skills
```

Adding a plugin = a new self-contained dir under `plugins/` plus one entry in
`marketplace.json`.

## Contributing

New plugins are welcome. Every plugin is checked in CI on every PR by the official
`claude plugin validate` (plus a gitleaks secret scan) — see
[CONTRIBUTING.md](CONTRIBUTING.md). Run the same check locally with
`claude plugin validate ./plugins/<your-plugin>`.

## License

Released into the public domain under [The Unlicense](LICENSE). Do whatever you want with it
— no attribution required.
