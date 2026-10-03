#!/bin/bash
# PreToolUse hook for mcp__ccd_session_mgmt__set_remote_control: approve
# turning Remote Control OFF without a prompt (/kix:close does it before
# archiving). Turning it ON prints nothing, so the normal permission prompt
# still runs. Only skips Claude Code's own prompt - an approval the desktop
# app asks for itself is out of a hook's reach.

enabled=$(/usr/bin/python3 -c '
import json, sys
d = json.load(sys.stdin)
print(str(d.get("tool_input", {}).get("enabled")).lower())
' 2>/dev/null)

[ "$enabled" = "false" ] || exit 0

printf '%s\n' '{"hookSpecificOutput":{"hookEventName":"PreToolUse","permissionDecision":"allow","permissionDecisionReason":"Turning Remote Control off is always allowed"}}'
