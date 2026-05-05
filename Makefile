.PHONY: all setup autofix check bump_plugin

PART ?= patch

all: autofix check

setup:
	cp .git-hooks/* .git/hooks/
	chmod +x .git/hooks/*

autofix:
	npx prettier --write .

check:
	npx prettier --check .

bump_plugin:
	@node scripts/bump-plugin.js $(PART)
