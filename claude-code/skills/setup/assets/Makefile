.PHONY: all setup autofix check

all: autofix check

setup:
	@if [ -d .beads/hooks ]; then \
		git config core.hooksPath .beads/hooks && chmod +x .beads/hooks/*; \
	else \
		hooks="$$(git rev-parse --git-path hooks)" && mkdir -p "$$hooks" && cp .git-hooks/* "$$hooks/" && chmod +x "$$hooks"/*; \
	fi

# Pin Prettier: an unpinned `npx prettier` resolves to whatever is in the local
# npx cache, so a stale cache passes the pre-commit gate while CI (always latest)
# fails on the same tree. Bump this deliberately, then run `make autofix`.
PRETTIER := npx --yes prettier@3.9.6

autofix:
	$(PRETTIER) --write .

check:
	$(PRETTIER) --check .
