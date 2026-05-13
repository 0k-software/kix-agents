.PHONY: all setup autofix check

all: autofix check

setup:
	@if [ -d .beads/hooks ]; then \
		git config core.hooksPath .beads/hooks && chmod +x .beads/hooks/*; \
	else \
		mkdir -p .git/hooks && cp .git-hooks/* .git/hooks/ && chmod +x .git/hooks/*; \
	fi

autofix:
	npx prettier --write .

check:
	npx prettier --check .
