<!--
  Starting text for the "Beads / session completion / non-interactive shell"
  section of a repo's CLAUDE.md (or AGENTS.md). The /kix:setup skill
  adapts the project-specific bits before inserting it — do not paste verbatim.
-->

## Beads Issue Tracker

This project uses **bd (beads)** for issue tracking. Run `bd prime` to see full
workflow context and commands.

### Quick Reference

```bash
bd ready                # Find available work
bd show <id>            # View issue details
bd update <id> --claim  # Claim work
bd close <id>           # Complete work
```

### Rules

- Use `bd` for ALL task tracking — do NOT use TodoWrite, TaskCreate, or
  markdown TODO lists
- Run `bd prime` for the detailed command reference and session-close protocol
- Use `bd remember` for persistent knowledge — do NOT use MEMORY.md files

## Session Completion

**When ending a work session**, you MUST: file issues for any follow-up work,
run the quality gates if code changed (`make check`), update issue status
(close finished work, update in-progress items), then **push to remote**:

```bash
git pull --rebase
git push
git status   # MUST show "up to date with origin"
```

Work is NOT complete until `git push` succeeds.

## Non-Interactive Shell Commands

**ALWAYS use non-interactive flags** with file operations — `cp`, `mv`, and
`rm` may be aliased to `-i` mode on some systems and hang the agent on a y/n
prompt:

```bash
cp -f source dest      # NOT: cp source dest
mv -f source dest      # NOT: mv source dest
rm -f file             # NOT: rm file
rm -rf directory       # NOT: rm -r directory
```

Other commands that may prompt: `apt-get -y`, `ssh -o BatchMode=yes`,
`scp -o BatchMode=yes`, `HOMEBREW_NO_AUTO_UPDATE=1 brew ...`.

## Build & Test

Formatting is enforced by Prettier via a `pre-commit` hook and `make check`:

```bash
make setup     # install .git-hooks/* into .git/hooks/ (run once after cloning)
make autofix   # prettier --write .
make check     # prettier --check .  (the formatting gate)
```

> Replace this section with the project's real build/test commands — keep the
> Prettier targets, add whatever else this repo needs.
