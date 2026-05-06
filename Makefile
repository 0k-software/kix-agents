.PHONY: all setup autofix check bump release

PART ?= patch
PLUGIN_VERSION := $(shell jq -r '.version' claude-code/.claude-plugin/plugin.json 2>/dev/null)

all: autofix check

setup:
	cp .git-hooks/* .git/hooks/
	chmod +x .git/hooks/*

autofix:
	npx prettier --write .

check:
	npx prettier --check .

bump:
	@node scripts/bump-plugin.js $(PART)

release:
	@test -n "$(PLUGIN_VERSION)" || { echo "error: could not read version from claude-code/.claude-plugin/plugin.json"; exit 1; }
	@git diff --quiet && git diff --cached --quiet \
		|| { echo "error: working tree is dirty — commit all changes first"; exit 1; }
	@git tag -a "v$(PLUGIN_VERSION)" -m "v$(PLUGIN_VERSION)" 2>/dev/null \
		|| { echo "error: tag v$(PLUGIN_VERSION) already exists"; exit 1; }
	@git push origin "v$(PLUGIN_VERSION)"
	@gh release create "v$(PLUGIN_VERSION)" \
		--title "v$(PLUGIN_VERSION)" \
		--generate-notes
	@echo "Released v$(PLUGIN_VERSION)"
