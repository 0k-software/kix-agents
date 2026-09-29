---
name: rebase
description: Rebase current branch onto another, handling pre-commit hook failures
argument-hint: [!|?] [target-branch] | --mode [interactive|auto] [--save local|project|user]
---

Rebase the current branch on top of a target branch, handling pre-commit hook
failures automatically.

## Invocation modes

- **Interactive mode** — ask the user to resolve conflicts.
- **Auto mode** — resolve conflicts without asking.

Pick the mode per invocation:

- **`/kix:rebase! [branch]`** — auto mode for this run.
- **`/kix:rebase? [branch]`** — interactive mode for this run.
- **`/kix:rebase [branch]`** — the configured mode (see below).
- **`/kix:rebase --mode [mode] [--save <scope>]`** — show, set or save the mode
  instead of rebasing (see [Setting the mode](#setting-the-mode)).

First check for the **`--mode` flag**: when the first word of `$ARGUMENTS` is
`--mode` or `--save` (`--save <scope>` alone means `--mode --save <scope>`),
don't rebase — run [Setting the mode](#setting-the-mode) and stop. That section
validates what follows. No branch name can start with `-`, so this never
shadows a target.

Otherwise, parse `$ARGUMENTS` to determine the mode and target branch:

1. If the skill was invoked as `/kix:rebase!` or `/kix:rebase?`, the marker
   appears as the first character of `$ARGUMENTS` (i.e. `$ARGUMENTS` starts
   with `!` or `?`). `!` sets **auto mode**, `?` sets **interactive mode**.
   Strip the marker before parsing the branch name. With no marker, resolve the
   configured mode.
2. Whatever remains after stripping is the **target branch**. If empty, detect
   the default branch with
   `git symbolic-ref refs/remotes/origin/HEAD | sed 's@^refs/remotes/origin/@@'`,
   falling back to `main`. Strip a leading `refs/remotes/origin/` or `origin/`
   if the user wrote one — the target is always a bare branch name here.

### Mode resolution

When `$ARGUMENTS` carries no marker, the mode is — first match wins:

1. The **session mode**: the last `/kix:rebase --mode <mode>` earlier in this
   conversation (see [Setting the mode](#setting-the-mode)). It lasts only for
   this session, and is lost if the conversation is compacted before it.
2. The `KIX_REBASE_MODE` environment variable. Claude Code builds it from the
   `env` blocks of its settings files, highest first: the repo's
   `.claude/settings.local.json`, the repo's `.claude/settings.json`, then
   `~/.claude/settings.json` — a local value beats the project's, which beats
   the user's.
3. `interactive`.

Valid values are `interactive` and `auto` (case-insensitive); ignore anything
else and fall through. Read the variable with
`printenv KIX_REBASE_MODE || true`.

State the resolved mode and its source in one short line before Step 1 (e.g.
`mode: auto (session)` or `mode: auto (KIX_REBASE_MODE)`), so a surprising
default is visible.

### Setting the mode

`/kix:rebase --mode [interactive|auto] [--save local|project|user]`:

- **`--mode`** alone: report the resolved mode and its source. To name the
  settings file behind `KIX_REBASE_MODE`, read the `env` blocks of the three
  files. The highest-priority file that sets it is the expected value: if it
  differs from the live variable, it was saved after this session started —
  list it as pending. List a lower file that sets a different value as shadowed
  by that one, never as pending. When no file sets it but the variable is set,
  name the source as the shell environment (exported before Claude Code
  started). E.g.
  `rebase mode: interactive (~/.claude/settings.json) · pending: auto (.claude/settings.local.json, next session)`.
  Change nothing.
- **`--mode <mode>`**: set the session mode — this and later `/kix:rebase` runs
  in this conversation use it. Persist nothing.
- **`--save <scope>`**, with or without a `<mode>`: when a `<mode>` is given,
  set the session mode as above. Then write the mode — the given one, else the
  currently resolved one — as `"KIX_REBASE_MODE": "<mode>"` into the `env`
  block of the scope's file:
  - `local` → the repo's `.claude/settings.local.json` (personal). Keep it out
    of commits: if `git check-ignore -q .claude/settings.local.json` fails,
    append it to the clone-local exclude file
    (`git rev-parse --git-path info/exclude`) and say so.
  - `project` → the repo's `.claude/settings.json` (committed, shared with the
    team). Say it's a repo change to commit.
  - `user` → `~/.claude/settings.json` (every project).

  Create the file if missing. Read the existing JSON first and change only that
  one key — keep every other key and setting. If the file exists but isn't
  valid JSON, stop and show it rather than overwrite it. Claude Code loads
  `env` at session start, so the saved value applies from the next session (the
  session mode covers this one). If a higher-priority file already sets
  `KIX_REBASE_MODE`, warn that it shadows the value just saved.

- **Invalid value or scope**: reply with the valid ones (`interactive`, `auto`;
  `local`, `project`, `user`). Change nothing.

End with one line, e.g.
`rebase mode: auto (session) · saved to .claude/settings.json`.

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

   The cap has to kill the hook's **children** too. A hook is a shell script
   that spawns the real work — `make`, `npx prettier --write .`, `bd` — and
   killing the script leaves those running: they go on rewriting files while
   item 4 restores the tree and Step 2 starts the rebase, which then aborts on
   a tree that was clean a moment earlier. Give the hook its own process group
   and kill the group:

   ```
   python3 -c 'import subprocess,time,os,signal; t=time.time()
   p = subprocess.Popen(["git","hook","run","pre-commit"], start_new_session=True)
   try: p.wait(timeout=30)
   except subprocess.TimeoutExpired:
       os.killpg(os.getpgid(p.pid), signal.SIGKILL); p.wait()
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

**If interactive mode:**

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

**If auto mode:**

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
