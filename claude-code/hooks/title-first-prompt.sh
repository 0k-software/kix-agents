#!/bin/bash
# SessionStart hook (matcher: startup) for the kix:title skill (dot-mrr in
# dotfiles): a hook cannot pick the tracker item or the state, so it only asks
# the agent to run the kix:title skill once the user's first message is in.
# Resumes, clears and compactions do not match, so a running session keeps its
# title. Terminal CLI sessions have no rename tool and skip it: the skill would
# only print a /rename line for the user.

printf '%s\n' '{"hookSpecificOutput":{"hookEventName":"SessionStart","additionalContext":"Session title: right after the user'"'"'s first message in this session, before anything else, run the `kix:title` skill (no arguments) so the session gets its `<emoji> <code>-<id> │ <description>` title — only when the `mcp__ccd_session_mgmt__set_session_title` tool exists (the desktop app, deferred tools included); in a terminal CLI session without it, skip this. Do it once; later state changes follow the Session title rule in CLAUDE.md."}}'
