#!/bin/bash
# SessionStart hook (matcher: startup) for kix:preflight's "Show me what
# changed" (kxa-a9i): records the beads DB's dolt commit as the session's start
# mark, so a session that has not reviewed anything yet still has a window to
# diff bead changes from. Resumes, clears and compactions do not match, and
# `bd-mark start` keeps the first mark anyway. It never fails or prints: a
# repo without beads, a missing jq or dolt, or bad input all end in silence.

command -v jq >/dev/null 2>&1 || exit 0
input=$(cat)
session=$(printf '%s' "$input" | jq -r '.session_id // empty' 2>/dev/null)
cwd=$(printf '%s' "$input" | jq -r '.cwd // empty' 2>/dev/null)
[ -n "$session" ] && [ -n "$cwd" ] && cd "$cwd" 2>/dev/null || exit 0
"${CLAUDE_PLUGIN_ROOT}/bin/preflight-checks" bd-mark start --session "$session" >/dev/null 2>&1
exit 0
