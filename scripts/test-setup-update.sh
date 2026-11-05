#!/usr/bin/env bash
# Tests for setup.sh --update, the mode kix:update runs (kxa-6ei.9): it refuses
# a repo without Kix, brings a Kix repo up to date, leaves first-install-only
# files alone, and a second run changes nothing.
set -uo pipefail

# A suite run from the pre-commit hook inherits GIT_DIR and friends; the
# throwaway repos below must not touch the real one (kxa-6df).
unset GIT_DIR GIT_WORK_TREE GIT_INDEX_FILE GIT_OBJECT_DIRECTORY GIT_COMMON_DIR \
  GIT_PREFIX GIT_ALTERNATE_OBJECT_DIRECTORIES

SETUP=${SETUP:-"$(cd "$(dirname "$0")/.." && pwd)/claude-code/skills/setup/setup.sh"}
failures=0
tmp=$(mktemp -d)
trap 'rm -rf "$tmp"' EXIT
export KIX_SETUP_QUIET=1

check() {
  local what=$1 got=$2 want=$3
  if [ "$got" = "$want" ]; then
    echo "  ok: $what"
  else
    echo "  FAIL: $what — got [$got], want [$want]"
    failures=$((failures + 1))
  fi
}

fresh() { # <name> → a repo with one commit on main, no remote
  local r="$tmp/$1"
  git init -q -b main "$r"
  git -C "$r" config user.email t@example.invalid
  git -C "$r" config user.name t
  git -C "$r" config commit.gpgsign false
  echo base >"$r/a.txt"
  git -C "$r" add a.txt
  git -C "$r" commit -q -m base
  echo "$r"
}

# The installed pre-commit hook runs `make check`; these commits only snapshot.
commit_all() { git -C "$1" add -A && git -C "$1" commit -q --no-verify -m "$2"; }

setup() { (cd "$1" && shift && bash "$SETUP" "$@" >/dev/null 2>&1); }

kix_repo() { # <name> → a repo with Kix installed by setup.sh and committed
  local r
  r=$(fresh "$1")
  mkdir -p "$r/.beads/hooks"
  setup "$r"
  commit_all "$r" kix
  echo "$r"
}

echo "unknown flag: refused"
r=$(fresh flag)
setup "$r" --bogus
check "exit status" "$?" "1"
check "tree untouched" "$(git -C "$r" status --porcelain)" ""

echo "no Kix: refused, nothing written"
r=$(fresh nokix)
out=$(cd "$r" && bash "$SETUP" --update 2>&1)
check "exit status" "$?" "1"
check "says Kix is missing" "$(printf '%s' "$out" | grep -c 'Kix is not installed here')" "1"
check "tree untouched" "$(git -C "$r" status --porcelain)" ""

echo "Kix repo with stale tooling: brought up to date"
r=$(kix_repo stale)
echo '# stale' >"$r/.kix/hooks/prime.sh"
rm -f "$r/.kix/hooks/check-prime.sh"
jq '.hooks.SessionStart = []' "$r/.claude/settings.json" >"$tmp/s.json" &&
  mv -f "$tmp/s.json" "$r/.claude/settings.json"
commit_all "$r" stale
setup "$r" --update
check "exit status" "$?" "0"
check "prime.sh refreshed" \
  "$(cmp -s "$r/.kix/hooks/prime.sh" "$(dirname "$SETUP")/assets/kix/hooks/prime.sh" && echo same)" "same"
check "check-prime.sh restored" "$(test -x "$r/.kix/hooks/check-prime.sh" && echo yes)" "yes"
check "SessionStart entry restored" \
  "$(jq '[.hooks.SessionStart[].hooks[].command] | length' "$r/.claude/settings.json")" "1"

echo "Kix repo without CLAUDE.md: update leaves it out"
r=$(kix_repo noclaude)
git -C "$r" rm -q CLAUDE.md AGENTS.md
commit_all "$r" "drop agent files"
setup "$r" --update
check "exit status" "$?" "0"
check "no CLAUDE.md" "$(test -e "$r/CLAUDE.md" && echo yes || echo no)" "no"
check "no AGENTS.md" "$(test -L "$r/AGENTS.md" && echo yes || echo no)" "no"

echo "Kix repo with its own pre-commit additions: hook kept, merge flagged"
r=$(kix_repo ownhook)
echo '# repo-only gate' >>"$r/.beads/hooks/pre-commit"
commit_all "$r" "own hook"
out=$(cd "$r" && bash "$SETUP" --update 2>&1)
check "exit status" "$?" "0"
check "hook kept" "$(tail -1 "$r/.beads/hooks/pre-commit")" "# repo-only gate"
check "merge flagged" "$(printf '%s' "$out" | grep -c 'merge .* into .beads/hooks/pre-commit by hand')" "1"

echo "second update run: nothing changes"
r=$(kix_repo twice)
setup "$r" --update
commit_all "$r" first >/dev/null || true
setup "$r" --update
check "exit status" "$?" "0"
check "tree clean" "$(git -C "$r" status --porcelain)" ""
check "core.hooksPath" "$(git -C "$r" config --get core.hooksPath)" ".beads/hooks"

if [ "$failures" -gt 0 ]; then
  echo "$failures failure(s)"
  exit 1
fi
echo "all passed"
