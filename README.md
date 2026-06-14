# funbox

A Claude Code plugin marketplace — a small, growing set of plugins for working in Claude Code.

## Add the marketplace

From inside Claude Code:

```text
/plugin marketplace add nthansen/funbox-plugins
```

Then install any plugin below, and update later with `/plugin marketplace update funbox`.

## Plugins

### [`vscode-thinking-display`](plugins/vscode-thinking-display/) — see thinking on Opus/Fable

On Opus/Fable models the VS Code Claude Code extension renders thinking as empty, unexpandable
"Thought for Xs" stubs — an upstream bug where it never asks the API for thinking summaries.
This plugin patches the extension to bring the summaries back, and can optionally default
thinking blocks to expanded. Reversible, with backups. →
[details](plugins/vscode-thinking-display/)

```text
/plugin install vscode-thinking-display@funbox
```

### [`doc-sweep`](plugins/doc-sweep/) — keep docs current and in the right file

A repo's docs serve two audiences, each with a shared (committed) file and an optional local
(gitignored) twin: `CLAUDE.md` / `CLAUDE.local.md` for Claude, and `README.md` /
`README.local.md` for humans. They drift out of date after a working session, and content lands
in the wrong place — a machine-specific path baked into a shared file, or Claude-only notes
cluttering a `README`. doc-sweep enforces these **audience rules** (a bundled default you can
override per project): its two skills audit doc health (`audit-docs`) and revise docs from what
changed (`revise-docs`), keeping each piece in its right home — and per-developer content in the
`.local.md` twin. → [details](plugins/doc-sweep/)

```text
/plugin install doc-sweep@funbox
```

Each plugin is self-contained under [`plugins/`](plugins/) with its own `plugin.json`,
README, and CHANGELOG. Plugins roll on `main` — every commit is the current version, and
`/plugin marketplace update funbox` pulls the latest.

## Layout

```
.claude-plugin/marketplace.json   # the funbox catalog (lists each plugin)
plugins/
  vscode-thinking-display/        # plugin: VS Code thinking-display patch
  doc-sweep/                      # plugin: documentation audit + revise skills
```

Adding a plugin = a new self-contained dir under `plugins/` plus one entry in
`marketplace.json`.

## Contributing

New plugins are welcome. Every plugin meets an automated, auditable bar (structure, required
docs, scoped `allowed-tools`, script safety, no secrets) enforced by CI on every PR — see
[CONTRIBUTING.md](CONTRIBUTING.md). Run the same checks locally with
`node scripts/validate-marketplace.mjs`.

## License

Released into the public domain under [The Unlicense](LICENSE). Do whatever you want with it
— no attribution required.

Individual plugins may carry their own disclaimers (e.g. `vscode-thinking-display` patches a
third-party extension at your own risk) — see each plugin's README.
