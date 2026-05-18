#!/usr/bin/env bash
# Kix Codex SessionStart hook: make Codex sessions as self-sufficient as
# Claude Code sessions by wiring git hooks, installing dolt + bd, bootstrapping
# beads, and surfacing bd workflow context at session start.
set -euo pipefail

export PATH="${HOME}/.local/bin:${PATH}"

if repo_root="$(git rev-parse --show-toplevel 2>/dev/null)"; then
  cd "$repo_root"
else
  printf 'kix-codex-session-start: skipped (not inside a git repository)\n' >&2
  exit 0
fi

# Mirror the Claude SessionStart behavior. Prefer the repo's make target when
# present, because it may include repo-specific hook wiring. Fall back to the
# generic hook install logic used by the Claude hook asset.
if command -v make >/dev/null 2>&1 && [ -f Makefile ] && grep -Eq '^setup:' Makefile; then
  make setup >/dev/null 2>&1 || true
elif [ -d .beads/hooks ]; then
  git config core.hooksPath .beads/hooks 2>/dev/null || true
  chmod +x .beads/hooks/* 2>/dev/null || true
elif [ -d .git-hooks ] && find .git-hooks -maxdepth 1 -type f 2>/dev/null | grep -q .; then
  hooks_dir="$(git rev-parse --git-path hooks 2>/dev/null || echo .git/hooks)"
  mkdir -p "$hooks_dir"
  cp -f .git-hooks/* "$hooks_dir"/ 2>/dev/null || true
  chmod +x "$hooks_dir"/* 2>/dev/null || true
fi

hook_dir="${KIX_CODEX_HOOK_DIR:-$repo_root/.codex/hooks}"
"$hook_dir/install-dolt.sh" || true
"$hook_dir/install-bd.sh" || true
"$hook_dir/bootstrap-bd.sh" || true

if command -v bd >/dev/null 2>&1; then
  bd prime || true
fi
