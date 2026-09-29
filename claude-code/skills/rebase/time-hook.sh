#!/bin/sh
# Runs the pre-commit hook and records how long it took, for the hook-time
# estimate in SKILL.md. Meant to be the --exec command of the rebase:
#
#   git rebase <base> --exec "${CLAUDE_PLUGIN_ROOT}/skills/rebase/time-hook.sh"
#
# Appends one line per run to .git/kix-hook-times:
#
#   <short sha> <start epoch> <end epoch> <hook exit status>
#
# The status field is what marks a sample clean. It cannot be inferred from the
# commit appearing twice: `git rebase --continue` does not re-run a failed
# `exec`, it moves to the next todo entry, so a failed run is the only line that
# commit ever gets.
#
# --ignore-missing is load-bearing: a bare `git hook run pre-commit` exits 1
# with "cannot find a hook named pre-commit" when no hook is configured, which
# as an --exec command would stop the rebase at its first commit in every repo
# without one. A hook that exists and fails still propagates its own status, so
# the rebase stops exactly as SKILL.md's case B expects.
#
# Tested by scripts/test-rebase-timing.sh — that suite runs this very file.

set -u

d=$(git rev-parse --git-dir)
c=$(git rev-parse --short HEAD)
start=$(python3 -c 'import time; print(time.time())')

git hook run --ignore-missing pre-commit
status=$?

python3 -c "import time; print('$c', $start, time.time(), $status)" >> "$d/kix-hook-times"

exit $status
