---
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
   falling back to `main`.

---

## Step 1 — Prepare

1. Verify the working tree is clean (`git status --porcelain`). If dirty, abort
   and tell the user to commit or stash first.
2. Fetch the latest from origin: `git fetch origin {target}`.
3. List the commits to rebase: `git log --oneline origin/{target}..HEAD`.
   Display them so the user knows what will be rebased. Track per-commit
   progress in your text output as you work through Step 2 — call out which
   commit is currently applying, and report when each one lands (cleanly, after
   a hook fix, or after conflict resolution).

## Step 2 — Start the rebase

Run:

```
git rebase origin/{target} --exec "git hook run pre-commit"
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
- How many conflicts were resolved (and how)
- How many pre-commit fixes were applied
- The final `git log --oneline` showing the rebased commits
