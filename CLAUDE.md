# Project Instructions for AI Agents

This file provides instructions and context for AI coding agents working on this project.

<!-- BEGIN BEADS INTEGRATION v:1 profile:minimal hash:ca08a54f -->
## Beads Issue Tracker

This project uses **bd (beads)** for issue tracking. Run `bd prime` to see full workflow context and commands.

### Quick Reference

```bash
bd ready              # Find available work
bd show <id>          # View issue details
bd update <id> --claim  # Claim work
bd close <id>         # Complete work
```

### Rules

- Use `bd` for ALL task tracking — do NOT use TodoWrite, TaskCreate, or markdown TODO lists
- Run `bd prime` for detailed command reference and session close protocol
- Use `bd remember` for persistent knowledge — do NOT use MEMORY.md files

## Session Completion

**When ending a work session**, you MUST complete ALL steps below. Work is NOT complete until `git push` succeeds.

**MANDATORY WORKFLOW:**

1. **File issues for remaining work** - Create issues for anything that needs follow-up
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


## Build & Test

This repo is Markdown content (slash commands, templates, docs) — there is no runtime and no test suite. The toolchain is Prettier + a small release pipeline:

```bash
make setup     # install .git-hooks/* into .git/hooks/
make autofix   # prettier --write .
make check     # prettier --check .  (the formatting gate)
make all       # autofix && check
make bump PART=patch|minor|major   # bump claude-code/.claude-plugin/plugin.json
make release   # cut a GitHub release at the current plugin.json version
                # (requires clean tree, HEAD pushed, no existing tag)
```

`make release` reads the version from `claude-code/.claude-plugin/plugin.json`, so bump first, commit, push, then release.

## Architecture Overview

kix-agents ships a Claude Code marketplace + plugin — no application code:

- `.claude-plugin/marketplace.json` — marketplace declaration (root)
- `claude-code/.claude-plugin/plugin.json` — plugin manifest
- `claude-code/skills/<name>/SKILL.md` — skill definitions (one folder per skill, frontmatter + Markdown body). Each also surfaces as a `/kix:<name>` slash command.
- `claude-code/templates/*.md` — body templates stamped out by `kix:create-task` / `kix:create-pitch` (`task-feature.md`, `task-chore.md`, `task-bug.md`, `task-enhancement.md`, `pitch.md`)
- `docs/kix/<bd-id>/spec.md` — long-form specs for non-trivial epics tracked in beads
- `docs/kix-agents.md`, `docs/roadmap.md` — what the repo is and where it's going
- `scripts/bump-plugin.js` — plugin version bumper invoked by `make bump`

Long-term direction (per `docs/kix-agents.md`): canonical, agent-agnostic skills live under `.kix/skills/` and are **compiled** into per-harness layouts (`claude-code/`, `codex/`, …). Today those harness dirs are hand-authored — treat them as source, not generated output, until the compiler exists.

## Conventions & Patterns

- **Skill aliases.** Some skills are thin aliases for canonical ones (`pitch/` → `create-pitch/`, `task/` → `create-task/`, `request/` / `capture/` → `create-request/`, `fix/` / `address/` / `address-pr/` → `fix-pr/`). Edit the canonical `SKILL.md`; aliases just point at it.
- **Skill format.** Each capability is a folder under `claude-code/skills/<name>/` with a `SKILL.md` (frontmatter + body). Files under `commands/` are deprecated upstream — use the skill format for anything new.
- **Markdown formatting.** Prettier is the formatter; `make check` blocks merges on drift. Run `make autofix` before committing.
- **Releases are tag-driven.** `make release` POSTs to GitHub's releases API; the plugin marketplace install path resolves via tags. Never force-tag or rewrite published tags.
- **Pre-commit hook.** `.git-hooks/pre-commit` is installed by `make setup` — run setup once after cloning so commits get the same checks CI runs.
