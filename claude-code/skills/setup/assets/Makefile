.PHONY: all setup autofix check

all: autofix check

setup:
	cp .git-hooks/* .git/hooks/
	chmod +x .git/hooks/*

autofix:
	npx prettier --write .

check:
	npx prettier --check .
