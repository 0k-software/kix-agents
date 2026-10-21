#!/usr/bin/env bash
# Tests for `preflight-checks` (kxa-cx0).
#
# Every case clones a throwaway bare origin under a temp dir, so nothing here
# reads or writes a real repo.
set -uo pipefail

# Run from the pre-commit hook, git exports GIT_DIR, GIT_INDEX_FILE and friends
# for the real repo, and every git call below would hit it instead of the
# throwaway repos (kxa-6df: it re-inited kix-agents as bare). Drop them.
unset GIT_DIR GIT_WORK_TREE GIT_INDEX_FILE GIT_OBJECT_DIRECTORY GIT_COMMON_DIR \
  GIT_PREFIX GIT_ALTERNATE_OBJECT_DIRECTORIES

BIN=${PREFLIGHT_CHECKS_BIN:-"$(cd "$(dirname "$0")/.." && pwd)/claude-code/bin/preflight-checks"}
failures=0

git_q() { git -c user.name=t -c user.email=t@t "$@" >/dev/null 2>&1; }

# $work/origin.git (bare, branch main, one commit) cloned to $work/repo; cds
# into the clone.
setup() {
  work=$(mktemp -d)
  git_q init -q --bare -b main "$work/origin.git"
  git_q clone -q "$work/origin.git" "$work/seed"
  git_q -C "$work/seed" commit -q --allow-empty -m init
  git_q -C "$work/seed" push -q origin HEAD:main
  git_q clone -q "$work/origin.git" "$work/repo"
  cd "$work/repo" || exit 1
}

teardown() {
  cd / || exit 1
  rm -rf "$work"
}

# A commit on origin/main the clone has not got yet.
advance_origin() {
  git_q -C "$work/seed" commit -q --allow-empty -m "upstream $1"
  git_q -C "$work/seed" push -q origin HEAD:main
}

commit() {
  git_q add -A
  git_q commit -q --allow-empty -m "$1"
}

run() { out=$("$BIN" --no-fetch --session s1); }

# The status and detail columns of one line of $out.
field() { printf '%s\n' "$out" | awk -F'\t' -v n="$1" -v c="$2" '$1 == n { print $c }'; }
status() { field "$1" 2; }
detail() { field "$1" 3; }

check() {
  local what=$1 got=$2 want=$3
  if [ "$got" = "$want" ]; then
    echo "  ok: $what"
  else
    echo "  FAIL: $what — got [$got], want [$want]"
    failures=$((failures + 1))
  fi
}

echo "fresh clone: every checkpoint passes"
setup
run
check "exit status" "$?" "0"
check "default" "$(detail default)" "origin/main"
check "from" "$(detail from)" "-"
check "shortstat" "$(detail shortstat)" "no changes"
check "markdown" "$(detail markdown)" ""
check "fetch" "$(detail fetch)" "skipped"
for c in dirty-tree unlanded rebase notes-guard before-shipping; do
  check "$c" "$(status "$c")" "pass"
done
check "marker" "$(status marker)" "stale"
check "line count" "$(printf '%s\n' "$out" | wc -l | tr -d ' ')" "11"
teardown

echo "dirty tree"
setup
echo x >a.txt
run
check "dirty-tree" "$(status dirty-tree)" "finding"
check "dirty-tree detail" "$(detail dirty-tree)" "1 uncommitted path(s)"
check "marker" "$(detail marker)" "dirty tree"
teardown

echo "unlanded commits, still on origin/main"
setup
echo x >a.txt && commit one
echo y >b.txt && commit two
run
check "unlanded" "$(status unlanded)" "finding"
check "unlanded detail" "$(detail unlanded)" "2 commit(s) not on origin/main"
check "rebase" "$(status rebase)" "pass"
check "shortstat" "$(detail shortstat)" "2 files changed, 2 insertions(+)"
teardown

echo "origin/main moved: rebase needed"
setup
echo x >a.txt && commit one
advance_origin 1
advance_origin 2
git_q fetch -q origin
run
check "rebase" "$(status rebase)" "finding"
check "rebase detail" "$(detail rebase)" "origin/main has 2 commit(s) not in HEAD"
check "shortstat ignores upstream" "$(detail shortstat)" "1 file changed, 1 insertion(+)"
teardown

echo "notes.rewriteRef guard"
setup
git config notes.rewriteRef refs/notes/commits
run
check "unrelated ref" "$(status notes-guard)" "pass"
git config --add notes.rewriteRef 'refs/notes/*'
run
check "glob" "$(status notes-guard)" "finding"
check "glob detail" "$(detail notes-guard)" "notes.rewriteRef: local refs/notes/*"
git config --unset-all notes.rewriteRef
git config notes.rewriteRef refs/notes/checks
run
check "exact" "$(detail notes-guard)" "notes.rewriteRef: local refs/notes/checks"
teardown

echo "check marks"
setup
echo x >a.txt && commit one
marked=$(git rev-parse HEAD)
git_q notes --ref=checks add -m "checked s1" HEAD
run
check "this session's mark" "$(status marker)" "pass"
check "from is HEAD" "$(detail from)" "$marked"
check "shortstat from the mark" "$(detail shortstat)" "no changes"
echo y >b.txt && commit two
run
check "new commit is unchecked" "$(status marker)" "stale"
check "from stays on the marked commit" "$(detail from)" "$marked"
check "shortstat from the mark" "$(detail shortstat)" "1 file changed, 1 insertion(+)"
git_q notes --ref=checks add -m "checked s2" HEAD
run
check "another session's mark" "$(status marker)" "stale"
git_q notes --ref=checks append -m "checked s1" HEAD
run
check "stacked union lines" "$(status marker)" "pass"
git_q notes --ref=checks add -f -m "checked s10" HEAD
run
check "no prefix match" "$(status marker)" "stale"
out=$("$BIN" --no-fetch --session "")
check "no session id" "$(detail marker)" "no session id"
check "no session: from" "$(detail from)" "-"
teardown

echo "before-shipping items in touched Markdown"
setup
printf '# Plan\n\n- [x] done\n- [ ] later\n  - [ ] nested\n' >plan.md
commit plan
printf -- '- [ ] draft\n' >draft.md
run
check "markdown" "$(detail markdown)" "draft.md, plan.md"
check "before-shipping" "$(status before-shipping)" "finding"
check "items" "$(detail before-shipping)" "draft.md:1, plan.md:4, plan.md:5"
teardown

echo "untouched Markdown is not listed"
setup
printf -- '- [ ] old\n' >old.md
commit old
git_q push -q origin HEAD:main
git_q fetch -q origin
echo x >a.txt && commit code
run
check "markdown" "$(detail markdown)" ""
check "before-shipping" "$(status before-shipping)" "pass"
teardown

echo "no origin"
setup
git_q remote remove origin
run
check "exit status" "$?" "0"
check "default" "$(detail default)" "-"
check "unlanded" "$(status unlanded)" "skip"
check "rebase" "$(status rebase)" "skip"
check "fetch" "$("$BIN" --session s1 | awk -F'\t' '$1 == "fetch" { print $3 }')" "skipped"
teardown

echo "cached fetch"
setup
advance_origin 1
out=$(KIX_FETCH_TTL=0 "$BIN" --session s1)
check "stale cache fetches" "$(detail fetch)" "fetched"
check "fetched commit seen" "$(status rebase)" "finding"
out=$(KIX_FETCH_TTL=60 "$BIN" --session s1)
check "fresh cache skips" "$(detail fetch)" "fresh"
teardown

echo "outside a git repo"
work=$(mktemp -d)
cd "$work" || exit 1
"$BIN" --no-fetch >/dev/null 2>&1
check "exit status" "$?" "1"
teardown

if [ "$failures" -gt 0 ]; then
  echo "$failures failure(s)"
  exit 1
fi
echo "all passed"
