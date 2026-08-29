# Project Instructions for AI Agents

This file provides instructions and context for AI coding agents working on
this project.

<!-- BEGIN BEADS INTEGRATION v:1 profile:minimal hash:ca08a54f -->

## Beads Issue Tracker

This project uses **bd (beads)** for issue tracking. Run `bd prime` to see full
workflow context and commands.

### Quick Reference

```bash
bd ready              # Find available work
bd show <id>          # View issue details
bd update <id> --claim  # Claim work
bd close <id>         # Complete work
```

### Rules

- Use `bd` for ALL task tracking — do NOT use TodoWrite, TaskCreate, or
  markdown TODO lists
- Run `bd prime` for detailed command reference and session close protocol
- Use `bd remember` for persistent knowledge — do NOT use MEMORY.md files

## Session Completion

**When ending a work session**, you MUST complete ALL steps below. Work is NOT
complete until `git push` succeeds.

**MANDATORY WORKFLOW:**

1. **File issues for remaining work** - Create issues for anything that needs
   follow-up
2. **Run quality gates** (if code changed) - Tests, linters, builds
3. **Update issue status** - Close finished work, update in-progress items
4. **PUSH TO REMOTE** - This is MANDATORY:
   ```bash
   git pull --rebase
   bd dolt push
   git push
   git status  # MUST show "up to date with origin"
   ```
5. **Clean up** - Clear stashes, prune remote branches
6. **Verify** - All changes committed AND pushed
7. **Hand off** - Provide context for next session

**CRITICAL RULES:**

- Work is NOT complete until `git push` succeeds
- NEVER stop before pushing - that leaves work stranded locally
- NEVER say "ready to push when you are" - YOU must push
- If push fails, resolve and retry until it succeeds

<!-- END BEADS INTEGRATION -->

## Non-Interactive Shell Commands

**ALWAYS use non-interactive flags** with file operations to avoid hanging on
confirmation prompts.

Shell commands like `cp`, `mv`, and `rm` may be aliased to include `-i`
(interactive) mode on some systems, causing the agent to hang indefinitely
waiting for y/n input.

**Use these forms instead:**

```bash
# Force overwrite without prompting
cp -f source dest           # NOT: cp source dest
mv -f source dest           # NOT: mv source dest
rm -f file                  # NOT: rm file

# For recursive operations
rm -rf directory            # NOT: rm -r directory
cp -rf source dest          # NOT: cp -r source dest
```

**Other commands that may prompt:**

- `scp` - use `-o BatchMode=yes` for non-interactive
- `ssh` - use `-o BatchMode=yes` to fail instead of prompting
- `apt-get` - use `-y` flag
- `brew` - use `HOMEBREW_NO_AUTO_UPDATE=1` env var

## Build & Test

This repo is Markdown content (slash commands, templates, docs) — there is no
runtime and no test suite. The toolchain is Prettier + a small release
pipeline:

```bash
make setup     # point core.hooksPath at .beads/hooks/ (beads + Prettier gate)
make autofix   # prettier --write .
make check     # prettier --check .  (the formatting gate)
make all       # autofix && check
make bump PART=patch|minor|major   # bump claude-code/.claude-plugin/plugin.json
make release   # cut a GitHub release at the current plugin.json version
                # (requires clean tree, HEAD pushed, no existing tag)
```

`make release` reads the version from `claude-code/.claude-plugin/plugin.json`,
so bump first, commit, push, then release.

### Release Process

Releases follow [Keep a Changelog](https://keepachangelog.com/en/1.1.0/) — the
`[Unreleased]` section in `CHANGELOG.md` accumulates entries as work lands.
Cutting a release is the act of stamping that section with a version + date.

Versioning convention: while the plugin is in `0.x`, treat a `patch` bump as a
user-facing minor and a `minor` bump as a user-facing major. Use `PART=patch`
for normal additions and fixes; reserve `PART=minor` for breaking changes.

Full flow:

1. **Update `CHANGELOG.md`** — rename the `[Unreleased]` heading to
   `[X.Y.Z] — YYYY-MM-DD` and add a fresh empty `[Unreleased]` section above
   it. Today's date in ISO format.
2. **Bump the plugin version** — `make bump PART=patch` (or `minor` / `major`).
   Confirm `claude-code/.claude-plugin/plugin.json` shows the expected version.
3. **Commit** — one `release: vX.Y.Z` commit containing both the CHANGELOG
   update and the `plugin.json` bump.
4. **Push** the branch.
5. **Cut the release** — `make release`. This validates a clean tree, that HEAD
   is on origin, and that the tag doesn't already exist, then POSTs to the
   GitHub releases API tagging the current HEAD as `vX.Y.Z`.

Released tags must not be force-moved or rewritten — the marketplace install
path resolves through them.

## Architecture Overview

kix-agents ships a Claude Code marketplace + plugin — no application code:

- `.claude-plugin/marketplace.json` — marketplace declaration (root)
- `claude-code/.claude-plugin/plugin.json` — plugin manifest
- `claude-code/skills/<name>/SKILL.md` — skill definitions (one folder per
  skill, frontmatter + Markdown body). Each also surfaces as a `/kix:<name>`
  slash command. A skill folder may also bundle scripts/assets it needs at
  runtime (e.g. `claude-code/skills/setup/setup.sh` and
  `claude-code/skills/setup/assets/`), referenced via
  `${CLAUDE_PLUGIN_ROOT}/skills/<name>/…`.
- `claude-code/templates/*.md` — orphaned body templates from removed creation
  skills; not consumed by anything today
- `docs/kix/<bd-id>/spec.md` — long-form specs for non-trivial epics tracked in
  beads
- `docs/kix-agents.md` — what the repo is and how it fits into Kix (the roadmap
  lives in beads — `bd ready` / `bd list`)
- `scripts/bump-plugin.js` — plugin version bumper invoked by `make bump`

## Conventions & Patterns

- **Skill aliases.** Some skills are thin aliases for canonical ones (`fix/` /
  `address/` / `address-pr/` → `fix-pr/`). Edit the canonical `SKILL.md`;
  aliases just point at it.
- **Skill format.** Each capability is a folder under
  `claude-code/skills/<name>/` with a `SKILL.md` (frontmatter + body). Files
  under `commands/` are deprecated upstream — use the skill format for anything
  new.
- **Markdown formatting.** Prettier is the formatter; `make check` blocks
  merges on drift. Run `make autofix` before committing.
- **Releases are tag-driven.** `make release` POSTs to GitHub's releases API;
  the plugin marketplace install path resolves via tags. Never force-tag or
  rewrite published tags.
- **Pre-commit hook.** `.beads/hooks/pre-commit` is the single hook — beads' DB
  → JSONL sync (managed section, between the `BEGIN/END BEADS INTEGRATION`
  markers) followed by the Prettier gate (reject-if-dirty → `make autofix` →
  re-stage → `make check`). `make setup` wires it up by pointing
  `core.hooksPath` at `.beads/hooks/`; run setup once after cloning. Don't add
  a `.git-hooks/` dir — it's gone.
