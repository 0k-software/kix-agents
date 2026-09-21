#!/usr/bin/env bash
# Kix prime hook: inject the beads workflow context into an agent session.
#
# `.beads/PRIME.md` overrides the whole `bd prime` output — persistent memories
# included — so whenever that override is in place the memories have to be
# injected separately. `--memories-only` alone is NOT enough: as of bd 1.2.2 it
# honours the override too and just reprints the file. Only `--export` bypasses
# it, so the pair `--export --memories-only` is what yields the memories and
# nothing else. Without the override a plain `bd prime` already carries them,
# and a second call would duplicate them.
#
# Agent-neutral: called from .kix/hooks/session-start.sh (Claude Code + Codex)
# and from the Claude Code PreCompact hook in .claude/settings.json.
set -euo pipefail

export PATH="${HOME}/.local/bin:${PATH}"

command -v bd >/dev/null 2>&1 || exit 0

if [ -n "${CLAUDE_PROJECT_DIR:-}" ]; then
  project_dir="$CLAUDE_PROJECT_DIR"
elif project_dir="$(git rev-parse --show-toplevel 2>/dev/null)"; then
  :
else
  exit 0
fi

bd -C "$project_dir" prime || true

if [ -f "$project_dir/.beads/PRIME.md" ]; then
  bd -C "$project_dir" prime --export --memories-only || true
fi
