# funbox — local dev helpers.
#
# Switch the funbox marketplace between your local working clone and the published GitHub repo,
# and (re)install its plugins via the `claude` CLI.
#
# Both sources resolve to the SAME marketplace name ("funbox", from marketplace.json), so they
# can't be added at the same time — each install target removes the marketplace first, then
# re-adds it from the chosen source.
#
# These targets configure the install; plugin changes apply on the next Claude Code session
# (or after /reload-plugins in a running one). They don't hot-reload a live session.

REPO   := nthansen/funbox-plugins
MARKET := funbox

.PHONY: help install-local install-remote install-plugins remove validate

help:
	@echo "make install-local   - point funbox at this working clone, then install its plugins"
	@echo "make install-remote  - point funbox at $(REPO) on GitHub, then install its plugins"
	@echo "make remove          - uninstall the plugins and remove the funbox marketplace"
	@echo "make validate        - run the marketplace validator (same check CI runs)"

# Use the local checkout (this directory) as the marketplace source.
install-local:
	-claude plugin marketplace remove $(MARKET)
	claude plugin marketplace add "$(CURDIR)"
	$(MAKE) install-plugins

# Use the published GitHub repo as the marketplace source.
install-remote:
	-claude plugin marketplace remove $(MARKET)
	claude plugin marketplace add $(REPO)
	$(MAKE) install-plugins

install-plugins:
	claude plugin install vscode-thinking-display@$(MARKET)
	claude plugin install doc-sweep@$(MARKET)

remove:
	-claude plugin uninstall vscode-thinking-display
	-claude plugin uninstall doc-sweep
	-claude plugin marketplace remove $(MARKET)

validate:
	node scripts/validate-marketplace.mjs
