#!/bin/bash
# PreToolUse hook (matcher: AskUserQuestion) and Stop hook for kix:preflight's
# diff page (kxa-a9i). A changed verdict's status call
# (`preflight-checks --diff-html`) records the page it wrote in the session
# store as `diff-page`; the skill then publishes it as an Artifact and links
# it. Demos showed the model skipping that step and going straight to the
# rerun question, so the user reviewed with no diff — and a `file://` link in
# the reply text is no fix: such text never reaches the transcript, nor the
# user (kxa-bun). This gate blocks a question, and the end of the turn, until
# the transcript shows the page was sent — an Artifact publish of it (a
# claude.ai page, which the phone opens too; kxa-9bm), else a SendUserFile
# call naming it with a caption, else its path printed in the reply — and says
# what to do. Once it sees one, it clears the record. It blocks at most twice
# per page, then lets questions and the turn's end through: a gate that can
# never be satisfied must not lock the session. Blocking is exit 2 with the
# reason on stderr, never a permissionDecision: on AskUserQuestion that reads
# as the user's answer. Anything it can't read — no jq, bad input, no record —
# lets the question through. An interim guard, until Kix checkpoints check the
# Verdict. When the page went to the user's shared folder (KIX_SHARE_DIR), the
# record's third line is its url, and only that url in the reply counts.

command -v jq >/dev/null 2>&1 || exit 0
input=$(cat)
session=$(printf '%s' "$input" | jq -r '.session_id // empty' 2>/dev/null)
cwd=$(printf '%s' "$input" | jq -r '.cwd // empty' 2>/dev/null)
transcript=$(printf '%s' "$input" | jq -r '.transcript_path // empty' 2>/dev/null)
event=$(printf '%s' "$input" | jq -r '.hook_event_name // empty' 2>/dev/null)
[ -n "$session" ] && [ -n "$cwd" ] && cd "$cwd" 2>/dev/null || exit 0
common=$(git rev-parse --path-format=absolute --git-common-dir 2>/dev/null) || exit 0
pending="$common/kix/checks/$session/diff-page"
[ -f "$pending" ] || exit 0
page=$(sed -n 1p "$pending")
blocks=$(sed -n 2p "$pending")
url=$(sed -n 3p "$pending")
[ -n "$page" ] || {
  rm -f "$pending"
  exit 0
}

# A shared page: the reply text must hold its url.
if [ -n "$url" ]; then
  if [ -f "$transcript" ] &&
    grep -F "$url" "$transcript" 2>/dev/null |
    jq -r 'select(.type == "assistant") | .message.content[]? | select(.type == "text") | .text' 2>/dev/null |
      grep -qF "$url"; then
    rm -f "$pending"
    exit 0
  fi
# grep narrows the transcript to the lines that mention the page; jq keeps a
# SendUserFile call that names it and carries a caption, or the model's own
# text that does.
elif [ -f "$transcript" ] &&
  grep -F "$page" "$transcript" 2>/dev/null |
  jq -r --arg p "$page" 'select(.type == "assistant") | .message.content[]?
      | if .type == "tool_use" and .name == "Artifact" and ((.input.action // "publish") == "publish")
        then (.input.file_path // "" | tostring)
        elif .type == "tool_use" and .name == "SendUserFile" and ((.input.caption // "") | length > 0)
        then (.input.files // [] | map(tostring) | .[])
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
printf '%s\n%s\n%s\n' "$page" $((${blocks:-0} + 1)) "$url" >"$pending"

if [ "$event" = Stop ]; then
  then_do="Then end the turn as you meant to."
  before="ending the turn"
else
  then_do="Then ask the same question again."
  before="asking"
fi
if [ -n "$url" ]; then
  cat >&2 <<EOF
Link the diff page before $before: the user reviews the changes from it. Put
"[Diff page — the commits and bead changes to review]($url)" in your reply (in
the user's language). $then_do
EOF
  exit 2
fi
cat >&2 <<EOF
Publish the diff page before $before: the user reviews the changes from it.
Call the Artifact tool with file_path "$page", icon "diff" and a description
saying what it is, then link its url in your reply as "[Diff page — the
commits and bead changes to review](<url>)" (in the user's language). Without
that tool, send it with SendUserFile (display "render", a caption saying what
it is); without either, print the path. $then_do
EOF
exit 2
