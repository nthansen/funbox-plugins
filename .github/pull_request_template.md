<!-- See CONTRIBUTING.md for the full criteria. CI runs `claude plugin validate` plus
     shell/PowerShell syntax and a secret scan; the rest is reviewer judgment. -->

## What does this change?

<!-- New plugin? New skill in an existing plugin? Fix? Briefly describe it. -->

## Checklist

- [ ] `claude plugin validate ./plugins/<name>` passes locally
- [ ] New/changed plugin lives under `plugins/<name>/` and is listed in `marketplace.json`
- [ ] Plugin has a `README.md` and `CHANGELOG.md`
- [ ] Any `SKILL.md` has `name` (matching its dir) + `description`, and any `allowed-tools` are scoped (no bare/wildcard `Bash`/`PowerShell`)
- [ ] Scripts contain no download-into-shell, `rm -rf /`/`$HOME`, or secrets
- [ ] I agree my contribution is released into the public domain (The Unlicense)

## Notes for the reviewer

<!-- Anything that needs human judgment: what the scripts do, why a flagged pattern is safe, etc. -->
