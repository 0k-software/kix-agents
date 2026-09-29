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
5. Do **not** measure the hook yet. The estimate comes out of the rebase's own
   first hook run — see "Estimate the hook time" below, which Step 2 feeds.

### Estimate the hook time

The rebase runs the pre-commit hook once per commit, so a slow hook multiplied
by a long branch can burn a lot of wall-clock time. The user should hear that
before paying it — but not at the price of a measurement run of our own.

**Measure the rebase's own first hook run, not a separate one.** Step 2 already
runs the hook after every commit via `--exec`; the first of those runs is the
measurement. That keeps the estimate free: no extra hook run, nothing to cap or
kill, and nothing to restore afterwards. An earlier draft of this skill timed a
standalone `git hook run pre-commit` before the rebase and had to undo whatever
it wrote — `make autofix`, `git add .`, a beads DB→JSONL sync — which meant
either discarding the user's tree or SIGKILLing a hook mid-write, one risking
their work and the other a corrupt database and a stale `.git/index.lock`. The
first `--exec` run costs nothing extra and carries none of that.

There is no commit-count gate on any of this. The measurement is free, so the
only question left is whether the remaining time is worth interrupting for —
which is exactly what the thresholds below decide. A 1-commit branch answers
itself (nothing left to apply, so the estimate is zero and nothing trips), and
a 2-commit branch with a six-minute hook is precisely the case a count gate
used to silence.

1. **Let the hook time itself.** Polling cannot measure it: at a 10-second
   interval a sub-second hook starts and finishes between two looks, so H would
   read as anything up to 10s and a 30-commit branch with a 0.4s hook would
   estimate 290s instead of 12 — tripping the over-5-minutes row over nothing.
   Wrap the hook in a recorder that timestamps itself, and point `--exec` at
   that instead of at the hook directly:

   ```
   cat > "$(git rev-parse --git-dir)/kix-time-hook" <<'SH'
   #!/bin/sh
   d=$(git rev-parse --git-dir)
   python3 -c 'import time; print(time.time())' >> "$d/kix-hook-times"
   git hook run pre-commit; status=$?
   python3 -c 'import time; print(time.time())' >> "$d/kix-hook-times"
   exit $status
   SH
   chmod +x "$(git rev-parse --git-dir)/kix-time-hook"
   ```

   It re-exports the hook's own exit status, so a failing hook still stops the
   rebase exactly as case B expects. Both files live inside `.git/`, so nothing
   reaches the tree or a commit; delete `kix-hook-times` before starting and
   both files when the rebase ends.

2. **Run the rebase in the background and poll it.** A blocking `git rebase`
   call returns nothing until every commit has landed, so no threshold has
   anything left to stop and the 60-second warning below could never fire.
   Start Step 2's command in the background instead and poll, roughly every 10
   seconds:

   - `.git/rebase-merge/msgnum` against `.git/rebase-merge/end`. These count
     **todo entries, not commits**: `--exec` inserts an `exec` line after every
     `pick`, so `end` is `2N` — a 3-commit rebase reports `end=6`. An odd
     `msgnum` means a commit is applying; an even one means that commit's hook
     is running. Commits still to apply are `(end - msgnum) / 2`. (`--exec`
     forces the merge backend, so `rebase-apply/` never appears — only look for
     `rebase-merge/`.)
   - the wall-clock time since `msgnum` last changed — while `msgnum` is even,
     that is how long the current commit's hook has been running.

3. **Speak up while the first run is still going.** When the first commit's
   hook passes **60 seconds** without finishing, do not wait for it: report
   right then that the hook has been running 60s and more, with `N-1` commits
   left, so the rest costs at least `60×(N-1)` seconds. In interactive mode ask
   at that point — let it finish, or `git rebase --abort` — while the run
   continues in the background; in force mode warn in red and let it run. This
   is the case where waiting for a clean measurement would mean waiting out the
   very thing being measured.

4. **H is the first clean hook run**, read from `kix-hook-times`: the first two
   lines are that run's start and end, and their difference is **H**, to the
   fraction of a second, whatever the poll interval was. No need to rebase one
   commit at a time to get it — the full rebase keeps running while you read
   the file.

   Ignore a first commit that conflicted or whose hook failed — its timing
   includes the fix, so it is not a clean sample. Take the next clean commit's
   run instead, and if none is clean by the third commit, drop the estimate and
   say so.

5. Multiply **H** by the commits still to apply — **N-1** of the count from
   Step 1 item 4, since the first one has already landed. Report it as hook
   time: it excludes conflict resolution and hook fixes, so a branch that
   conflicts will overrun it by however long those take.

Then apply the threshold that matches the estimate, **before letting the rebase
go further**:

| Estimate    | Interactive (`/kix:rebase`)       | Force (`/kix:rebase!`)            |
| ----------- | --------------------------------- | --------------------------------- |
| Under 2 min | Report the estimate, continue     | Report the estimate, continue     |
| 2–5 min     | Warn, suggest squashing, continue | Warn, suggest squashing, continue |
| Over 5 min  | **Ask** — rebase keeps running    | Big red warning, continue         |

**Nothing here ever pauses the rebase.** "Ask" means ask while it runs: you
stop to wait for an answer, the background process does not. It has no pause —
the only thing you could do to it is `git rebase --abort`, which throws away
the commits it has already applied. Doing that before the user answers would be
destroying work on the chance they might say stop, and the common answer is
"continue anyway", which then costs nothing at all. In the best case the rebase
finishes while the question is still on screen, and the answer is moot.

The warning always names the two numbers behind the estimate, so the user can
see which one to attack: "this will take a while — your pre-commit hook takes
{H}s and there are {N-1} commits left, so roughly {H×(N-1)}s". Follow it with
the suggestion to squash the branch's commits, which cuts the number of hook
runs proportionally.

Over 5 minutes, say so explicitly ("this will take more than 5 minutes") and:

- **Interactive mode:** ask, leaving the rebase running. Spell out the ways
  out: let it run, or `git rebase --abort` and squash first (a squash needs the
  abort either way), or `git rebase --abort` and leave it for later. Only abort
  on their answer — and if the rebase has already finished by then, say so and
  treat an abort answer as a question about whether to squash the landed
  result, not as licence to throw it away.
- **Force mode:** never ask. Render the warning as a large, prominent red
  notice and let the rebase run on.

## Step 2 — Start the rebase

Run as a **detached shell process** — backgrounded so the estimate above can
watch the first hook run and so a warning still has something left to stop:

**Background means the shell command, never the work.** Do not hand the rebase
to a subagent. You resolve every conflict yourself, in this session, with the
whole conversation in front of you — which is what tells a deliberate change
apart from a stale one in case C below. Backgrounding changes only how the
command is launched; a subagent would start blind to all of it.

```
git rebase refs/remotes/origin/{target} --exec "$(git rev-parse --git-dir)/kix-time-hook"
```

`kix-time-hook` is the recorder from "Estimate the hook time" item 1: it runs
`git hook run pre-commit`, timestamps both ends into `.git/kix-hook-times` and
re-exports the hook's exit status, so the outcomes below are unchanged. Without
that section (no hook configured), `--exec "git hook run pre-commit"` is the
plain form.

This applies each commit and runs the pre-commit hook after each one. Poll it
as "Estimate the hook time" describes; `git rebase` stops on its own at the
first conflict or hook failure, so a poll that finds the process gone means the
rebase either finished or is waiting for one of the two outcomes below. Three
outcomes are possible per commit:

### A) Commit applies cleanly and hook passes

Nothing to do — rebase continues automatically. Note the commit as landed in
your progress output.

On the **first** such commit, this run is also the measurement: take **H** from
it and apply the thresholds in "Estimate the hook time" before the rebase gets
further. On an over-5-minute estimate in interactive mode that means stopping
here, mid-rebase, and waiting for the user.

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
- How long it actually took, against the hook-time estimate taken from the
  first commit's hook run (conflicts and hook fixes are the gap between the
  two)
- How many conflicts were resolved (and how)
- How many pre-commit fixes were applied
- The final `git log --oneline` showing the rebased commits
