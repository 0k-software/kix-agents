---
name: rebase
description: Rebase current branch onto another, handling pre-commit hook failures
argument-hint: [!] [target-branch]
---

Rebase the current branch on top of a target branch, handling pre-commit hook
failures automatically.

## Invocation modes

- **`/kix:rebase [branch]`** — interactive: ask the user to resolve conflicts.
- **`/kix:rebase! [branch]`** — autonomous: resolve conflicts without asking.

Parse `$ARGUMENTS` to determine the mode and target branch:

1. If the skill was invoked as `/kix:rebase!`, set **force mode = true**. The
   `!` may appear as the first character of `$ARGUMENTS` (i.e. `$ARGUMENTS`
   starts with `!`). Strip the `!` before parsing the branch name.
2. Whatever remains after stripping is the **target branch**. If empty, detect
   the default branch with
   `git symbolic-ref refs/remotes/origin/HEAD | sed 's@^refs/remotes/origin/@@'`,
   falling back to `main`. Strip a leading `refs/remotes/origin/` or `origin/`
   if the user wrote one — the target is always a bare branch name here.

---

## The target is always the remote branch

**Never rebase onto a local branch.** The rebase base is
`refs/remotes/origin/{target}`, never the local `{target}`. The local branch is
routinely behind the remote, and rebasing onto it produces a branch that looks
rebased but is still missing commits that are already on origin — the failure
this rule exists to prevent.

This is not a decision to hand to the user: there is no case where rebasing
onto a stale local ref is what they wanted. Fetch, then use the fully spelled
`refs/remotes/origin/{target}` everywhere — the `git log` range in Step 1 and
the `git rebase` base in Step 2. The shorthand `origin/{target}` is ambiguous:
git checks `refs/heads/` before `refs/remotes/`, so a stray local branch named
`origin/main` would silently win.

---

## Step 1 — Prepare

1. Verify the working tree is clean (`git status --porcelain`). If dirty, abort
   and tell the user to commit or stash first.
2. Fetch the latest from origin: `git fetch origin {target}`. If this exits
   non-zero, abort — do **not** fall back to the local branch. Say the branch
   is not on origin only when the output contains `couldn't find remote ref`;
   for anything else (network, auth) abort as a fetch failure and quote what
   git actually printed.
3. Verify the tracking ref was created:
   `git rev-parse --verify refs/remotes/origin/{target}`. Spell out the full
   `refs/remotes/` path: the shorthand `origin/{target}` resolves to a local
   branch of that literal name first. If the ref is missing, abort — again
   without falling back to the local branch.
4. List the commits to rebase:
   `git log --oneline refs/remotes/origin/{target}..HEAD`. Display them so the
   user knows what will be rebased. Track per-commit progress in your text
   output as you work through Step 2 — call out which commit is currently
   applying, and report when each one lands (cleanly, after a hook fix, or
   after conflict resolution).
5. Estimate the hook time — see below — and report it before starting.

### Estimate the hook time

The rebase runs the pre-commit hook once per commit, so a slow hook multiplied
by a long branch can burn a lot of wall-clock time. Measure it up front instead
of letting the user discover it halfway through.

Measuring costs one hook run, so it is not always worth it:

1. **Fewer than 5 commits to rebase: skip this whole section.** Go straight to
   Step 2 without measuring or reporting. On a 1-commit branch the measurement
   costs exactly what the rebase costs, and there is nothing to squash; at 2–4
   it is a 25–50% tax on the operation to save at most three hook runs. At 5
   the tax drops to a fifth and squashing to one commit cuts 80% of the runs,
   so the advice starts paying for itself.

2. Locate the pre-commit hook. **Check `core.hooksPath` first** — a repo that
   set it (every repo `/kix:setup` touches points it at `.beads/hooks/`) keeps
   its hooks there, and `git rev-parse --git-path hooks/pre-commit` answers
   with the unused `.git/hooks/` path regardless:

   ```
   dir=$(git config --get core.hooksPath || git rev-parse --git-path hooks)
   ```

   Resolve `{dir}/pre-commit` relative to the repo root when the configured
   path is relative. If that file does not exist, skip the estimate entirely —
   the `--exec` in Step 2 is then a no-op and costs nothing — and move on to
   Step 2.

3. Time one run against the current HEAD, **capped at 30 seconds**. The cap is
   the point: without it, a hook that takes three minutes costs three minutes
   to measure — the estimate is most valuable exactly where measuring it hurts
   most. Hitting the cap is itself the answer, since a hook that has not
   finished in 30s makes any branch expensive.

   Measure **sub-second** too: a hook that takes 0.6s reads as 0 in whole
   seconds, which zeroes every estimate no matter how long the branch is, and
   BSD `date` on macOS has no `%N` to widen it.

   The cap is Python's own, not the `timeout` binary — stock macOS has no
   `timeout` (this repo's `.beads/hooks/pre-commit` guards it with
   `command -v timeout` for that reason), and shelling out to a missing one
   turns the measurement into a `FileNotFoundError`:

   ```
   python3 -c 'import subprocess,time; t=time.time()
   try: subprocess.run(["git","hook","run","pre-commit"], timeout=30)
   except subprocess.TimeoutExpired: pass
   print(time.time()-t)'
   ```

   A non-zero exit here is **not** an abort — Step 2 case B already handles
   hook failures. Use the measured duration either way.

   If the run was killed at 30s, you have a lower bound rather than a duration.
   Treat the hook as ≥30s, compute the estimate from 30s, and phrase every
   number that follows as "at least" — "at least {30×N}s". A lower bound over a
   threshold still trips that threshold: the real figure is only larger.

4. **Restore what the hook touched.** A pre-commit hook is written to run
   mid-commit, so it may well write files and stage them — the Kix hook runs
   `make autofix` and `git add .`, and beads' managed section syncs its DB to
   JSONL. Left alone, that dirty index makes Step 2 abort with
   `cannot rebase: Your index contains uncommitted changes`, and the
   measurement will have broken the very thing it was measuring. Unstage and
   discard it:

   ```
   git reset && git checkout -- .
   ```

   Both halves are unconditional discards, so they are only safe because Step 1
   item 1 already proved the tree clean — everything they throw away came from
   the hook. Never run them when that check has not just passed: they would
   take the user's uncommitted work with them.

   Then re-verify `git status --porcelain` is empty. If anything survives (an
   untracked file the hook generated, say), abort and tell the user what the
   hook left behind rather than starting a rebase on a dirty tree.

5. Multiply the hook duration by the number of commits from Step 1 item 4. That
   product is the estimate. Always report it, however small — and report it as
   hook time, which is what it measures: it excludes conflict resolution and
   hook fixes, so a branch that conflicts will overrun it by however long those
   take.

Then apply the threshold that matches the estimate:

| Estimate    | Interactive (`/kix:rebase`)      | Force (`/kix:rebase!`)           |
| ----------- | -------------------------------- | -------------------------------- |
| Under 2 min | Report the estimate, proceed     | Report the estimate, proceed     |
| 2–5 min     | Warn, suggest squashing, proceed | Warn, suggest squashing, proceed |
| Over 5 min  | **Stop and wait for the user**   | Big red warning, proceed         |

The warning always names the two numbers behind the estimate, so the user can
see which one to attack: "this will take a while — your pre-commit hook takes
{X}s and there are {N} commits, so roughly {X×N}s". Follow it with the
suggestion to squash the branch's commits first, which cuts the number of hook
runs proportionally.

Over 5 minutes, say so explicitly ("this will take more than 5 minutes") and:

- **Interactive mode:** stop. Wait for the user to choose — proceed anyway,
  squash first, or abort. Do not start the rebase before they answer.
- **Force mode:** never stop. Render the warning as a large, prominent red
  notice and start the rebase.

## Step 2 — Start the rebase

Run:

```
git rebase refs/remotes/origin/{target} --exec "git hook run pre-commit"
```

This applies each commit and runs the pre-commit hook after each one. Three
outcomes are possible per commit:

### A) Commit applies cleanly and hook passes

Nothing to do — rebase continues automatically. Note the commit as landed in
your progress output.

### B) Pre-commit hook fails

When the pre-commit hook fails after a commit is applied:

1. Read the hook output to understand what failed.
2. Fix the issues (formatting, linting, etc.).
3. Stage the fixes and amend the commit: `git commit --amend --no-edit`.
4. If the fix changes the commit's semantics, update the commit message to
   reflect what changed.
5. Run `git rebase --continue`.
6. Note the commit as landed in your progress output.

### C) Conflict occurs

1. Run `git diff` to see the conflict markers.
2. Read the conflicting files to understand the full context.

**If interactive mode (default):**

3. Explain to the user:
   - **What conflicted:** which files and hunks
   - **Why:** what the current commit changed vs what the target branch changed
     in the same area
   - **Options** (explain the final result for each):
     - **Keep ours** (current branch's version)
     - **Keep theirs** (target branch's version)
     - **Manual merge** — suggest a merged version if the changes can be
       combined
4. **Wait for the user's decision** before proceeding.

**If force mode (`/kix:rebase!`):**

3. Determine the best resolution by analyzing the intent of both sides:
   - If the current commit's change is the primary goal (e.g., a feature or
     fix), **prefer our changes** while incorporating any non-conflicting
     updates from the target branch.
   - If the target branch introduced a structural refactor (rename, move,
     rewrite) and our commit makes a small change to the old structure, **adapt
     our change to fit the new structure**.
   - When both sides add new content (e.g., imports, list items, config
     entries), **keep both**.
   - When in doubt, prefer the version that keeps the code **compiling and
     tests passing**.
4. Briefly log what you resolved and why (for the final report).

**Then, in both modes:**

5. Apply the resolution, stage the files, and run `git rebase --continue`.
6. Note the commit as landed in your progress output.

## Step 3 — Repeat

Continue handling hook failures and conflicts until the rebase completes
successfully — every commit from Step 1 should end up landed.

## Step 4 — Report

Display a summary:

- How many commits were rebased
- How long it actually took, against the Step 1 hook-time estimate (conflicts
  and hook fixes are the gap between the two)
- How many conflicts were resolved (and how)
- How many pre-commit fixes were applied
- The final `git log --oneline` showing the rebased commits
