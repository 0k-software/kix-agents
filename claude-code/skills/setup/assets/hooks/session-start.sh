#!/bin/bash
# Kix SessionStart hook: make a fresh clone (e.g. a cloud Claude Code session)
# self-sufficient — install the git hooks, install the dolt + bd CLIs, and
# bootstrap the beads database. Idempotent; safe to run on every session start.
set -euo pipefail

cd "$CLAUDE_PROJECT_DIR"

# Wire up repo git hooks (equivalent to `make setup`, but without depending on
# the Makefile so this still works if the Prettier targets weren't merged in).
if [ -d .beads/hooks ]; then
  git config core.hooksPath .beads/hooks 2>/dev/null || true
  chmod +x .beads/hooks/* 2>/dev/null || true
elif [ -d .git-hooks ] && ls .git-hooks/* >/dev/null 2>&1; then
  hooks_dir="$(git rev-parse --git-path hooks 2>/dev/null || echo .git/hooks)"
  mkdir -p "$hooks_dir"
  cp -f .git-hooks/* "$hooks_dir"/ 2>/dev/null || true
  chmod +x "$hooks_dir"/* 2>/dev/null || true
fi

"$CLAUDE_PROJECT_DIR/.claude/hooks/install-dolt.sh" || true
"$CLAUDE_PROJECT_DIR/.claude/hooks/install-bd.sh" || true
"$CLAUDE_PROJECT_DIR/.claude/hooks/bootstrap-bd.sh" || true
