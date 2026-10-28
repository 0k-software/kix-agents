#!/bin/bash
# PreToolUse hook (matcher: AskUserQuestion) for kix:preflight's diff page
# (kxa-a9i). A changed verdict's status call (`preflight-checks --diff-html`)
# records the page it wrote in the session store as `diff-page`; the skill then
# sends it to the user with SendUserFile. Demos showed the model skipping that
# step and going straight to the rerun question, so the user reviewed with no
# diff — and a `file://` link in the reply text is no fix: such text never
# reaches the transcript, nor the user (kxa-bun). This gate blocks a question
# until the transcript shows the page was sent (a SendUserFile call naming
# it) or its path printed in the reply (a terminal without SendUserFile), and
# says what to do. Once it sees either, it clears the record. It blocks at most
# twice per page, then lets questions through: a gate that can never be
# satisfied must not lock the session. Blocking is exit 2 with the reason on
# stderr, never a permissionDecision: on AskUserQuestion that reads as the
# user's answer. Anything it can't read — no jq, bad input, no record — lets
# the question through.

command -v jq >/dev/null 2>&1 || exit 0
input=$(cat)
session=$(printf '%s' "$input" | jq -r '.session_id // empty' 2>/dev/null)
cwd=$(printf '%s' "$input" | jq -r '.cwd // empty' 2>/dev/null)
transcript=$(printf '%s' "$input" | jq -r '.transcript_path // empty' 2>/dev/null)
[ -n "$session" ] && [ -n "$cwd" ] && cd "$cwd" 2>/dev/null || exit 0
common=$(git rev-parse --path-format=absolute --git-common-dir 2>/dev/null) || exit 0
pending="$common/kix/checks/$session/diff-page"
[ -f "$pending" ] || exit 0
page=$(sed -n 1p "$pending")
blocks=$(sed -n 2p "$pending")
[ -n "$page" ] || {
  rm -f "$pending"
  exit 0
}

# grep narrows the transcript to the lines that mention the page; jq keeps a
# SendUserFile call that names it, or the model's own text that does.
if [ -f "$transcript" ] &&
  grep -F "$page" "$transcript" 2>/dev/null |
  jq -r --arg p "$page" 'select(.type == "assistant") | .message.content[]?
      | if .type == "tool_use" and .name == "SendUserFile" then (.input.files // [] | map(tostring) | .[])
        elif .type == "text" then .text
        else empty end' 2>/dev/null |
    grep -qF "$page"; then
  rm -f "$pending"
  exit 0
fi

if [ "${blocks:-0}" -ge 2 ]; then
  rm -f "$pending"
  exit 0
fi
printf '%s\n%s\n' "$page" $((${blocks:-0} + 1)) >"$pending"

cat >&2 <<EOF
Send the diff page before asking: the user reviews the changes from it.
Call SendUserFile with files ["$page"], display "render", status "normal"
(without that tool, print the path in your reply). Then ask the same
question again.
EOF
exit 2
