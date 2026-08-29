.PHONY: all setup autofix check bump release

PART ?= patch
# Pin Prettier: an unpinned `npx prettier` resolves to whatever is in the local
# npx cache, so a stale cache passes the pre-commit gate while CI (always latest)
# fails on the same tree. Bump this deliberately, then run `make autofix`.
PRETTIER := npx --yes prettier@3.9.6
PLUGIN_VERSION := $(shell jq -r '.version' claude-code/.claude-plugin/plugin.json 2>/dev/null)

all: autofix check

setup:
	git config core.hooksPath .beads/hooks
	chmod +x .beads/hooks/*

autofix:
	$(PRETTIER) --write .

check:
	$(PRETTIER) --check .

bump:
	@node scripts/bump-plugin.js $(PART)

release:
	@test -n "$(PLUGIN_VERSION)" || { echo "error: could not read version from claude-code/.claude-plugin/plugin.json"; exit 1; }
	@git diff --quiet && git diff --cached --quiet \
		|| { echo "error: working tree is dirty — commit all changes first"; exit 1; }
	@set -e; \
	TOKEN="$${GITHUB_TOKEN:-$${GH_TOKEN:-$$(gh auth token 2>/dev/null)}}"; \
	test -n "$$TOKEN" || { echo "error: no GitHub token (set GITHUB_TOKEN or GH_TOKEN, or run 'gh auth login')"; exit 1; }; \
	REPO=$$(git config --get remote.origin.url | sed -E -e 's#^.+[:/]([^:/]+/[^/]+)$$#\1#' -e 's#\.git$$##'); \
	SHA=$$(git rev-parse HEAD); \
	HTTP=$$(curl -sS -o /dev/null -w "%{http_code}" \
		-H "Authorization: Bearer $$TOKEN" \
		-H "Accept: application/vnd.github+json" \
		"https://api.github.com/repos/$$REPO/commits/$$SHA"); \
	test "$$HTTP" = "200" \
		|| { echo "error: HEAD ($$SHA) is not on origin — push your branch first (got HTTP $$HTTP)"; exit 1; }; \
	HTTP=$$(curl -sS -o /dev/null -w "%{http_code}" \
		-H "Authorization: Bearer $$TOKEN" \
		-H "Accept: application/vnd.github+json" \
		"https://api.github.com/repos/$$REPO/git/ref/tags/v$(PLUGIN_VERSION)"); \
	test "$$HTTP" = "404" \
		|| { echo "error: tag v$(PLUGIN_VERSION) already exists on origin"; exit 1; }; \
	curl -fsSL -X POST \
		-H "Authorization: Bearer $$TOKEN" \
		-H "Accept: application/vnd.github+json" \
		-H "X-GitHub-Api-Version: 2022-11-28" \
		"https://api.github.com/repos/$$REPO/releases" \
		-d "{\"tag_name\":\"v$(PLUGIN_VERSION)\",\"target_commitish\":\"$$SHA\",\"name\":\"v$(PLUGIN_VERSION)\",\"generate_release_notes\":true}" \
		> /dev/null; \
	git fetch origin "refs/tags/v$(PLUGIN_VERSION):refs/tags/v$(PLUGIN_VERSION)" 2>/dev/null || true; \
	echo "Released v$(PLUGIN_VERSION)"
