#!/usr/bin/env bash
#
# Print a commit message for a repository's current changes — and nothing else.
#
# Drives `claude -p "/kix:commit-message"` headlessly with a read-only tool
# allowlist, then trims any stray fencing or blank padding the model added, so
# the result is safe to pipe straight into `git commit -F -` or into an
# editor's commit field (e.g. Obsidian Git).

set -euo pipefail

CLAUDE_BIN="${KIX_CLAUDE_BIN:-claude}"
MODEL="${KIX_COMMIT_MESSAGE_MODEL:-}"

# Read-only git plumbing plus file reading. Nothing here can mutate the repo.
ALLOWED_TOOLS='Bash(git status:*),Bash(git diff:*),Bash(git log:*),Bash(git rev-parse:*),Bash(git ls-files:*),Bash(git show:*),Read,Glob,Grep'

usage() {
  cat <<'USAGE'
Usage: commit-message.sh [-C <repo-dir>] [context ...]

Prints a commit message for the uncommitted changes in <repo-dir> (default:
the current directory). If anything is staged, the message describes the
staged changes only; otherwise it describes every uncommitted change,
untracked files included.

Options:
  -C <dir>   Run against this repository instead of the current directory.
  -h         Show this help.

Arguments:
  context    Free text explaining why the change was made. Used for the
             message body.

Environment:
  KIX_CLAUDE_BIN             claude executable to invoke (default: claude)
  KIX_COMMIT_MESSAGE_MODEL   model passed to claude --model (default: unset)

Exit status:
  0  a message was printed
  1  bad usage, not a git repo, or claude failed
  2  nothing to commit (no message printed)

Examples:
  commit-message.sh
  commit-message.sh -C ~/vault "sync notes from phone"
  git commit -F <(commit-message.sh)
USAGE
}

REPO="."
while getopts ":C:h" opt; do
  case "$opt" in
    C) REPO="$OPTARG" ;;
    h)
      usage
      exit 0
      ;;
    \?)
      echo "commit-message.sh: unknown option -$OPTARG" >&2
      usage >&2
      exit 1
      ;;
    :)
      echo "commit-message.sh: option -$OPTARG requires an argument" >&2
      exit 1
      ;;
  esac
done
shift $((OPTIND - 1))
CONTEXT="$*"

cd "$REPO" || {
  echo "commit-message.sh: cannot enter '$REPO'" >&2
  exit 1
}

if ! git rev-parse --git-dir >/dev/null 2>&1; then
  echo "commit-message.sh: '$REPO' is not a git repository" >&2
  exit 1
fi

if [ -z "$(git status --porcelain)" ]; then
  echo "commit-message.sh: nothing to commit" >&2
  exit 2
fi

PROMPT="/kix:commit-message"
if [ -n "$CONTEXT" ]; then
  PROMPT="$PROMPT $CONTEXT"
fi

claude_args=(
  -p "$PROMPT"
  --output-format text
  --allowedTools "$ALLOWED_TOOLS"
  --no-session-persistence
)
if [ -n "$MODEL" ]; then
  claude_args+=(--model "$MODEL")
fi

# </dev/null: claude waits ~3s for piped stdin otherwise.
if ! raw="$("$CLAUDE_BIN" "${claude_args[@]}" </dev/null)"; then
  echo "commit-message.sh: $CLAUDE_BIN failed" >&2
  exit 1
fi

# Trim blank padding, and unwrap a single surrounding ``` fence if the model
# wrapped the message in one despite the skill's output contract.
message="$(
  printf '%s\n' "$raw" | awk '
    { line[NR] = $0 }
    END {
      s = 1; e = NR
      while (s <= e && line[s] ~ /^[[:space:]]*$/) s++
      while (e >= s && line[e] ~ /^[[:space:]]*$/) e--
      if (s < e && line[s] ~ /^```/ && line[e] ~ /^```[[:space:]]*$/) {
        s++; e--
        while (s <= e && line[s] ~ /^[[:space:]]*$/) s++
        while (e >= s && line[e] ~ /^[[:space:]]*$/) e--
      }
      for (i = s; i <= e; i++) print line[i]
    }'
)"

if [ -z "$message" ]; then
  echo "commit-message.sh: no message generated" >&2
  exit 1
fi

printf '%s\n' "$message"
