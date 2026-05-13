.PHONY: all setup autofix check

all: autofix check

setup:
	@if [ -d .beads/hooks ]; then \
		git config core.hooksPath .beads/hooks && chmod +x .beads/hooks/*; \
	else \
		hooks="$$(git rev-parse --git-path hooks)" && mkdir -p "$$hooks" && cp .git-hooks/* "$$hooks/" && chmod +x "$$hooks"/*; \
	fi

autofix:
	npx prettier --write .

check:
	npx prettier --check .
