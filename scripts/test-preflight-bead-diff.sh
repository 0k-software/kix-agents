#!/usr/bin/env bash
# Tests for the bead side of `preflight-checks` (kxa-a9i): the bd-mark
# subcommand and the beads DB it finds.
#
# Every case clones a throwaway bare origin under a temp dir and, where it needs
# one, inits a throwaway beads DB there, so nothing here reads or writes a real
# repo or tracker. Cases that need a real bd and dolt print a skip line when
# either is missing (CI has neither).
set -uo pipefail

# Run from the pre-commit hook, git exports GIT_DIR, GIT_INDEX_FILE and friends
# for the real repo (kxa-6df). Drop them, and anything that would point bd at
# a real DB.
unset GIT_DIR GIT_WORK_TREE GIT_INDEX_FILE GIT_OBJECT_DIRECTORY GIT_COMMON_DIR \
  GIT_PREFIX GIT_ALTERNATE_OBJECT_DIRECTORIES BEADS_DIR BEADS_DB

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
BIN=${PREFLIGHT_CHECKS_BIN:-"$ROOT/claude-code/bin/preflight-checks"}
failures=0

git_q() { git -c user.name=t -c user.email=t@t "$@" >/dev/null 2>&1; }

setup() {
  work=$(mktemp -d)
  export CLAUDE_CONFIG_DIR="$work/claude-config"
  export CLAUDE_CODE_SESSION_ID=s1
  git_q init -q --bare -b main "$work/origin.git"
  git_q clone -q "$work/origin.git" "$work/repo"
  cd "$work/repo" || exit 1
  git_q commit -q --allow-empty -m init
  git_q push -q origin HEAD:main
  store="$work/repo/.git/kix/checks/s1"
}

teardown() {
  cd / || exit 1
  rm -rf "$work"
}

check() {
  local what=$1 got=$2 want=$3
  if [ "$got" = "$want" ]; then
    echo "  ok: $what"
  else
    echo "  FAIL: $what — got [$got], want [$want]"
    failures=$((failures + 1))
  fi
}

have_beads() { command -v bd >/dev/null 2>&1 && command -v dolt >/dev/null 2>&1; }

# A beads DB in the current repo with two issues; ids in $A and $B.
setup_beads() {
  bd init --prefix t --quiet --sandbox >/dev/null 2>&1 || return 1
  A=$(bd --sandbox create --title A --type task --silent 2>/dev/null)
  B=$(bd --sandbox create --title B --type task --silent 2>/dev/null)
  [ -n "$A" ] && [ -n "$B" ]
}

skip() { echo "  skip: $1 (no bd/dolt)"; }

kinds() { [ -f "$store/bd.jsonl" ] && jq -rs --arg k "$1" 'map(select(.kind == $k)) | length' "$store/bd.jsonl" || echo 0; }

echo "start mark is written once"
setup
if have_beads && setup_beads; then
  "$BIN" bd-mark start
  "$BIN" bd-mark start
  check "one start line" "$(kinds start)" "1"
  check "commit is a dolt hash" "$(jq -r 'select(.kind == "start") | .commit' "$store/bd.jsonl" | grep -cE '^[0-9a-v]{32}$')" "1"
else
  skip "start mark"
fi
teardown

echo "review mark appends and prints"
setup
if have_beads && setup_beads; then
  out=$("$BIN" bd-mark review)
  check "prints the review line" "$(printf '%s' "$out" | grep -cE '^👀 beads reviewed up to [0-9a-v]{7} · [0-9-]{10}T[0-9:]{8}Z$')" "1"
  "$BIN" bd-mark review >/dev/null
  check "two review lines" "$(kinds review)" "2"
else
  skip "review mark"
fi
teardown

echo "no beads → no-op"
setup
"$BIN" bd-mark start
check "exit 0" "$?" "0"
check "no bd.jsonl" "$([ -e "$store/bd.jsonl" ] && echo yes || echo no)" "no"
out=$("$BIN" bd-mark review)
check "review prints nothing" "$out" ""
teardown

echo "bad bd-mark kind fails"
setup
"$BIN" bd-mark sideways >/dev/null 2>&1
check "exit 1" "$?" "1"
teardown

echo "worktree finds the main DB"
setup
if have_beads && setup_beads; then
  git_q add -A
  git_q commit -q -m beads
  git_q worktree add -q "$work/wt" -b wt
  main_head=$(cd .beads/embeddeddolt/* && dolt sql -r csv -q "select hashof('HEAD') as h" | tail -n1)
  (cd "$work/wt" && "$BIN" bd-mark review >/dev/null)
  check "line in the main store" "$(kinds review)" "1"
  check "commit is the main DB's" "$(jq -r .commit "$store/bd.jsonl")" "$main_head"
else
  skip "worktree"
fi
teardown

FX="$ROOT/scripts/fixtures/bead-diff"

echo "renderer matches the fixture"
setup
check "render" "$("$BIN" diff --dolt-json "$FX/dolt-diff.json")" "$(cat "$FX/expected.txt")"
teardown

# One modified issue whose notes go from $1 to $2, as dolt diff -r json.
notes_diff() {
  jq -n --arg a "$1" --arg b "$2" '{tables: [{name: "issues", data_diff: [
    {from_row: {id: "t-x", title: "T", notes: $a}, to_row: {id: "t-x", title: "T", notes: $b}}]}]}' >"$work/n.json"
}

echo "text without a trailing newline"
setup
notes_diff $'a\nb' $'a\nb\nc'
check "only the new line" "$("$BIN" diff --dolt-json "$work/n.json")" "$(printf '%s\n' '@@ t-x · T · modified @@' ' notes:' '   a' '   b' '+  c')"
teardown

echo "empty diff renders nothing"
setup
echo '{"tables": [{"name": "events", "data_diff": [{"from_row": {}, "to_row": {"id": "e"}}]}]}' >"$work/e.json"
check "nothing" "$("$BIN" diff --dolt-json "$work/e.json")" ""
teardown

row() { "$BIN" --format tsv --no-fetch | awk -F'\t' -v n="$1" '$1 == n { print $2 "/" $3 }'; }
hshort() { jq -r "$1" "$store/bd.jsonl" | tail -n1 | cut -c1-7; }

echo "row: no beads → skip"
setup
check "skip" "$(row unreviewed-bead-changes)" "skip/no beads"
"$BIN" diff >"$work/d.txt"
check "diff exit 0" "$?" "0"
check "no Beads section" "$(grep -c '^## Beads' "$work/d.txt")" "0"
teardown

echo "row: no mark → unknown"
setup
if have_beads && setup_beads; then
  check "unknown" "$(row unreviewed-bead-changes)" "unknown/no bead mark"
else
  skip "no mark"
fi
teardown

echo "row: pass after review, finding after a bd update or a dep"
setup
if have_beads && setup_beads; then
  "$BIN" bd-mark review >/dev/null
  h=$(hshort .commit)
  check "pass" "$(row unreviewed-bead-changes)" "pass/no bead changes since $h"
  bd --sandbox update "$A" --notes x -q
  check "update" "$(row unreviewed-bead-changes)" "finding/1 bead(s) changed since $h: $A"
  "$BIN" bd-mark review >/dev/null
  h=$(hshort .commit)
  bd --sandbox dep add "$A" "$B" -q
  check "dep" "$(row unreviewed-bead-changes)" "finding/1 bead(s) changed since $h: $A"
  "$BIN" diff >"$work/d.txt"
  check "diff heading" "$(grep -c "^## Beads (since your last review $h · " "$work/d.txt")" "1"
  check "diff dep line" "$(grep -cxF "+dep: blocks $B" "$work/d.txt")" "1"
else
  skip "row pass/finding"
fi
teardown

echo "row: a mark dolt no longer knows → stale"
setup
if have_beads && setup_beads; then
  mkdir -p "$store"
  echo '{"kind":"review","commit":"00000000000000000000000000000000","at":"2000-01-01T00:00:00Z"}' >"$store/bd.jsonl"
  check "stale" "$(row unreviewed-bead-changes | cut -d: -f1)" "stale/mark 0000000 not in beads history"
else
  skip "stale mark"
fi
teardown

echo "diff: code part inline, then as a stat"
setup
seq 1 5 >small.txt && git_q add -A && git_q commit -q -m small
first=$(git rev-parse HEAD)
"$BIN" diff --from "$first" >"$work/d.txt"
check "code heading" "$(grep -c "^## Code ($(echo "$first" | cut -c1-7)^..$(echo "$first" | cut -c1-7))$" "$work/d.txt")" "1"
check "inline diff block" "$(grep -cx '```diff' "$work/d.txt")" "1"
seq 1 200 >big.txt && git_q add -A && git_q commit -q -m big
"$BIN" diff --from "$first" >"$work/d.txt"
check "too long" "$(grep -c '^Too long to show inline (' "$work/d.txt")" "1"
check "stat block" "$(grep -cx '```text' "$work/d.txt")" "1"
teardown

echo "diff: other sessions warn"
setup
if have_beads && setup_beads; then
  "$BIN" bd-mark review >/dev/null
  enc=$(dirname "$(git rev-parse --path-format=absolute --git-common-dir)" | sed 's/[\/.]/-/g')
  mkdir -p "$CLAUDE_CONFIG_DIR/projects/$enc"
  sleep 1
  touch "$CLAUDE_CONFIG_DIR/projects/$enc/s1.jsonl"
  check "own session: no warning" "$("$BIN" diff | grep -c '^⚠️ Other sessions')" "0"
  touch "$CLAUDE_CONFIG_DIR/projects/$enc/s2.jsonl"
  check "warning" "$("$BIN" diff | grep -c '^⚠️ Other sessions also touched this repo since .* (1) — some bead changes may be theirs\.$')" "1"
else
  skip "other sessions"
fi
teardown

HOOK="$ROOT/claude-code/hooks/bead-session-mark.sh"

echo "hook writes the start mark"
setup
if have_beads && setup_beads; then
  out=$(jq -nc --arg cwd "$work/repo" '{session_id: "s9", cwd: $cwd}' |
    (cd / && CLAUDE_PLUGIN_ROOT="$ROOT/claude-code" bash "$HOOK"))
  check "silent" "$out" ""
  check "start line" "$(jq -rs 'map(select(.kind == "start")) | length' "$work/repo/.git/kix/checks/s9/bd.jsonl" 2>/dev/null)" "1"
else
  skip "hook start mark"
fi
teardown

echo "hook is silent and exits 0 on bad input"
setup
out=$(echo 'not json' | CLAUDE_PLUGIN_ROOT="$ROOT/claude-code" bash "$HOOK" 2>&1)
check "garbage: exit 0" "$?" "0"
check "garbage: silent" "$out" ""
out=$(jq -nc '{session_id: "s9", cwd: "/"}' | CLAUDE_PLUGIN_ROOT="$ROOT/claude-code" bash "$HOOK" 2>&1)
check "outside git: exit 0" "$?" "0"
check "outside git: silent" "$out" ""
teardown

if [ "$failures" -gt 0 ]; then
  echo "$failures failure(s)"
  exit 1
fi
echo "all passed"
