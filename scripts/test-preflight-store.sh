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

git_q() { git -c user.name=t -c user.email=t@t "$@" >/dev/null 2>&1; }

setup() {
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
