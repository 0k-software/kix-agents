#!/usr/bin/env bash
# Tests for the autocommit Stop hook's guards (kxa-6ei.8): each case it must
# stay quiet on, the protected-branch note, and the one-call commit block.
set -uo pipefail

# A suite run from the pre-commit hook inherits GIT_DIR and friends; the
# throwaway repos below must not touch the real one (kxa-6df).
unset GIT_DIR GIT_WORK_TREE GIT_INDEX_FILE GIT_OBJECT_DIRECTORY GIT_COMMON_DIR \
  GIT_PREFIX GIT_ALTERNATE_OBJECT_DIRECTORIES

HOOK=${HOOK:-"$(cd "$(dirname "$0")/.." && pwd)/claude-code/hooks/autocommit.sh"}
failures=0
tmp=$(mktemp -d)
trap 'rm -rf "$tmp"' EXIT

check() {
  local what=$1 got=$2 want=$3
  if [ "$got" = "$want" ]; then
    echo "  ok: $what"
  else
    echo "  FAIL: $what — got [$got], want [$want]"
    failures=$((failures + 1))
  fi
}

# Run the hook from outside the repo, as a session rooted elsewhere would.
run() { # <cwd> [stop_hook_active]
  (cd "$tmp" && printf '{"cwd":"%s","stop_hook_active":%s}' "$1" "${2:-false}" |
    bash "$HOOK")
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

echo "not a work tree: silent"
mkdir "$tmp/plain"
check "output" "$(run "$tmp/plain")" ""

echo "clean tree: silent"
r=$(fresh clean)
check "output" "$(run "$r")" ""

echo "beads churn alone: silent"
r=$(fresh beads)
mkdir "$r/.beads" && echo '{}' >"$r/.beads/issues.jsonl"
git -C "$r" add .beads && git -C "$r" commit -q -m beads
echo '{"id":1}' >"$r/.beads/issues.jsonl"
check "output" "$(run "$r")" ""

echo "stop_hook_active: silent"
r=$(fresh active)
echo change >"$r/a.txt"
check "output" "$(run "$r" true)" ""

echo "mid merge: silent"
r=$(fresh merge)
echo change >"$r/a.txt"
git -C "$r" rev-parse HEAD >"$r/.git/MERGE_HEAD"
check "output" "$(run "$r")" ""

echo "mid rebase: silent"
r=$(fresh rebase)
echo change >"$r/a.txt"
mkdir "$r/.git/rebase-merge"
check "output" "$(run "$r")" ""

echo "protected branch (cached): skip note, no block"
r=$(fresh protected)
echo change >"$r/a.txt"
git -C "$r" config autocommit.main.blocked "pull requests required"
git -C "$r" config autocommit.main.checkedAt "$(date +%s)"
out=$(run "$r")
check "no decision" "$(jq -r '.decision // ""' <<<"$out")" ""
check "names the reason" \
  "$(jq -r .systemMessage <<<"$out" | grep -c 'main is protected (pull requests required)')" "1"

echo "dirty working branch: blocks with stage-read, then commit"
r=$(fresh dirty)
echo change >"$r/a.txt"
out=$(run "$r")
check "decision" "$(jq -r .decision <<<"$out")" "block"
reason=$(jq -r .reason <<<"$out")
check "stages, then lists" "$(grep -c 'git add -A && git diff --cached --stat && git log -5' <<<"$reason")" "1"
check "commit from heredoc" "$(grep -c "git commit -F - <<'EOF'" <<<"$reason")" "1"
check "user-edits skip" "$(grep -c 'dirty is the user' <<<"$reason")" "1"
check "no-progress stop" "$(grep -c 'no progress' <<<"$reason")" "1"
check "tree left uncommitted" "$(git -C "$r" status --porcelain)" " M a.txt"

if [ "$failures" -eq 0 ]; then
  echo "all passed"
else
  echo "$failures check(s) failed"
fi
exit $((failures > 0))
