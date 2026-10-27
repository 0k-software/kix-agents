#!/bin/bash
# Stop hook: land the turn's work in a commit, one commit per prompt. The block
# reason has the agent stage and list the change in one Bash call, then write
# the message itself and commit in one more - no /kix:commit round trips
# (kxa-6ei.8: the skill's own procedure, not the message, was the cost). The kix pre-commit hook autofixes formatting and
# re-stages on its own, so only real failures come back to the agent.
# Guards first so we never burn a turn when there is nothing safe to commit.

input=$(cat)

read -r stop_active cwd <<<"$(printf '%s' "$input" | /usr/bin/python3 -c '
import json, sys
d = json.load(sys.stdin)
print("1" if d.get("stop_hook_active") else "0", d.get("cwd", ""))
' 2>/dev/null)"

# Already continuing from this hook - do not loop.
[ "$stop_active" = "1" ] && exit 0

repo="${cwd:-$PWD}"
git -C "$repo" rev-parse --is-inside-work-tree >/dev/null 2>&1 || exit 0

# Mid rebase/merge/cherry-pick/revert/bisect: committing corrupts the operation.
for op in rebase-merge rebase-apply MERGE_HEAD CHERRY_PICK_HEAD REVERT_HEAD BISECT_LOG; do
  # --git-path answers relative to the repo, not to this hook's cwd.
  (cd "$repo" && [ -e "$(git rev-parse --git-path "$op" 2>/dev/null)" ]) && exit 0
done

dirty=$(git -C "$repo" status --porcelain)

# Nothing dirty, or beads churn alone: no code progress, nothing to commit.
[ -n "$dirty" ] || exit 0
[ "$(printf '%s\n' "$dirty" | grep -cv '\.beads/issues\.jsonl$')" -gt 0 ] || exit 0

# Whether to commit is about the branch being blocked, not about its name: a
# main that takes pushes is a working branch, and a locked-down release branch
# is not. Print why an ordinary push would be refused, or nothing when it would
# land. A rule that only forbids force pushes or deletions still lets this
# commit through.
push_blocked() {
  local branch=$1 out

  case "$(git -C "$repo" remote get-url origin 2>/dev/null)" in
  *github.com*) ;;
  *) return 1 ;;
  esac
  command -v gh >/dev/null 2>&1 || return 1

  # Rulesets. Name-based, so they answer even for a branch not yet pushed.
  # Each row is the ruleset that carries the rule and what it forbids.
  out=$(cd "$repo" && gh api "repos/{owner}/{repo}/rules/branches/$branch" --jq '
    [.[] | {id: .ruleset_id, reason: (
      if .type == "pull_request" then "pull requests required"
      elif .type == "required_status_checks" then "status checks required"
      elif .type == "required_signatures" then "signed commits required"
      elif .type == "update" then "updates restricted"
      else empty end
    )}] | unique | .[] | "\(.id)|\(.reason)"' 2>&1) || return 2

  # A rule you are allowed to bypass does not stop your push. The listing
  # does not say who may bypass, so each ruleset behind a rule is asked.
  local id reason bypass reasons=
  while IFS='|' read -r id reason; do
    [ -n "$reason" ] || continue
    bypass=$(cd "$repo" && gh api "repos/{owner}/{repo}/rulesets/$id" \
      --jq .current_user_can_bypass 2>/dev/null)
    [ "$bypass" = always ] && continue
    case ",$reasons," in
    *",$reason,"*) ;;
    ,,) reasons=$reason ;;
    *) reasons="$reasons,$reason" ;;
    esac
  done <<EOF
$out
EOF

  [ -n "$reasons" ] && {
    printf '%s' "${reasons//,/, }"
    return 0
  }

  # Classic protection. The branch object only says that some exists; the
  # details need admin, so an unreadable one counts as blocked - a repo whose
  # protection you cannot read is not one to commit to unasked. Reading them
  # at all means you are an admin, so admins being exempt settles it.
  out=$(cd "$repo" && gh api "repos/{owner}/{repo}/branches/$branch" \
    --jq .protected 2>&1) ||
    case "$out" in
    # Not on the remote yet: there is no classic protection to find. Only
    # this exact 404 says so - a missing repo answers "Not Found" instead.
    *"Branch not found"*) return 1 ;;
    *) return 2 ;;
    esac
  [ "$out" = true ] || return 1

  out=$(cd "$repo" && gh api "repos/{owner}/{repo}/branches/$branch/protection" --jq '
    if .enforce_admins.enabled == false then "" else
    [ (if .required_pull_request_reviews then "pull request reviews required" else empty end),
      (if .restrictions then "pushes restricted to selected actors" else empty end),
      (if .lock_branch.enabled then "branch locked" else empty end),
      (if .required_signatures.enabled then "signed commits required" else empty end),
      (if ((.required_status_checks.checks // []) | length) > 0 then "status checks required" else empty end)
    ] | join(", ") end' 2>&1) ||
    case "$out" in
    # GitHub answered and refused - the detail is admin-only.
    *"(HTTP "*)
      printf 'branch protection, details not readable'
      return 0
      ;;
    *) return 2 ;;
    esac

  [ -n "$out" ] || return 1
  printf '%s' "$out"
}

branch=$(git -C "$repo" symbolic-ref --quiet --short HEAD 2>/dev/null)
if [ -n "$branch" ]; then
  # Cached in the repo config for a day: this runs at the end of every turn.
  now=$(date +%s)
  stamp=$(git -C "$repo" config --get "autocommit.$branch.checkedAt" 2>/dev/null)
  if [ -n "$stamp" ] && [ $((now - stamp)) -lt 86400 ]; then
    blocked=$(git -C "$repo" config --get "autocommit.$branch.blocked" 2>/dev/null)
  else
    blocked=$(push_blocked "$branch")
    # Status 2 is "could not ask" - an unreachable API is not an answer worth
    # keeping for a day, so leave it uncached and let the next turn retry.
    if [ $? -ne 2 ]; then
      git -C "$repo" config "autocommit.$branch.blocked" "$blocked"
      git -C "$repo" config "autocommit.$branch.checkedAt" "$now"
    fi
  fi

  # Blocked: say so rather than committing something that cannot be pushed.
  if [ -n "$blocked" ]; then
    BRANCH="$branch" REASON="$blocked" /usr/bin/python3 <<'NOTE'
import json, os

print(json.dumps({"systemMessage":
                  "Auto-commit skipped: %s is protected (%s), so the commit "
                  "could not be pushed from here. Move the work onto a branch, "
                  "or commit it yourself."
                  % (os.environ["BRANCH"], os.environ["REASON"])}))
NOTE
    exit 0
  fi
fi

/usr/bin/python3 <<'PY'
import json

CODE = """You left uncommitted work in the tree. Commit it now - do not ask first,
and do not run /kix:commit.

Decide before running anything: if you edited nothing this turn, everything
dirty is the user's - say so and skip the commit.

Otherwise stage everything and list it in ONE Bash call:

    git add -A && git diff --cached --stat && git log -5

Write the message yourself from what you did this turn, in the repo's style:
the commit section of its CLAUDE.md if it has one, else the subject and body
shape of that `git log`. Read a file's diff (`git diff --cached -- <file>`)
only when the stat lists one whose change you do not already know. Then commit
in ONE more Bash call:

    git commit -F - <<'EOF'
    <subject>

    <body>
    EOF

The pre-commit hook fixes formatting and re-stages on its own. If it fails for
another reason, fix what it reports and rerun the same commit command. Stop
when an attempt makes no progress (the same errors, no files changed) and
report the failure instead of retrying.

Then report the short SHA in one line."""

print(json.dumps({"decision": "block", "reason": CODE}))
PY
