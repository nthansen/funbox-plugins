<!-- See CONTRIBUTING.md for the full criteria. CI enforces these automatically. -->

## What does this change?

<!-- New plugin? New skill in an existing plugin? Fix? Briefly describe it. -->

## Checklist

- [ ] `node scripts/validate-marketplace.mjs` passes locally
- [ ] New/changed plugin lives under `plugins/<name>/` and is listed in `marketplace.json`
- [ ] Plugin has a `README.md` and `CHANGELOG.md`
- [ ] Any `SKILL.md` has `name` (matching its dir) + `description`, and any `allowed-tools` are scoped (no bare/wildcard `Bash`/`PowerShell`)
- [ ] Scripts contain no download-into-shell, `rm -rf /`/`$HOME`, or secrets
- [ ] I agree my contribution is released into the public domain (The Unlicense)

## Notes for the reviewer

<!-- Anything that needs human judgment: what the scripts do, why a flagged pattern is safe, etc. -->
