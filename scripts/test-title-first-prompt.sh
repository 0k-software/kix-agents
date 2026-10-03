#!/usr/bin/env bash
# Tests for the title-first-prompt SessionStart hook (dot-mrr): it must print
# valid hook JSON whose context tells the agent to run the title skill.
set -uo pipefail

HOOK=${HOOK:-"$(cd "$(dirname "$0")/.." && pwd)/claude/hooks/title-first-prompt.sh"}
failures=0

check() {
  local what=$1 got=$2 want=$3
  if [ "$got" = "$want" ]; then
    echo "  ok: $what"
  else
    echo "  FAIL: $what — got [$got], want [$want]"
    failures=$((failures + 1))
  fi
}

echo "startup: asks for the title skill after the first message"
out=$(printf '{"hook_event_name":"SessionStart","source":"startup"}' | bash "$HOOK")
check "exit status" "$?" "0"
check "event" "$(jq -r .hookSpecificOutput.hookEventName <<<"$out")" "SessionStart"
check "mentions title skill" \
  "$(jq -r .hookSpecificOutput.additionalContext <<<"$out" | grep -c 'title')" "1"

check "skips without the rename tool" \
  "$(jq -r .hookSpecificOutput.additionalContext <<<"$out" | grep -c 'set_session_title.*skip')" "1"

if [ "$failures" -eq 0 ]; then
  echo "all passed"
else
  echo "$failures check(s) failed"
fi
exit $((failures > 0))
