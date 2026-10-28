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
  bd --sandbox dep add "$B" "$A" -q
  check "dep" "$(row unreviewed-bead-changes)" "finding/1 bead(s) changed since $h: $B"
  "$BIN" diff >"$work/d.txt"
  check "diff heading" "$(grep -c "^## Beads (since your last review $h · " "$work/d.txt")" "1"
  check "diff dep line" "$(grep -cxF "+dep: blocks $A" "$work/d.txt")" "1"
else
  skip "row pass/finding"
fi
teardown

echo "row: one dolt call, labels and comments counted"
setup
if have_beads && setup_beads; then
  "$BIN" bd-mark review >/dev/null
  h=$(hshort .commit)
  bd --sandbox label add "$A" foo -q
  bd --sandbox comments add "$B" "hi" -q >/dev/null
  mkdir -p "$work/wrap"
  printf '#!/bin/sh\necho x >>"%s/dolt-calls"\nexec "%s" "$@"\n' "$work" "$(command -v dolt)" >"$work/wrap/dolt"
  chmod +x "$work/wrap/dolt"
  got=$(PATH="$work/wrap:$PATH" row unreviewed-bead-changes)
  ids=$(printf '%s\n' "$A" "$B" | sort | paste -sd, - | sed 's/,/, /g')
  check "label and comment" "$got" "finding/2 bead(s) changed since $h: $ids"
  check "one dolt call" "$(wc -l <"$work/dolt-calls" | tr -d ' ')" "1"
else
  skip "row dolt calls"
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
  enc=$(dirname "$(git rev-parse --path-format=absolute --git-common-dir)" | sed 's/[^A-Za-z0-9]/-/g')
  mkdir -p "$CLAUDE_CONFIG_DIR/projects/$enc"
  sleep 1
  touch "$CLAUDE_CONFIG_DIR/projects/$enc/s1.jsonl"
  check "own session: no warning" "$("$BIN" diff | grep -c '^⚠️ Other sessions')" "0"
  # With its own transcript the diff shows only this session's beads; the
  # warning is for the unscoped diff, when there is none.
  rm -f "$CLAUDE_CONFIG_DIR/projects/$enc/s1.jsonl"
  touch "$CLAUDE_CONFIG_DIR/projects/$enc/s2.jsonl"
  check "warning" "$("$BIN" diff | grep -c '^⚠️ Other sessions also touched this repo since .* (1) — some bead changes may be theirs\.$')" "1"
else
  skip "other sessions"
fi
teardown

echo "row: beads but no readable DB → skip that says so, not no beads"
setup
mkdir -p .beads "$work/stubs"
printf '#!/bin/sh\nexit 0\n' >"$work/stubs/bd" && chmod +x "$work/stubs/bd"
for t in bash env jq git awk sed tr cut paste wc grep sort date dirname basename find mktemp touch cat head tail diff; do
  p=$(command -v "$t") && ln -sf "$p" "$work/stubs/$t"
done
check "skip detail" "$(PATH="$work/stubs" row unreviewed-bead-changes)" "skip/beads DB not readable (no dolt CLI, or not embedded mode)"
teardown

# One modified issue, its from/to rows given as JSON objects.
issue_diff() {
  jq -n --argjson a "$1" --argjson b "$2" '{tables: [{name: "issues", data_diff: [{from_row: $a, to_row: $b}]}]}' >"$work/i.json"
}

echo "fences outlast the content's own"
setup
issue_diff '{"id":"t-x","title":"T","notes":"```\nmake test\n```"}' '{"id":"t-x","title":"T","notes":"```\nmake test\n```\nmore"}'
if have_beads && setup_beads; then
  "$BIN" bd-mark review >/dev/null
  bd --sandbox update "$A" --notes $'```\nmake test\n```' -q
  "$BIN" diff >"$work/d.txt"
  check "bead fence is longer" "$(grep -cx '````diff' "$work/d.txt")" "1"
else
  skip "bead fence"
fi
teardown

echo "code fence outlasts a diffed Markdown fence"
setup
printf '```\ncode\n```\n' >fenced.md && git_q add -A && git_q commit -q -m fenced
"$BIN" diff --from HEAD >"$work/d.txt"
check "code fence is longer" "$(grep -cx '````diff' "$work/d.txt")" "1"
teardown

echo "long text stored out of row still renders as text"
setup
if have_beads && setup_beads; then
  long=$(seq -f 'long line %g of a description dolt keeps outside the row' 1 400)
  "$BIN" bd-mark review >/dev/null
  bd --sandbox update "$A" --description "$long" -q
  C=$(bd --sandbox create --title C --type task --description "$long" --silent)
  "$BIN" diff >"$work/d.txt"
  check "no raw blob" "$(grep -c '"Buf"' "$work/d.txt")" "0"
  check "modified text line" "$(grep -cxF '+  long line 400 of a description dolt keeps outside the row' "$work/d.txt")" "2"
  check "created block" "$(grep -cxF "@@ $C · C · created @@" "$work/d.txt")" "1"
else
  skip "long text"
fi
teardown

echo "comments in full"
setup
jq -n '{tables: [{name: "comments", data_diff: [
  {from_row: {}, to_row: {issue_id: "t-x", author: "k", text: "one\ntwo"}},
  {from_row: {issue_id: "t-x", author: "k", text: "same\nold"}, to_row: {issue_id: "t-x", author: "k", text: "same\nnew"}},
  {from_row: {}, to_row: {issue_id: "t-x", text: "solo"}}]}]}' >"$work/c.json"
check "full comments" "$("$BIN" diff --dolt-json "$work/c.json" | tail -n +2)" "$(printf '%s\n' '+comment (k):' '+  one' '+  two' '-comment (k):' '-  same' '-  old' '+comment (k):' '+  same' '+  new' '+comment (?): solo')"
teardown

echo "other changed fields are named"
setup
issue_diff '{"id":"t-x","title":"T","external_ref":"","due_at":null,"updated_at":"1","content_hash":"a"}' '{"id":"t-x","title":"T","external_ref":"gh-1","due_at":"2026-11-01","updated_at":"2","content_hash":"b"}'
check "other fields" "$("$BIN" diff --dolt-json "$work/i.json")" "$(printf '%s\n' '@@ t-x · T · modified @@' ' other fields changed: due_at, external_ref')"
teardown

echo "other sessions: worktree outside .claude, path with _"
setup
if have_beads && setup_beads; then
  git_q add -A && git_q commit -q -m beads
  git_q worktree add -q "$work/wt_x" -b wtx
  "$BIN" bd-mark review >/dev/null
  enc=$(cd "$work/wt_x" && pwd -P | sed 's/[^A-Za-z0-9]/-/g')
  mkdir -p "$CLAUDE_CONFIG_DIR/projects/$enc"
  sleep 1
  touch "$CLAUDE_CONFIG_DIR/projects/$enc/s3.jsonl"
  check "warning" "$("$BIN" diff | grep -c '^⚠️ Other sessions also touched this repo since .* (1)')" "1"
else
  skip "worktree sessions"
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

echo "diff --html: bead diff with changed words marked"
setup
"$BIN" diff --dolt-json "$FX/dolt-diff.json" --html "$work/d.html" >"$work/d.txt"
check "text unchanged" "$(cat "$work/d.txt")" "$(cat "$FX/expected.txt")"
check "a whole page" "$(head -n1 "$work/d.html")" "<!doctype html>"
check "hunk header" "$(grep -c '<div class="l h">@@ t-qlg · Modified one · modified @@</div>' "$work/d.html")" "1"
check "old word" "$(grep -c '<div class="l d">-status: <span class=w>open</span></div>' "$work/d.html")" "1"
check "new word" "$(grep -c '<div class="l a">+status: <span class=w>in_progress</span></div>' "$work/d.html")" "1"
check "text field words" "$(grep -c '<div class="l a">+  line <span class=w>2 changed</span></div>' "$work/d.html")" "1"
check "unpaired add, whole line" "$(grep -c '<div class="l a">+  line four</div>' "$work/d.html")" "1"
check "context" "$(grep -c '<div class="l c">   line one</div>' "$work/d.html")" "1"
teardown

echo "diff --html: escapes HTML"
setup
notes_diff 'a <b>&' 'a <i>&'
"$BIN" diff --dolt-json "$work/n.json" --html "$work/d.html" >/dev/null
check "escaped" "$(grep -c '<div class="l d">-  a <span class=w>&lt;b&gt;&amp;</span></div>' "$work/d.html")" "1"
check "no raw tag" "$(grep -c '<b>' "$work/d.html")" "0"
teardown

echo "diff --html: code in full, words marked"
setup
echo "hello world" >w.txt && git_q add -A && git_q commit -q -m w
echo "hello there" >w.txt && git_q add -A && git_q commit -q -m there
first=$(git rev-parse HEAD)
seq 1 200 >big.txt && git_q add -A && git_q commit -q -m big
"$BIN" diff --from "$first" --html "$work/d.html" >"$work/d.txt"
check "code words" "$(grep -c '<div class="l a">+hello <span class=w>there</span></div>' "$work/d.html")" "1"
check "text still a stat" "$(grep -c '^Too long to show inline (' "$work/d.txt")" "1"
check "html not cut" "$(grep -c 'Too long' "$work/d.html")" "0"
check "all lines" "$(grep -c '<div class="l a">+200</div>' "$work/d.html")" "1"
check "file header is meta" "$(grep -c '<div class="l m">+++ b/big.txt</div>' "$work/d.html")" "1"
check "section heading" "$(grep -c '<h2>Code (' "$work/d.html")" "1"
teardown

echo "diff --html: a last line without a newline still gets word marks"
setup
printf 'hello world' >n.txt && git_q add -A && git_q commit -q -m n
printf 'hello there' >n.txt && git_q add -A && git_q commit -q -m n2
"$BIN" diff --from HEAD --html "$work/d.html" >/dev/null
check "old word" "$(grep -c '<div class="l d">-hello <span class=w>world</span></div>' "$work/d.html")" "1"
check "new word" "$(grep -c '<div class="l a">+hello <span class=w>there</span></div>' "$work/d.html")" "1"
teardown

prow() { awk -F'\t' -v n="$1" '$1 == n { print $2 "/" $3 }' "$work/rows.tsv"; }

echo "status call --diff-html: no page when nothing is unreviewed"
setup
"$BIN" --no-fetch --format tsv --diff-html "$work/p.html" >"$work/rows.tsv"
check "row" "$(prow diff-page)" "fact/-"
check "no file" "$([ -e "$work/p.html" ] && echo yes || echo no)" "no"
check "no row without the flag" "$("$BIN" --no-fetch --format tsv | grep -c '^diff-page')" "0"
teardown

echo "status call --diff-html: a page for the commits under review"
setup
echo "hello world" >w.txt && git_q add -A && git_q commit -q -m w
first=$(git rev-parse HEAD)
"$BIN" --no-fetch --format tsv --diff-html "$work/p.html" --from "$first" >"$work/rows.tsv"
check "row" "$(prow diff-page)" "fact/$work/p.html"
check "code section" "$(grep -c '<h2>Code (' "$work/p.html")" "1"
check "added line" "$(grep -c '<div class="l a">+hello world</div>' "$work/p.html")" "1"
teardown

echo "status call --diff-html: a page for unreviewed bead changes"
setup
if have_beads && setup_beads; then
  "$BIN" bd-mark review >/dev/null
  bd --sandbox update "$A" --notes "changed" >/dev/null 2>&1
  "$BIN" --no-fetch --format tsv --diff-html "$work/p.html" >"$work/rows.tsv"
  check "row" "$(prow diff-page)" "fact/$work/p.html"
  check "bead hunk" "$(grep -c "<div class=\"l h\">@@ $A · A · modified @@</div>" "$work/p.html")" "1"
  "$BIN" bd-mark review >/dev/null
  rm -f "$work/p.html"
  "$BIN" --no-fetch --format tsv --diff-html "$work/p.html" >"$work/rows.tsv"
  check "reviewed: no page" "$(prow diff-page)/$([ -e "$work/p.html" ] && echo yes || echo no)" "fact/-/no"
else
  skip "status call bead page"
fi
teardown

# This session's transcript ($CLAUDE_CONFIG_DIR/projects/p/s1.jsonl) with one
# Bash tool call running command $1, and its result $2.
transcript() {
  mkdir -p "$CLAUDE_CONFIG_DIR/projects/p"
  jq -nc --arg c "$1" '{type: "assistant", message: {content: [{type: "tool_use", id: "tu1", name: "Bash", input: {command: $c}}]}}' \
    >>"$CLAUDE_CONFIG_DIR/projects/p/s1.jsonl"
  jq -nc --arg r "$2" '{type: "user", message: {content: [{type: "tool_result", tool_use_id: "tu1", content: $r}]}}' \
    >>"$CLAUDE_CONFIG_DIR/projects/p/s1.jsonl"
}

echo "row: only this session's beads and their deps"
setup
if have_beads && setup_beads; then
  C=$(bd --sandbox create --title C --type task --silent 2>/dev/null)
  "$BIN" bd-mark review >/dev/null
  h=$(hshort .commit)
  transcript "bd update $A --notes mine" ""
  bd --sandbox update "$A" --notes mine -q
  bd --sandbox update "$B" --notes theirs -q
  check "mine only" "$(row unreviewed-bead-changes)" "finding/1 bead(s) changed since $h: $A (this session's beads and their deps; 1 other not shown)"
  "$BIN" diff >"$work/d.txt"
  check "diff: mine" "$(grep -c "^@@ $A " "$work/d.txt")" "1"
  check "diff: not theirs" "$(grep -c "^@@ $B " "$work/d.txt")" "0"
  check "diff: hidden line" "$(grep -c '^1 bead change(s) by other sessions not shown\.$' "$work/d.txt")" "1"
  bd --sandbox dep add "$C" "$A" -q
  check "a dep of mine counts" "$(row unreviewed-bead-changes | sed 's/^[^:]*: //; s/ (.*//')" "$(printf '%s\n' "$A" "$C" | sort | paste -sd, - | sed 's/,/, /g')"
else
  skip "session scope"
fi
teardown

echo "row: a bead this session created counts, --silent or not"
setup
if have_beads && setup_beads; then
  "$BIN" bd-mark review >/dev/null
  D=$(bd --sandbox create --title D --type task --silent 2>/dev/null)
  transcript "bd create --title D --type task --silent" "$D"
  E=$(bd --sandbox create --title E --type task --silent 2>/dev/null)
  got=$(row unreviewed-bead-changes)
  check "created: listed" "$(printf '%s' "$got" | grep -c ": $D (")" "1"
  check "other's create: not" "$(printf '%s' "$got" | grep -c "$E")" "0"
else
  skip "session creates"
fi
teardown

echo "row: a session that wrote no bead shows none"
setup
if have_beads && setup_beads; then
  "$BIN" bd-mark review >/dev/null
  h=$(hshort .commit)
  transcript "bd show $A; grep 'bd update|x' f" ""
  bd --sandbox update "$A" --notes theirs -q
  check "pass" "$(row unreviewed-bead-changes)" "pass/no bead changes from this session since $h (1 other not shown)"
else
  skip "session none"
fi
teardown

GATE="$ROOT/claude-code/hooks/diff-link-gate.sh"
# Run the question gate as Claude Code would, for session s1 in the current
# repo, with transcript $1.
gate() {
  jq -nc --arg c "$PWD" --arg t "$1" '{session_id: "s1", cwd: $c, transcript_path: $t, tool_name: "AskUserQuestion"}' |
    bash "$GATE" 2>"$work/gate.err"
}

echo "status call --diff-html: records the unshown page, clears it when none"
setup
echo "hello" >w.txt && git_q add -A && git_q commit -q -m w
"$BIN" --no-fetch --format tsv --diff-html "$work/p.html" --from HEAD >/dev/null
check "pending" "$(cat "$store/diff-page" 2>/dev/null)" "$work/p.html"
"$BIN" --no-fetch --format tsv --diff-html "$work/p.html" >/dev/null
check "cleared" "$([ -e "$store/diff-page" ] && echo yes || echo no)" "no"
teardown

echo "gate: a question waits until the page link is printed"
setup
gate "$work/none.jsonl"
check "no page: allowed" "$?/$(cat "$work/gate.err")" "0/"
mkdir -p "$store" && echo "$work/p.html" >"$store/diff-page"
jq -nc '{type: "assistant", message: {content: [{type: "text", text: "❓ 12/12 Verdict — rerun?"}]}}' >"$work/t.jsonl"
gate "$work/t.jsonl"
check "no link: blocked" "$?" "2"
check "says what to print" "$(grep -cF "[Open the diff page](file://$work/p.html)" "$work/gate.err")" "1"
jq -nc --arg l "⚠️ 12/12 Verdict — changed
[Open the diff page](file://$work/p.html)" '{type: "assistant", message: {content: [{type: "text", text: $l}]}}' >>"$work/t.jsonl"
gate "$work/t.jsonl"
check "link printed: allowed" "$?" "0"
check "page cleared" "$([ -e "$store/diff-page" ] && echo yes || echo no)" "no"
echo "garbage" | bash "$GATE" >/dev/null 2>&1
check "bad input: allowed" "$?" "0"
teardown

if [ "$failures" -gt 0 ]; then
  echo "$failures failure(s)"
  exit 1
fi
echo "all passed"
