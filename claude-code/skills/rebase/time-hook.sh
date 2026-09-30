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

# Epoch seconds with a fraction where the system can give one. `date +%s.%N`
# covers GNU coreutils and modern BSD date (macOS 26 supports %N; older ones
# print a literal "N", which is what the case below catches). perl is the
# fallback because it ships with macOS; whole seconds are the last resort, and
# cost up to a second of error per commit.
now() {
  t=$(date +%s.%N 2>/dev/null) || t=''
  case $t in
    '' | *[!0-9.]*) ;;
    *)
      printf '%s\n' "$t"
      return
      ;;
  esac

  t=$(perl -MTime::HiRes=time -e 'printf "%.6f\n", time' 2>/dev/null) || t=''
  case $t in
    '' | *[!0-9.]*) ;;
    *)
      printf '%s\n' "$t"
      return
      ;;
  esac

  date +%s
}

d=$(git rev-parse --git-dir)
c=$(git rev-parse --short HEAD)
start=$(now)

git hook run --ignore-missing pre-commit
status=$?

printf '%s %s %s %s\n' "$c" "$start" "$(now)" "$status" >> "$d/kix-hook-times"

exit $status
