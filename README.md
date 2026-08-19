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

A repo's docs serve two audiences, each with a shared (committed) file and an optional local
(gitignored) twin: `CLAUDE.md` / `CLAUDE.local.md` for Claude, and `README.md` /
`README.local.md` for humans. They drift out of date after a working session, and content lands
in the wrong place — a machine-specific path baked into a shared file, or Claude-only notes
cluttering a `README`. funbox enforces these **audience rules** (a bundled default you can
override per project) and, crucially, writes docs from the **live session context** — its skills
audit doc health (`audit-docs`), revise docs from what changed (`revise-docs`), and scaffold a
project-specific rules overlay (`init-audience-rules`) — keeping each piece in its right home, and
per-developer content in the `.local.md` twin. It also derives and maintains a repo's
**`.claude/rules`** from its own code: `init-claude-rules` cold-scans the repo to bootstrap
evidence-backed, path-scoped rules, and `revise-claude-rules` folds a session's convention
learnings into them. →
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
