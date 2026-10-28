#!/bin/bash
# PreToolUse hook (matcher: AskUserQuestion) for kix:preflight's diff page
# (kxa-a9i). A changed verdict's status call (`preflight-checks --diff-html`)
# records the page it wrote in the session store as `diff-page`; the skill then
# prints a `file://` link to it under the ⚠️ Verdict line. Demos showed the
# model skipping that reply and going straight to the rerun question, so the
# user reviewed with no diff. This gate blocks any question while the page's
# link is missing from the session's own reply text, and tells the model what
# to print; once the link is in the transcript it clears the record and lets
# questions through. Blocking is exit 2 with the reason on stderr, never a
# permissionDecision: on AskUserQuestion that reads as the user's answer.
# Anything it can't read — no jq, bad input, no record — lets the question
# through.

command -v jq >/dev/null 2>&1 || exit 0
input=$(cat)
session=$(printf '%s' "$input" | jq -r '.session_id // empty' 2>/dev/null)
cwd=$(printf '%s' "$input" | jq -r '.cwd // empty' 2>/dev/null)
transcript=$(printf '%s' "$input" | jq -r '.transcript_path // empty' 2>/dev/null)
[ -n "$session" ] && [ -n "$cwd" ] && cd "$cwd" 2>/dev/null || exit 0
common=$(git rev-parse --path-format=absolute --git-common-dir 2>/dev/null) || exit 0
pending="$common/kix/checks/$session/diff-page"
[ -f "$pending" ] || exit 0
page=$(head -n1 "$pending")
[ -n "$page" ] || {
  rm -f "$pending"
  exit 0
}

# Only the model's own text counts: grep narrows the transcript to the lines
# that mention the link, jq keeps those where it is assistant text.
if [ -f "$transcript" ] &&
  grep -F "file://$page" "$transcript" 2>/dev/null |
  jq -r 'select(.type == "assistant") | .message.content[]? | select(.type == "text") | .text' 2>/dev/null |
    grep -qF "file://$page"; then
  rm -f "$pending"
  exit 0
fi

cat >&2 <<EOF
Print the diff page link before asking: the user reviews the changes from it.
Write it in your reply, on the line right under the ⚠️ Verdict line:

[Open the diff page](file://$page)

Then ask the same question again.
EOF
exit 2
