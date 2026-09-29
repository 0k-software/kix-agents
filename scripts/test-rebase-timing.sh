#!/bin/sh
# Tests claude-code/skills/rebase/time-hook.sh — the recorder the rebase skill
# tells agents to use as their --exec command.
#
# There is no copy of it here and nothing is extracted: the tests run that file
# directly, the same one the plugin ships, so a change to it is a change to what
# these tests execute. Point RECORDER at another path to test a different copy.
#
# Run: sh scripts/test-rebase-timing.sh   (or: make test)

set -eu

RECORDER=${RECORDER:-claude-code/skills/rebase/time-hook.sh}
case $RECORDER in /*) ;; *) RECORDER="$PWD/$RECORDER" ;; esac

failures=0
tmproot=$(mktemp -d)
trap 'rm -rf "$tmproot"' EXIT

ok() { printf '  ok — %s\n' "$1"; }
no() {
  printf '  FAIL — %s\n' "$1"
  failures=$((failures + 1))
}

# A repo with `n` commits on feat and one divergent commit on main.
make_repo() {
  repo="$tmproot/$1"
  n=$2
  mkdir -p "$repo"
  (
    cd "$repo"
    git init -q -b main .
    git config user.email t@t
    git config user.name t
    echo base > f
    git add -A
    git commit -qm base
    git checkout -qb feat
    i=1
    while [ "$i" -le "$n" ]; do
      echo "$i" >> f
      git add -A
      git commit -qm "c$i"
      i=$((i + 1))
    done
    git checkout -q main
    echo other > g
    git add -A
    git commit -qm other
    git checkout -q feat
  )
  echo "$repo"
}

set_hook() { printf '#!/bin/sh\n%s\n' "$2" > "$1/.git/hooks/pre-commit" && chmod +x "$1/.git/hooks/pre-commit"; }

rebase() { (cd "$1" && git rebase main --exec "$RECORDER" >/dev/null 2>&1); }

lines() { wc -l < "$1/.git/kix-hook-times" | tr -d ' '; }

echo "0. the recorder the skill ships is present and runnable"
if [ -f "$RECORDER" ]; then
  ok "found $RECORDER"
else
  no "no recorder at $RECORDER"
  echo
  echo "nothing to test — stopping"
  exit 1
fi
if [ -x "$RECORDER" ]; then
  ok "it is executable, so --exec can run it"
else
  no "$RECORDER is not executable — git would refuse to exec it"
fi
if grep -q -- '--ignore-missing' "$RECORDER"; then
  ok "it passes --ignore-missing"
else
  no "it does not pass --ignore-missing (test 1 covers what that breaks)"
fi

echo "1. no pre-commit hook — the rebase must still finish"
# Regression: a bare `git hook run pre-commit` exits 1 when no hook exists, which
# as an --exec command stranded every commit after the first.
repo=$(make_repo norebasehook 3)
if rebase "$repo"; then
  ok "rebase completed with no hook configured"
else
  no "rebase failed in a repo with no pre-commit hook"
fi
if [ -d "$repo/.git/rebase-merge" ]; then
  no "a rebase is still in progress — it stranded partway through"
elif [ "$(cd "$repo" && git rev-list --count main..feat)" = 3 ]; then
  ok "all 3 commits landed, no rebase left in progress"
else
  no "expected 3 commits on feat, got $(cd "$repo" && git rev-list --count main..feat)"
fi

echo "2. passing hook — one labelled line per commit, status 0"
repo=$(make_repo passing 3)
set_hook "$repo" "exit 0"
rebase "$repo" || no "rebase failed with a passing hook"
if [ "$(lines "$repo")" = 3 ]; then
  ok "3 recorded runs for 3 commits"
else
  no "expected 3 recorded runs, got $(lines "$repo")"
fi
if [ "$(awk '{print NF}' "$repo/.git/kix-hook-times" | sort -u)" = 4 ]; then
  ok "every line has commit, start, end, status"
else
  no "malformed lines: $(cat "$repo/.git/kix-hook-times")"
fi
if [ "$(awk '$4 != 0' "$repo/.git/kix-hook-times" | wc -l | tr -d ' ')" = 0 ]; then
  ok "all statuses are 0"
else
  no "a passing hook recorded a non-zero status"
fi

echo "3. timing accuracy — a 0.4s hook must not read as 0"
# Regression: 10-second polling floored sub-second hooks to 0, zeroing the
# estimate; and whole-second `date +%s` did the same.
repo=$(make_repo timing 1)
set_hook "$repo" "sleep 0.4"
rebase "$repo" || no "rebase failed with a sleeping hook"
elapsed=$(awk 'NR==1 {print $3 - $2}' "$repo/.git/kix-hook-times")
if python3 -c "import sys; sys.exit(0 if 0.35 <= $elapsed <= 1.5 else 1)"; then
  ok "measured ${elapsed}s for a 0.4s hook"
else
  no "measured ${elapsed}s for a 0.4s hook — outside 0.35–1.5s"
fi

echo "4. failing hook — status recorded, exit propagated, rebase stops"
repo=$(make_repo failing 3)
set_hook "$repo" "exit 7"
if rebase "$repo"; then
  no "rebase reported success despite a failing hook"
else
  ok "rebase stopped on the failing hook"
fi
if [ "$(awk 'NR==1 {print $4}' "$repo/.git/kix-hook-times")" = 7 ]; then
  ok "the hook's own exit status (7) is recorded"
else
  no "expected status 7, got $(awk 'NR==1 {print $4}' "$repo/.git/kix-hook-times")"
fi
if [ "$(cat "$repo/.git/rebase-merge/msgnum")" = 2 ] && [ "$(cat "$repo/.git/rebase-merge/end")" = 6 ]; then
  ok "msgnum/end are 2/6 — todo entries, not commits (end is 2N)"
else
  no "expected msgnum=2 end=6, got $(cat "$repo/.git/rebase-merge/msgnum")/$(cat "$repo/.git/rebase-merge/end")"
fi

echo "5. a failed exec is not re-run by --continue"
# This is why a clean sample is identified by its status field and not by a
# commit appearing twice: the failing commit records exactly one line.
before=$(lines "$repo")
set_hook "$repo" "exit 0"
(cd "$repo" && git rebase --continue >/dev/null 2>&1) || true
after=$(lines "$repo")
if [ "$after" -gt "$before" ] && [ "$(awk 'NR==1 {print $1}' "$repo/.git/kix-hook-times")" = "$(awk 'NR==2 {print $1}' "$repo/.git/kix-hook-times")" ]; then
  no "the failed exec was re-run for the same commit — the status field is not needed after all"
else
  ok "no second run for the failed commit; status is the only clean-sample marker"
fi

echo
if [ "$failures" -eq 0 ]; then
  echo "all checks passed"
else
  echo "$failures check(s) failed"
  exit 1
fi
