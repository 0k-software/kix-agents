#!/usr/bin/env bash
# Tests for `project-code` (dot-mrr).
#
# Every case builds throwaway git repos under a temp dir, so nothing here
# reads or writes a real repo's .claude/settings.json.
set -uo pipefail

PROJECT_CODE_BIN=${PROJECT_CODE_BIN:-"$(cd "$(dirname "$0")/.." && pwd)/claude-code/bin/project-code"}
failures=0

git_q() { git -c user.name=t -c user.email=t@t "$@" >/dev/null 2>&1; }

# A fresh repo at $work/<name> with one commit; cds into it.
setup() {
  work=$(mktemp -d)
  mkdir -p "$work/$1"
  cd "$work/$1" || exit 1
  git_q init -q
  git_q commit -q --allow-empty -m init
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

echo "no settings file: get falls back to the generated code"
setup dotfiles
out=$("$PROJECT_CODE_BIN" get 2>&1)
check "exit status" "$?" "0"
check "output" "$out" "dot"
check "nothing written" "$([ -e .claude ] && echo yes || echo no)" "no"
teardown

echo "get reads an existing code"
setup dotfiles
mkdir -p .claude
printf '{"env":{"PROJECT_CODE":"dot"}}\n' >.claude/settings.json
check "code" "$("$PROJECT_CODE_BIN" get)" "dot"
check "default subcommand is get" "$("$PROJECT_CODE_BIN")" "dot"
teardown

echo "settings without the key: get falls back to the generated code"
setup obsidian-kingdone-chapel
mkdir -p .claude
printf '{"hooks":{}}\n' >.claude/settings.json
check "code" "$("$PROJECT_CODE_BIN" get)" "okc"
teardown

echo "a saved code wins over the generated one"
setup kix-agents
mkdir -p .claude
printf '{"env":{"PROJECT_CODE":"zzz"}}\n' >.claude/settings.json
check "code" "$("$PROJECT_CODE_BIN" get)" "zzz"
teardown

echo "repo name from a worktree subdirectory is the original repo's"
setup dotfiles
git_q worktree add -q "$work/wt/session-x-123" -b wt
mkdir -p "$work/wt/session-x-123/sub"
cd "$work/wt/session-x-123/sub" || exit 1
check "repo" "$("$PROJECT_CODE_BIN" repo)" "dotfiles"
check "generated" "$("$PROJECT_CODE_BIN" get)" "dot"
teardown

echo "generated codes"
# One word: its first three letters. Two: first and last letter of the
# first word, first letter of the second. Three or more: the first
# letter of each of the first three.
for pair in dotfiles:dot Stingdom:sti obsidian-kingdone-chapel:okc \
  kix-agents:kxa kix_agents:kxa KixAgents:kxa kixAgents:kxa \
  StingDomApp:sda my_big.repo-name:mbr a-b:aab; do
  setup "${pair%%:*}"
  check "${pair%%:*}" "$("$PROJECT_CODE_BIN" get)" "${pair##*:}"
  teardown
done

echo "set creates .claude/settings.json at the worktree root"
setup dotfiles
mkdir -p sub
(cd sub && "$PROJECT_CODE_BIN" set dot)
check "exit status" "$?" "0"
check "written" "$(jq -r .env.PROJECT_CODE .claude/settings.json)" "dot"
check "not in sub" "$([ -e sub/.claude ] && echo yes || echo no)" "no"
teardown

echo "set keeps every other key"
setup dotfiles
mkdir -p .claude
printf '{"hooks":{"SessionStart":[]},"env":{"FOO":"1"}}\n' >.claude/settings.json
"$PROJECT_CODE_BIN" set kxa
check "code" "$(jq -r .env.PROJECT_CODE .claude/settings.json)" "kxa"
check "other env" "$(jq -r .env.FOO .claude/settings.json)" "1"
check "hooks" "$(jq -c .hooks .claude/settings.json)" '{"SessionStart":[]}'
teardown

echo "set rejects invalid codes and leaves the file alone"
setup dotfiles
mkdir -p .claude
printf '{"env":{"PROJECT_CODE":"dot"}}\n' >.claude/settings.json
for bad in DOT dots d-t "" do; do
  "$PROJECT_CODE_BIN" set "$bad" >/dev/null 2>&1
  check "reject [$bad]" "$?" "1"
done
check "untouched" "$(jq -r .env.PROJECT_CODE .claude/settings.json)" "dot"
teardown

echo "malformed or non-object settings: exit 3, no temp file left"
for bad in '{bad' '[]' '"x"'; do
  setup dotfiles
  mkdir -p .claude "$work/tmp"
  printf '%s\n' "$bad" >.claude/settings.json
  "$PROJECT_CODE_BIN" get >/dev/null 2>&1
  check "get [$bad]" "$?" "3"
  TMPDIR="$work/tmp" "$PROJECT_CODE_BIN" set dot >/dev/null 2>&1
  check "set [$bad]" "$?" "3"
  check "file untouched [$bad]" "$(cat .claude/settings.json)" "$bad"
  check "no temp left [$bad]" "$(ls "$work/tmp" | wc -l | tr -d ' ')" "0"
  teardown
done

echo "outside a git repo: exit 1"
work=$(mktemp -d)
cd "$work" || exit 1
"$PROJECT_CODE_BIN" get >/dev/null 2>&1
check "exit status" "$?" "1"
teardown

if [ "$failures" -eq 0 ]; then
  echo "all passed"
else
  echo "$failures check(s) failed"
fi
exit $((failures > 0))
