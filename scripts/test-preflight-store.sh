#!/usr/bin/env bash
# Tests for the session store behind `preflight-checks` (kxa-102): the start,
# mark, resolve and findings subcommands and the findings-leftovers row.
#
# Every case clones a throwaway bare origin under a temp dir, so nothing here
# reads or writes a real repo, and CLAUDE_CONFIG_DIR points into that temp dir
# so a real transcript is never read.
set -uo pipefail

# Run from the pre-commit hook, git exports GIT_DIR, GIT_INDEX_FILE and friends
# for the real repo (kxa-6df). Drop them.
unset GIT_DIR GIT_WORK_TREE GIT_INDEX_FILE GIT_OBJECT_DIRECTORY GIT_COMMON_DIR \
  GIT_PREFIX GIT_ALTERNATE_OBJECT_DIRECTORIES

BIN=${PREFLIGHT_CHECKS_BIN:-"$(cd "$(dirname "$0")/.." && pwd)/claude-code/bin/preflight-checks"}
failures=0
ORIG_PATH=$PATH

git_q() { git -c user.name=t -c user.email=t@t "$@" >/dev/null 2>&1; }

setup() {
  PATH=$ORIG_PATH
  work=$(mktemp -d)
  export CLAUDE_CONFIG_DIR="$work/claude-config"
  export CLAUDE_CODE_SESSION_ID=s1
  git_q init -q --bare -b main "$work/origin.git"
  git_q clone -q "$work/origin.git" "$work/seed"
  git_q -C "$work/seed" commit -q --allow-empty -m init
  git_q -C "$work/seed" push -q origin HEAD:main
  git_q clone -q "$work/origin.git" "$work/repo"
  cd "$work/repo" || exit 1
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

lines() { [ -f "$1" ] && wc -l <"$1" | tr -d ' ' || echo 0; }
flen() { "$BIN" findings "$@" | jq length; }
row() { "$BIN" --format tsv --no-fetch | awk -F'\t' -v n="$1" '$1 == n { print $2 "/" $3 }'; }

echo "start prints the anchor line"
setup
out=$("$BIN" start)
check "anchor line" "$(printf '%s' "$out" | grep -cE '^🛫 preflight check started here · [0-9-]{10}T[0-9:]{8}Z$')" "1"
check "run recorded" "$(tail -n1 "$store/markers.jsonl" | jq -r .run)" "${out##* · }"
teardown

echo "mark assigns ids and records the run"
setup
start=$("$BIN" start)
start=${start##* · }
out=$(echo '[{"category":"x","summary":"a"},{"category":"x","summary":"b"}]' | "$BIN" mark diff-review)
check "first ids" "$out" $'diff-review-1\ndiff-review-2'
out=$(echo '[{"category":"x","summary":"c"}]' | "$BIN" mark diff-review)
check "next id" "$out" "diff-review-3"
check "marker run" "$(tail -n1 "$store/markers.jsonl" | jq -r .run)" "$start"
check "marker findings" "$(tail -n1 "$store/markers.jsonl" | jq -c .findings)" '["diff-review-3"]'
check "findings count" "$(flen diff-review)" "3"
teardown

echo "mark with [] still writes a marker"
setup
"$BIN" start >/dev/null
before=$(lines "$store/markers.jsonl")
echo '[]' | "$BIN" mark diff-review >/dev/null
check "findings" "$(flen)" "0"
check "marker lines" "$(lines "$store/markers.jsonl")" "$((before + 1))"
teardown

echo "mark rejects junk"
setup
"$BIN" start >/dev/null
echo '[{"category":"x","summary":"a"}]' | "$BIN" mark diff-review >/dev/null
m=$(lines "$store/markers.jsonl")
f=$(lines "$store/findings.jsonl")
echo '[]' | "$BIN" mark nope >/dev/null 2>&1
check "unknown check exit" "$?" "1"
echo '{}' | "$BIN" mark diff-review >/dev/null 2>&1
check "non-array exit" "$?" "1"
echo 'not json' | "$BIN" mark diff-review >/dev/null 2>&1
check "garbage exit" "$?" "1"
check "markers unchanged" "$(lines "$store/markers.jsonl")" "$m"
check "findings unchanged" "$(lines "$store/findings.jsonl")" "$f"
teardown

echo "resolve closes a finding, history kept"
setup
echo '[{"category":"x","summary":"a"},{"category":"x","summary":"b"},{"category":"x","summary":"c"}]' | "$BIN" mark diff-review >/dev/null
"$BIN" resolve diff-review-1 fixed
check "fixed exit" "$?" "0"
check "no longer open" "$("$BIN" findings | jq -c '[.[].id]')" '["diff-review-2","diff-review-3"]'
check "history kept" "$(grep -c diff-review-1 "$store/findings.jsonl")" "2"
"$BIN" resolve diff-review-2 deferred kxa-abc
check "deferred exit" "$?" "0"
"$BIN" resolve diff-review-3 discarded not a real problem
check "discarded exit" "$?" "0"
check "reason merged" "$(jq -sc 'group_by(.id) | map(add) | map(select(.id == "diff-review-3")) | .[0].reason' "$store/findings.jsonl")" '"not a real problem"'
check "ref merged" "$(jq -sc 'group_by(.id) | map(add) | map(select(.id == "diff-review-2")) | .[0].ref' "$store/findings.jsonl")" '"kxa-abc"'
n=$(lines "$store/findings.jsonl")
"$BIN" resolve diff-review-9 fixed 2>/dev/null
check "unknown id exit" "$?" "1"
"$BIN" resolve diff-review-1 deferred 2>/dev/null
check "missing ref exit" "$?" "1"
"$BIN" resolve diff-review-1 discarded 2>/dev/null
check "missing reason exit" "$?" "1"
"$BIN" resolve diff-review-1 maybe 2>/dev/null
check "other outcome exit" "$?" "1"
check "nothing written" "$(lines "$store/findings.jsonl")" "$n"
teardown

echo "findings-leftovers row"
setup
check "fresh" "$(row findings-leftovers)" "pass/none open"
echo '[{"category":"x","summary":"a"}]' | "$BIN" mark diff-review >/dev/null
check "open" "$(row findings-leftovers)" "finding/diff-review-1"
echo '[{"category":"x","summary":"b"}]' | "$BIN" mark diff-review >/dev/null
check "two open" "$(row findings-leftovers)" "finding/diff-review-1, diff-review-2"
"$BIN" resolve diff-review-1 fixed
"$BIN" resolve diff-review-2 fixed
check "resolved" "$(row findings-leftovers)" "pass/none open"
teardown

echo "awkward text round-trips"
setup
text=$'line1\nline2 | "q" ação'
jq -nc --arg s "$text" '[{category: "x", summary: $s}]' | "$BIN" mark diff-review >/dev/null
check "one line" "$(lines "$store/findings.jsonl")" "1"
check "byte-identical" "$("$BIN" findings | jq -r '.[0].summary')" "$text"
teardown

echo "branches never mix"
setup
git_q switch -c a
echo '[{"category":"x","summary":"on a"}]' | "$BIN" mark diff-review >/dev/null
git_q switch -c b
check "other branch empty" "$("$BIN" findings)" "[]"
check "other branch row" "$(row findings-leftovers)" "pass/none open"
git_q worktree add ../wt a
check "worktree sees it" "$(cd "$work/wt" && "$BIN" findings | jq -c '[.[].summary]')" '["on a"]'
git_q switch --detach
echo '[{"category":"x","summary":"detached"}]' | "$BIN" mark diff-review >/dev/null
check "detached mark" "$?" "0"
check "detached sees only HEAD" "$("$BIN" findings | jq -c '[.[].summary]')" '["detached"]'
check "detached branch field" "$(tail -n1 "$store/findings.jsonl" | jq -r .branch)" "HEAD"
teardown

echo "no session id"
setup
echo '[]' | env -u CLAUDE_CODE_SESSION_ID "$BIN" mark diff-review >/dev/null
check "unknown store" "$(lines "$work/repo/.git/kix/checks/unknown/markers.jsonl")" "1"
teardown

# Transcript fixtures in the shape Claude Code writes: one JSON object per line
# at $work/cfg/projects/p/s1.jsonl. Timestamps carry milliseconds.
tx=""
tx_init() {
  export CLAUDE_CONFIG_DIR="$work/cfg"
  mkdir -p "$work/cfg/projects/p"
  tx="$work/cfg/projects/p/s1.jsonl"
  : >"$tx"
}
tx_turn() {
  jq -nc --arg u "$1" --arg t "$2" --arg x "$3" \
    '{type: "user", uuid: $u, timestamp: $t, message: {role: "user", content: $x}}' >>"$tx"
}
tx_meta() {
  jq -nc --arg u "$1" --arg t "$2" \
    '{type: "user", isMeta: true, uuid: $u, timestamp: $t, message: {role: "user", content: [{type: "text", text: "skill text"}]}}' >>"$tx"
}
tx_ask() {
  jq -nc --arg u "$1" --arg t "$2" --arg i "$3" \
    '{type: "assistant", uuid: $u, timestamp: $t, message: {role: "assistant", content: [{type: "tool_use", id: $i, name: "AskUserQuestion", input: {}}]}}' >>"$tx"
}
tx_bash() {
  jq -nc --arg u "$1" --arg t "$2" --arg i "$3" \
    '{type: "assistant", uuid: $u, timestamp: $t, message: {role: "assistant", content: [{type: "tool_use", id: $i, name: "Bash", input: {}}]}}' >>"$tx"
}
tx_result() {
  jq -nc --arg u "$1" --arg t "$2" --arg i "$3" \
    '{type: "user", uuid: $u, timestamp: $t, message: {role: "user", content: [{type: "tool_result", tool_use_id: $i, content: "ok"}]}}' >>"$tx"
}
T1=2026-10-22T11:00:00.100Z
T2=2026-10-22T11:05:00.200Z
T3=2026-10-22T11:10:00.300Z
T4=2026-10-22T11:15:00.400Z

# A bd stub first on PATH: `list` answers with $work/bd-list.json, `show` with
# $work/bd-show.json (missing file: not found). Never the real bd.
stub_bd() {
  mkdir -p "$work/stubs"
  cat >"$work/stubs/bd" <<'SH'
#!/bin/sh
d=$(dirname "$0")/..
case $1 in
list) cat "$d/bd-list.json" ;;
show) [ -f "$d/bd-show.json" ] && cat "$d/bd-show.json" || exit 1 ;;
esac
SH
  chmod +x "$work/stubs/bd"
  echo '[]' >"$work/bd-list.json"
  export PATH="$work/stubs:$PATH"
  mkdir -p .beads
}
short() { git rev-parse HEAD | cut -c1-7; }
fact() { "$BIN" --format tsv --no-fetch | awk -F'\t' -v n="$1" '$1 == n { print $3 }'; }
commit() {
  git_q add -A
  git_q commit -q --allow-empty -m "$1"
}

echo "diff-review: never, then fresh, then stale on a commit"
setup
check "never" "$(row diff-review)" "skip/no changes"
echo a >a.txt && commit one
check "never with commits" "$(row diff-review)" "never/no marker"
echo '[]' | "$BIN" mark diff-review >/dev/null
marked=$(git rev-parse HEAD)
check "fresh" "$(row diff-review | cut -d/ -f1)" "fresh"
check "fresh detail" "$(row diff-review | cut -d/ -f2- | grep -cE '^no changes since [0-9-]{10}T[0-9:]{8}Z$')" "1"
check "from" "$(fact from)" "$marked"
echo b >b.txt && commit two
check "stale" "$(row diff-review)" "stale/new commits since $(echo "$marked" | cut -c1-7)"
check "from stays" "$(fact from)" "$marked"
check "shortstat from marker" "$(fact shortstat)" "1 file changed, 1 insertion(+)"
teardown

echo "dirty tree stales"
setup
echo a >a.txt && commit one
echo '[]' | "$BIN" mark diff-review >/dev/null
echo x >y
check "dirty" "$(row diff-review)" "stale/dirty tree"
rm y
check "clean again" "$(row diff-review | cut -d/ -f1)" "fresh"
echo x >y
echo '[]' | "$BIN" mark diff-review >/dev/null
check "marked dirty" "$(tail -n1 "$store/markers.jsonl" | jq -c '[.clean, .head]')" "[false,\"$(git rev-parse HEAD)\"]"
rm y
check "cleaned after dirty mark" "$(row diff-review)" "stale/dirty tree"
teardown

echo "rebased away"
setup
echo a >a.txt && commit one
echo '[]' | "$BIN" mark diff-review >/dev/null
old=$(short)
git_q commit --amend -m x
check "rebased" "$(row diff-review)" "stale/rebased since $old"
check "from" "$(fact from)" "-"
teardown

echo "fresh wins over skip"
setup
check "skip" "$(row diff-review)" "skip/no changes"
echo '[]' | "$BIN" mark diff-review >/dev/null
check "fresh" "$(row diff-review | cut -d/ -f1)" "fresh"
teardown

echo "bd updates stale related-tracker-items"
setup
stub_bd
tx_init
tx_turn u1 $T1 "hello"
check "never" "$(row related-tracker-items)" "never/no marker"
echo '[]' | "$BIN" mark related-tracker-items >/dev/null
at=$(tail -n1 "$store/markers.jsonl" | jq -r .at)
check "bd recorded" "$(tail -n1 "$store/markers.jsonl" | jq -r .bd)" "$at"
check "fresh" "$(row related-tracker-items | cut -d/ -f1)" "fresh"
echo '[{"id":"x"}]' >"$work/bd-list.json"
check "stale" "$(row related-tracker-items)" "stale/1 bd update(s) since $at"
teardown
setup
check "no tracker" "$(row related-tracker-items)" "skip/no tracker"
mkdir Gates && echo g >Gates/Gates.md
check "kingdone" "$(row related-tracker-items)" "never/no marker"
teardown

echo "bead update stales acceptance-criteria"
setup
stub_bd
echo '[{"id":"kxa-1","updated_at":"T1"}]' >"$work/bd-show.json"
echo '[]' | "$BIN" mark acceptance-criteria --bead kxa-1 >/dev/null
check "bead recorded" "$(tail -n1 "$store/markers.jsonl" | jq -c .bead)" '{"id":"kxa-1","updated":"T1"}'
check "fresh" "$(row acceptance-criteria | cut -d/ -f1)" "fresh"
echo '{"id":"kxa-1","updated_at":"T2"}' >"$work/bd-show.json"
check "stale" "$(row acceptance-criteria)" "stale/kxa-1 updated"
m=$(lines "$store/markers.jsonl")
rm "$work/bd-show.json"
echo '[]' | "$BIN" mark acceptance-criteria --bead nope >/dev/null 2>&1
check "unknown bead exit" "$?" "1"
check "nothing written" "$(lines "$store/markers.jsonl")" "$m"
teardown

echo "open-checkboxes delta"
setup
printf -- '- [ ] x\n' >a.md && commit a
check "never" "$(row open-checkboxes)" "never/no marker — a.md:1"
echo '[]' | "$BIN" mark open-checkboxes >/dev/null
printf -- '- [ ] y\n' >b.md && commit b
check "stale" "$(row open-checkboxes)" "stale/new commits since $(git rev-parse HEAD~1 | cut -c1-7) — b.md:1"
teardown

echo "conversation-leftovers: never, then fresh"
setup
tx_init
tx_turn u1 $T1 "hello"
check "never" "$(row conversation-leftovers)" "never/no marker"
echo '[]' | "$BIN" mark conversation-leftovers >/dev/null
check "turn recorded" "$(tail -n1 "$store/markers.jsonl" | jq -c .turn)" "{\"uuid\":\"u1\",\"ts\":\"$T1\"}"
check "fresh" "$(row conversation-leftovers | cut -d/ -f1)" "fresh"
teardown

echo "conversation: new prompt stales"
setup
tx_init
tx_turn u1 $T1 "hello"
echo '[]' | "$BIN" mark conversation-leftovers >/dev/null
tx_turn u2 $T2 "more"
check "stale" "$(row conversation-leftovers)" "stale/conversation since $T2"
teardown

echo "conversation: own tool output does not"
setup
tx_init
tx_turn u1 $T1 "hello"
echo '[]' | "$BIN" mark conversation-leftovers >/dev/null
tx_bash a1 $T2 b1
tx_result r1 $T3 b1
check "fresh" "$(row conversation-leftovers | cut -d/ -f1)" "fresh"
teardown

echo "conversation: question answers stale"
setup
tx_init
tx_turn u1 $T1 "hello"
echo '[]' | "$BIN" mark conversation-leftovers >/dev/null
tx_ask a1 $T2 q1
check "asked, unanswered" "$(row conversation-leftovers | cut -d/ -f1)" "fresh"
tx_result r1 $T3 q1
check "answered" "$(row conversation-leftovers)" "stale/conversation since $T3"
teardown

echo "conversation: meta lines do not"
setup
tx_init
tx_turn u1 $T1 "hello"
echo '[]' | "$BIN" mark conversation-leftovers >/dev/null
tx_meta m1 $T2
check "fresh" "$(row conversation-leftovers | cut -d/ -f1)" "fresh"
teardown

echo "conversation: uuid gone, timestamp fallback"
setup
tx_init
tx_turn u1 $T1 "hello"
tx_turn u2 $T2 "second"
echo '[]' | "$BIN" mark conversation-leftovers >/dev/null
: >"$tx"
tx_turn u0 $T1 "hello"
check "only earlier" "$(row conversation-leftovers | cut -d/ -f1)" "fresh"
tx_turn u3 $T4 "later"
check "later turn" "$(row conversation-leftovers)" "stale/conversation since $T4"
teardown

echo "conversation: malformed line skipped"
setup
tx_init
tx_turn u1 $T1 "hello"
echo '[]' | "$BIN" mark conversation-leftovers >/dev/null
printf '{"type":"user",\n' >>"$tx"
check "status" "$(row conversation-leftovers | cut -d/ -f1)" "fresh"
"$BIN" --format tsv --no-fetch >/dev/null
check "exit" "$?" "0"
tx_turn u2 $T2 "more"
check "still stales" "$(row conversation-leftovers)" "stale/conversation since $T2"
teardown

echo "conversation: no transcript"
setup
tx_init
tx_turn u1 $T1 "hello"
run=$("$BIN" start)
run=${run##* · }
echo '[]' | "$BIN" mark conversation-leftovers >/dev/null
echo '[]' | "$BIN" mark related-tracker-items >/dev/null
mkdir "$work/empty"
export CLAUDE_CONFIG_DIR="$work/empty"
check "unknown" "$(row conversation-leftovers)" "unknown/since $run"
echo c >c.txt && commit c
check "stale and unknown" "$(row related-tracker-items)" "stale/new commits since $(git rev-parse HEAD~1 | cut -c1-7), conversation unknown since $run"
teardown
setup
export CLAUDE_CONFIG_DIR="$work/empty2"
mkdir "$work/empty2"
run=$("$BIN" start)
run=${run##* · }
echo '[]' | "$BIN" mark conversation-leftovers >/dev/null
check "marked without transcript: no turn" "$(tail -n1 "$store/markers.jsonl" | jq 'has("turn")')" "false"
tx_init
tx_turn u1 $T1 "hello"
check "marker without turn" "$(row conversation-leftovers)" "unknown/since $run"
teardown

echo "stray lines in the store are skipped"
setup
echo '[{"category":"x","summary":"a"}]' | "$BIN" mark diff-review >/dev/null
before=$("$BIN" --format tsv --no-fetch | grep -v '^from')
printf '42\n{"id":\n' | tee -a "$store/findings.jsonl" >>"$store/markers.jsonl"
check "findings" "$("$BIN" findings | jq -c '[.[].id]')" '["diff-review-1"]'
check "default call" "$("$BIN" --format tsv --no-fetch | grep -v '^from')" "$before"
teardown

echo "resolve takes the rest literally"
setup
echo '[{"category":"x","summary":"a"}]' | "$BIN" mark diff-review >/dev/null
"$BIN" resolve diff-review-1 discarded -foo bar
check "exit" "$?" "0"
check "reason" "$(tail -n1 "$store/findings.jsonl" | jq -r .reason)" "-foo bar"
teardown

echo "jq missing"
setup
bin="$work/bin"
mkdir "$bin"
for t in git bash env cat sed awk grep sort tr date wc paste find dirname mkdir tail head basename; do
  p=$(command -v "$t") && ln -s "$p" "$bin/$t"
done
PATH="$bin" "$BIN" findings >/dev/null 2>&1
check "exit" "$?" "1"
err=$(PATH="$bin" "$BIN" findings 2>&1 >/dev/null)
check "message" "$err" "preflight-checks: jq is required"
teardown

if [ "$failures" -gt 0 ]; then
  echo "$failures failure(s)"
  exit 1
fi
echo "all passed"
