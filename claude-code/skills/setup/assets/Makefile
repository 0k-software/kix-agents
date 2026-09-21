.PHONY: all setup autofix check check-prime

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

check: check-prime
	$(PRETTIER) --check .

# Fails when .beads/PRIME.md is stamped for a different bd version than the pin
# in .kix/hooks/install-bd.sh. No-op when either file is absent.
check-prime:
	@if [ -x .kix/hooks/check-prime.sh ]; then .kix/hooks/check-prime.sh; fi
