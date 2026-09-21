#!/usr/bin/env bash
# Kix PRIME.md staleness gate.
#
# .beads/PRIME.md is a hand-edited snapshot of one bd version's `bd prime`
# output, so a bd upgrade silently leaves it stale. This compares the stamp in
# its header against the bd version pinned in .kix/hooks/install-bd.sh — the
# pin, deliberately, and not the locally installed bd: install-bd.sh installs
# "pin or newer", so a machine running a newer bd must not fail a gate nobody
# in the repo can fix.
#
# Fails loudly when they diverge; the fix is manual (re-export, merge, bump the
# stamp). Pass --warn to report without failing (session-start hook).
set -euo pipefail

warn_only=0
[ "${1:-}" = "--warn" ] && warn_only=1

if [ -n "${CLAUDE_PROJECT_DIR:-}" ]; then
  project_dir="$CLAUDE_PROJECT_DIR"
elif project_dir="$(git rev-parse --show-toplevel 2>/dev/null)"; then
  :
else
  exit 0
fi

prime_file="$project_dir/.beads/PRIME.md"
install_bd="$project_dir/.kix/hooks/install-bd.sh"

# Nothing to check in a repo that has not adopted the override (or the hooks).
[ -f "$prime_file" ] || exit 0
[ -f "$install_bd" ] || exit 0

stamped="$(sed -n 's/.*kix-prime: bd \([0-9][0-9.]*\).*/\1/p' "$prime_file" | head -1)"
pinned="$(sed -n 's/^version="\${KIX_BD_VERSION:-\([0-9][0-9.]*\)}"/\1/p' "$install_bd" | head -1)"

report() {
  printf 'kix-check-prime: %s\n' "$1" >&2
  [ "$warn_only" = 1 ] && exit 0
  exit 1
}

[ -n "$stamped" ] || report "no 'kix-prime: bd <version>' stamp in .beads/PRIME.md — add one matching the pin in .kix/hooks/install-bd.sh"
[ -n "$pinned" ] || report "could not read the bd pin from .kix/hooks/install-bd.sh"

if [ "$stamped" != "$pinned" ]; then
  report "$(printf '.beads/PRIME.md is stamped for bd %s but the pin is bd %s.\n  Refresh it by hand:\n    bd prime --export > /tmp/prime-%s.md\n    diff /tmp/prime-%s.md .beads/PRIME.md   # merge the upstream changes you want\n    # then bump the stamp to: <!-- kix-prime: bd %s -->' \
    "$stamped" "$pinned" "$pinned" "$pinned" "$pinned")"
fi
