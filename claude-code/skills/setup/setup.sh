#!/usr/bin/env bash
# setup.sh — drop the Kix repo tooling into the current git repository.
#
# Installs (idempotently):
#   - Prettier config         .prettierrc.json, .prettierignore
#   - Prettier CI workflow     .github/workflows/check.yml (only if absent)
#   - Prettier Makefile        Makefile (only if absent — otherwise reports the
#                              targets it needs so a human can merge them)
#   - pre-commit hook          merged beads-sync + Prettier gate — in
#                              .beads/hooks/ + core.hooksPath if the repo has a
#                              beads tracker, else .git-hooks/ + copied into the
#                              repo's real hooks dir (the `make setup` way)
#   - Claude Code hooks        .claude/hooks/{session-start,install-dolt,
#                              install-bd,bootstrap-bd}.sh and the matching
#                              SessionStart / PreCompact entries in
#                              .claude/settings.json
#   - AGENTS.md alias          AGENTS.md → CLAUDE.md symlink (so the two don't
#                              drift); creates an empty CLAUDE.md if neither
#                              file exists yet
#
# It does NOT: run `bd init`, edit CLAUDE.md/AGENTS.md, commit, push, or open a
# PR. The /kix:setup skill drives those steps and handles merges this script
# can't do safely.
#
# Re-running is safe: existing non-managed files are kept; the Claude hook
# scripts and the settings.json hook entries are upserted.
#
# Bundled assets are looked up next to this script (./assets); override with
# KIX_SETUP_ASSETS=/path/to/assets.
set -euo pipefail

note() { printf 'kix-setup: %s\n' "$*"; }
warn() { printf 'kix-setup: WARNING: %s\n' "$*" >&2; }
die()  { printf 'kix-setup: error: %s\n' "$*" >&2; exit 1; }

# --- banner ------------------------------------------------------------------
# Surface what this script does NOT do, so users running it directly know what
# /kix:setup adds on top. The skill sets KIX_SETUP_QUIET=1 to suppress.
if [ -z "${KIX_SETUP_QUIET:-}" ]; then
  cat >&2 <<'BANNER'
kix-setup: running setup.sh directly — mechanical file ops only.
kix-setup: full workflow (branch + `bd init` + CLAUDE.md content + commit + PR)
kix-setup: lives in the /kix:setup skill. Set KIX_SETUP_QUIET=1 to hide this.
BANNER
fi

# --- locate bundled assets ---------------------------------------------------
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ASSETS_DIR="${KIX_SETUP_ASSETS:-$SCRIPT_DIR/assets}"
[ -d "$ASSETS_DIR" ] || die "assets dir not found: $ASSETS_DIR"

# --- must run inside a git repo; operate from its root -----------------------
git rev-parse --git-dir >/dev/null 2>&1 || die "not inside a git repository"
REPO_ROOT="$(git rev-parse --show-toplevel)"
cd "$REPO_ROOT"
note "target repository: $REPO_ROOT"

needs_attention=()

# --- helpers -----------------------------------------------------------------
copy_if_absent() {  # <asset-relpath> <dest>
  local src="$ASSETS_DIR/$1" dst="$2"
  [ -e "$src" ] || die "missing asset: $src"
  if [ -e "$dst" ]; then
    note "kept existing $dst"
    return 1
  fi
  mkdir -p "$(dirname "$dst")"
  cp -f "$src" "$dst"
  note "created $dst"
  return 0
}

copy_force() {  # <asset-relpath> <dest>  (kix-managed; always overwrite)
  local src="$ASSETS_DIR/$1" dst="$2"
  [ -e "$src" ] || die "missing asset: $src"
  mkdir -p "$(dirname "$dst")"
  cp -f "$src" "$dst"
  chmod +x "$dst" 2>/dev/null || true
  note "wrote $dst"
}

# --- 1. Prettier config ------------------------------------------------------
copy_if_absent prettierrc.json .prettierrc.json || true

if [ ! -e .prettierignore ]; then
  cp -f "$ASSETS_DIR/prettierignore" .prettierignore
  note "created .prettierignore"
else
  while IFS= read -r entry; do
    [ -n "$entry" ] || continue
    if ! grep -qxF "$entry" .prettierignore; then
      printf '%s\n' "$entry" >> .prettierignore
      note "appended '$entry' to .prettierignore"
    fi
  done < "$ASSETS_DIR/prettierignore"
fi

# Prettier CI workflow (mirrors the local `make check` gate).
copy_if_absent check.yml .github/workflows/check.yml || true

# --- 2. pre-commit hook (beads sync + Prettier gate) -------------------------
# One merged hook: beads' DB→JSONL sync section (managed by beads, between the
# BEGIN/END markers) followed by the Prettier gate. The beads section is a
# no-op when `bd` isn't installed, so the same file works either way.
#
#   - repo has a beads tracker (.beads/hooks/ exists): the hook lives in
#     .beads/hooks/ and git is routed there via core.hooksPath, so beads' other
#     hooks (post-merge, pre-push, …) run too.
#   - otherwise: the hook lives in .git-hooks/ and is copied into the repo's
#     real hooks dir (the classic `make setup` mechanism).
if [ -d .beads/hooks ]; then
  cp -f "$ASSETS_DIR/pre-commit" .beads/hooks/pre-commit
  chmod +x .beads/hooks/* 2>/dev/null || true
  note "wrote .beads/hooks/pre-commit (beads sync + Prettier gate)"
  current_hp="$(git config --local --get core.hooksPath 2>/dev/null || true)"
  if [ -z "$current_hp" ]; then
    git config core.hooksPath .beads/hooks
    note "set core.hooksPath = .beads/hooks"
  elif [ "$current_hp" != ".beads/hooks" ]; then
    warn "core.hooksPath is '$current_hp' — not changing it; wire the merged pre-commit (from $ASSETS_DIR/pre-commit) into that dir yourself"
    needs_attention+=("core.hooksPath points at '$current_hp', not .beads/hooks — install the merged pre-commit ($ASSETS_DIR/pre-commit) into that path")
  fi
  if [ -e .git-hooks/pre-commit ]; then
    needs_attention+=("a stale .git-hooks/pre-commit exists but is now bypassed by core.hooksPath — delete .git-hooks/ if it isn't used for anything else")
  fi
else
  if copy_if_absent pre-commit .git-hooks/pre-commit; then
    chmod +x .git-hooks/pre-commit
  elif ! cmp -s "$ASSETS_DIR/pre-commit" .git-hooks/pre-commit; then
    warn "an existing .git-hooks/pre-commit was left in place and differs from the kix one — make sure it runs the Prettier gate (or merge it with $ASSETS_DIR/pre-commit)"
    needs_attention+=("review .git-hooks/pre-commit — kept the repo's existing hook; confirm it still enforces 'make check'")
  fi
  # Install repo hooks into the real hooks dir (equivalent to `make setup`).
  HOOKS_DIR="$(git rev-parse --git-path hooks)"
  mkdir -p "$HOOKS_DIR"
  for h in .git-hooks/*; do
    [ -e "$h" ] || continue
    name="$(basename "$h")"
    if [ -e "$HOOKS_DIR/$name" ] && ! cmp -s "$h" "$HOOKS_DIR/$name"; then
      warn "existing $HOOKS_DIR/$name differs from .git-hooks/$name — overwriting (the repo's source of truth is .git-hooks/)"
    fi
    cp -f "$h" "$HOOKS_DIR/$name"
    chmod +x "$HOOKS_DIR/$name" 2>/dev/null || true
    note "installed git hook: $name"
  done
fi

# --- 3. Makefile (Prettier targets) -----------------------------------------
if [ ! -e Makefile ]; then
  cp -f "$ASSETS_DIR/Makefile" Makefile
  note "created Makefile"
else
  have_all=1; have_setup=1; have_autofix=1; have_check=1
  grep -qE '^all:'     Makefile || have_all=0
  grep -qE '^setup:'   Makefile || have_setup=0
  grep -qE '^autofix:' Makefile || have_autofix=0
  grep -qE '^check:'   Makefile || have_check=0
  if [ "$have_setup$have_autofix$have_check" != "111" ]; then
    warn "Makefile exists but is missing kix targets (setup=$have_setup autofix=$have_autofix check=$have_check) — not edited; merge these in:"
    sed 's/^/    /' "$ASSETS_DIR/Makefile" >&2
    needs_attention+=("merge the 'setup' / 'autofix' / 'check' targets into the existing Makefile (template: $ASSETS_DIR/Makefile)")
  else
    note "Makefile already has setup/autofix/check"
  fi
fi

# --- 4. Claude Code hook scripts --------------------------------------------
copy_force hooks/session-start.sh  .claude/hooks/session-start.sh
copy_force hooks/install-dolt.sh   .claude/hooks/install-dolt.sh
copy_force hooks/install-bd.sh     .claude/hooks/install-bd.sh
copy_force hooks/bootstrap-bd.sh   .claude/hooks/bootstrap-bd.sh

# --- 5. .claude/settings.json hook entries ----------------------------------
command -v jq >/dev/null 2>&1 || die "jq is required to merge .claude/settings.json"
SETTINGS=".claude/settings.json"
mkdir -p .claude
[ -e "$SETTINGS" ] || { printf '{}\n' > "$SETTINGS"; note "created $SETTINGS"; }

SS_HOOK='$CLAUDE_PROJECT_DIR/.claude/hooks/session-start.sh'
tmp="$(mktemp)"
jq --arg ss "$SS_HOOK" '
  def cmds($arr): [ ($arr // [])[]?.hooks[]?.command // empty ];
  def add_if_missing($arr; $entry; $cmd):
    if (cmds($arr) | any(. == $cmd)) then $arr else ($arr + [$entry]) end;
  .hooks = (.hooks // {})
  | .hooks.PreCompact = add_if_missing(.hooks.PreCompact // [];
      {"hooks":[{"type":"command","command":"bd prime"}],"matcher":""}; "bd prime")
  | .hooks.SessionStart = add_if_missing(.hooks.SessionStart // [];
      {"hooks":[{"type":"command","command":$ss}]}; $ss)
  | .hooks.SessionStart = add_if_missing(.hooks.SessionStart;
      {"hooks":[{"type":"command","command":"bd prime"}],"matcher":""}; "bd prime")
' "$SETTINGS" > "$tmp" || { rm -f "$tmp"; die "failed to merge $SETTINGS (invalid JSON?)"; }
if cmp -s "$tmp" "$SETTINGS"; then
  rm -f "$tmp"
  note "$SETTINGS already has the SessionStart/PreCompact hooks"
else
  mv -f "$tmp" "$SETTINGS"
  note "merged SessionStart + PreCompact hooks into $SETTINGS"
fi

# --- 6. .beads permissions ---------------------------------------------------
# bd warns when .beads is group/other-readable; tighten it if the repo already
# has a beads tracker (this script does not run `bd init` — the skill does).
if [ -d .beads ]; then
  chmod 700 .beads 2>/dev/null && note "set .beads to 0700" || true
fi

# --- 7. AGENTS.md ↔ CLAUDE.md alias -----------------------------------------
# Mirror kix-agents convention: AGENTS.md is a symlink to CLAUDE.md so agent
# instructions don't drift between the two files. The skill's Step 6 fills the
# CLAUDE.md content; this section just enforces the symlink.
if [ -L AGENTS.md ] && [ "$(readlink AGENTS.md)" = "CLAUDE.md" ]; then
  note "AGENTS.md already symlinked to CLAUDE.md"
elif [ -f AGENTS.md ] && [ ! -e CLAUDE.md ]; then
  mv -f AGENTS.md CLAUDE.md
  ln -s CLAUDE.md AGENTS.md
  note "renamed AGENTS.md → CLAUDE.md and symlinked AGENTS.md → CLAUDE.md"
elif [ -f AGENTS.md ] && [ -e CLAUDE.md ]; then
  warn "both CLAUDE.md and AGENTS.md exist as regular files — merge by hand"
  needs_attention+=("merge AGENTS.md into CLAUDE.md, then: rm AGENTS.md && ln -s CLAUDE.md AGENTS.md")
else
  if [ ! -e CLAUDE.md ]; then
    : > CLAUDE.md
    note "created empty CLAUDE.md (skill fills it in Step 6)"
  fi
  if [ ! -e AGENTS.md ]; then
    ln -s CLAUDE.md AGENTS.md
    note "symlinked AGENTS.md → CLAUDE.md"
  fi
fi

# --- summary -----------------------------------------------------------------
echo
note "done. Review the changes with: git status && git diff"
if [ "${#needs_attention[@]}" -gt 0 ]; then
  echo
  note "needs manual attention:"
  for item in "${needs_attention[@]}"; do printf 'kix-setup:   - %s\n' "$item"; done
fi
echo
note "not done by this script (the /kix:setup skill handles these):"
note "  - bd init   (give this repo a beads issue tracker, if it doesn't have one)"
note "  - add a Beads section to CLAUDE.md (AGENTS.md is now a symlink to it)"
note "  - enable the kix plugin for the repo ('kix@kix-agents': true under enabledPlugins)"
note "  - commit, push, open the PR"
