#!/usr/bin/env bash
# Ensure the bd (beads) CLI is available at the pinned version or newer.
# Downloads a pinned release from GitHub into ~/.local/bin when what is on PATH
# is missing or older, so that remote/cloud Claude Code sessions can run beads
# commands.
#
# Override the version with KIX_BD_VERSION=<x.y.z>.
set -euo pipefail

# Moving this pin across a bd schema boundary is not a drop-in: bd refuses to
# migrate a remote-backed database on its own, so the remote has to be migrated
# first — one designated clone runs `BD_ALLOW_REMOTE_MIGRATE=1 bd migrate &&
# bd dolt push`, every other clone re-runs `bd bootstrap` — and only then does
# the pin move. That was done for v32 -> v53 before this went to 1.2.2.
version="${KIX_BD_VERSION:-1.2.2}"

bin_dir="${HOME}/.local/bin"

# Version of the bd at $1 ("bd" for whatever PATH resolves, or a full path).
# Empty when it is missing or its version line does not parse.
bd_version_of() {
  "$1" version 2>/dev/null | sed -n 's/^bd version \([0-9][0-9.]*\).*/\1/p' | head -1 || true
}

# Is $1 older than $2? Field-by-field numeric compare; `sort -V` is not
# portable enough to rely on.
bd_is_older() {
  awk -v a="$1" -v b="$2" 'BEGIN {
    na = split(a, x, "."); nb = split(b, y, ".");
    n = (na > nb ? na : nb);
    for (i = 1; i <= n; i++) {
      ai = (i <= na ? x[i] + 0 : 0); bi = (i <= nb ? y[i] + 0 : 0);
      if (ai < bi) { print "yes"; exit }
      if (ai > bi) { print "no"; exit }
    }
    print "no"
  }'
}

# An older bd earlier on PATH still wins after this script installs, which would
# silently undo the upgrade. Nothing here can reorder the caller's PATH, so make
# the situation visible instead.
warn_if_shadowed() {
  resolved="$(command -v bd 2>/dev/null || true)"
  if [ -n "$resolved" ] && [ "$resolved" != "${bin_dir}/bd" ]; then
    printf 'install-bd: %s is installed at %s, but %s comes first on PATH\n' \
      "$version" "${bin_dir}/bd" "$resolved" >&2
  fi
}

# Presence alone is not enough. A machine that already has an older bd (from
# Homebrew, say) would keep it forever under a bare `command -v` check, and a
# fleet split across bd versions sharing one Dolt remote breaks the moment
# either side migrates the schema — the old side can no longer read it. So
# compare against the pin: same or newer is left alone, older is replaced.
installed="$(bd_version_of bd)"
if [ -n "$installed" ]; then
  [ "$(bd_is_older "$installed" "$version")" = "yes" ] || exit 0
elif command -v bd >/dev/null 2>&1; then
  # Installed but its version line did not parse — replacing it would be a
  # guess, so say so and leave it be.
  printf 'install-bd: bd is installed but its version could not be read; leaving it alone\n' >&2
  exit 0
fi

# What PATH resolves may not be what this script installed: an older bd ahead of
# ~/.local/bin shadows it, and reading that one would re-download the release on
# every session start forever. Decide on the binary this script owns.
owned="$(bd_version_of "${bin_dir}/bd")"
if [ -n "$owned" ] && [ "$(bd_is_older "$owned" "$version")" != "yes" ]; then
  warn_if_shadowed
  exit 0
fi

if [ -n "$installed" ]; then
  printf 'install-bd: bd %s is older than the pinned %s; installing %s\n' \
    "$installed" "$version" "$version" >&2
fi

case "$(uname -s)" in
  Linux)  os=linux ;;
  Darwin) os=darwin ;;
  *) printf 'install-bd: skipped (unsupported OS: %s)\n' "$(uname -s)" >&2; exit 0 ;;
esac

case "$(uname -m)" in
  x86_64|amd64)  arch=amd64 ;;
  arm64|aarch64) arch=arm64 ;;
  *) printf 'install-bd: skipped (unsupported arch: %s)\n' "$(uname -m)" >&2; exit 0 ;;
esac

mkdir -p "$bin_dir"

tarball="beads_${version}_${os}_${arch}.tar.gz"
url="https://github.com/gastownhall/beads/releases/download/v${version}/${tarball}"

tmpdir="$(mktemp -d)"
trap 'rm -rf "$tmpdir"' EXIT

if ! curl -fsSL "$url" -o "${tmpdir}/${tarball}"; then
  printf 'install-bd: download failed: %s\n' "$url" >&2
  exit 1
fi

if ! tar -xzf "${tmpdir}/${tarball}" -C "$tmpdir"; then
  printf 'install-bd: extract failed: %s\n' "$tarball" >&2
  exit 1
fi

if [ ! -x "${tmpdir}/bd" ]; then
  printf 'install-bd: bd binary missing from %s\n' "$tarball" >&2
  exit 1
fi

install -m 0755 "${tmpdir}/bd" "${bin_dir}/bd"

warn_if_shadowed
