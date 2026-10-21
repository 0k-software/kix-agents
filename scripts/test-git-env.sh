#!/usr/bin/env bash
# Runs every other scripts/test-*.sh the way the pre-commit hook does: with
# GIT_DIR, GIT_WORK_TREE and GIT_INDEX_FILE exported for a repo — here a
# sentinel repo instead of the real one. A suite that forgets to unset them
# sends its throwaway `git init/config/add` into that repo (kxa-6df: it re-inited
# kix-agents as bare with a fake user), so the sentinel must come out byte for
# byte as it went in, and each suite must still pass.
#
# Run: bash scripts/test-git-env.sh [suite...]   (or: make test)
# With no arguments it runs every scripts/test-*.sh except itself.
set -uo pipefail

# This script is itself run from the hook with those variables set for the real
# repo; building the sentinel under them re-inits the real repo. Drop them first.
unset GIT_DIR GIT_WORK_TREE GIT_INDEX_FILE GIT_OBJECT_DIRECTORY GIT_COMMON_DIR \
  GIT_PREFIX GIT_ALTERNATE_OBJECT_DIRECTORIES

cd "$(dirname "$0")/.."
self=scripts/test-git-env.sh

if [ $# -gt 0 ]; then
  suites=("$@")
else
  suites=()
  for s in scripts/test-*.sh; do
    [ "$s" = "$self" ] || suites+=("$s")
  done
fi

tmproot=$(mktemp -d)
trap 'rm -rf "$tmproot"' EXIT

sentinel="$tmproot/sentinel"
# No sentinel means empty snapshots that always match: fail instead.
{
  git init -q -b main "$sentinel" &&
    git -C "$sentinel" config user.email sentinel@example.invalid &&
    git -C "$sentinel" config user.name sentinel &&
    echo sentinel >"$sentinel/file" &&
    git -C "$sentinel" add file &&
    git -C "$sentinel" -c commit.gpgsign=false commit -q -m sentinel
} || {
  echo "FAIL: could not build the sentinel repo"
  exit 1
}

# Every file in the repo and its .git, with its content hash.
snapshot() { (cd "$sentinel" && find . -type f -exec shasum {} + | sort -k2); }
before=$(snapshot)

failures=0
for s in "${suites[@]}"; do
  case $(head -n1 "$s") in *bash*) sh=bash ;; *) sh=sh ;; esac
  echo "== $s (GIT_DIR=sentinel)"
  if GIT_DIR="$sentinel/.git" GIT_WORK_TREE="$sentinel" \
    GIT_INDEX_FILE="$sentinel/.git/index" "$sh" "$s"; then
    echo "  ok: $s passes"
  else
    echo "  FAIL: $s fails"
    failures=$((failures + 1))
  fi
  after=$(snapshot)
  if [ "$after" = "$before" ]; then
    echo "  ok: $s leaves the sentinel repo untouched"
  else
    echo "  FAIL: $s wrote to the repo in GIT_DIR:"
    diff <(echo "$before") <(echo "$after") | sed 's/^/    /'
    failures=$((failures + 1))
    before=$after
  fi
done

if [ "$failures" -eq 0 ]; then
  echo "all passed"
else
  echo "$failures check(s) failed"
fi
exit $((failures > 0))
