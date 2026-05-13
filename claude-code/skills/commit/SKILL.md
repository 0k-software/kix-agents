---
description: Commit current work using the project's commit procedure (staging strategy, message generation, pre-commit hook auto-fix). Also bundles the current Claude Code session's archive into the commit.
argument-hint: [!] [reason for the change]
---

Commit the current intent — everything if the index is clean, only what's
staged otherwise — and generate the commit message. When run from a Claude Code
session, also bundle that session's archive into the same commit (see Step 1).

## Argument parsing

`$ARGUMENTS` may start with `!` (e.g. `! fixed the bug`). Strip the leading `!`
and whitespace to obtain the **context text**. If `!` is present, the skill
runs in **auto-fix mode** (see Step 6).

If `$ARGUMENTS` does not start with `!`, the entire string is the context text
and the skill runs in **interactive mode**.

If the context text is non-empty, treat it as the reason/motivation behind the
changes and use it to write the commit body.

## Resume detection

Before running the steps below, check for `.git/kix-commit-state.json`. If it
exists, a previous `/commit` run was paused via Step 6 **Continue** — this is a
**resume**, not a fresh run.

- Load `orig_index_tree`, `had_stash`, `arguments`, `commit_message`,
  `last_staged_diff`, and `claude_session_id` from the file.
- If `claude_session_id` differs from the current session, the original
  conversation may have additional context (e.g. why a particular fix was
  chosen). Treat it as available-on-demand background; don't auto-fetch unless
  the resume hits an ambiguity that the saved state alone can't resolve.
- If the current `$ARGUMENTS` is empty, reuse the saved `arguments` (so `!`
  mode persists across resumes). If non-empty, the new value wins.
- **Skip Step 1** — the staging strategy was decided on the original run, and
  the session archive was written + `git add`ed then. Run `git add .` to pick
  up any manual fixes the user made before resuming (this re-stages the archive
  too), and reuse the saved `ORIG_INDEX_TREE`.
- **Skip Step 3** if the new staged diff matches `last_staged_diff` and a saved
  `commit_message` is present — reuse the message. Otherwise regenerate the
  message in Step 3 against the new diff.
- Continue from Step 4. Re-entering Step 6 auto-fix is allowed; the same
  progress check still applies.

If the file does not exist, run the steps below normally.

The state file is consumed (deleted) on a successful commit (Step 5) and on the
**Rollback** path (Step 6). It is (re)written on the **Continue** path (Step
6).

## Steps

1. Decide the staging strategy from the current index:
   - Run `git status --porcelain` once. Each line is `XY path`: `X` is the
     index status (non-space = something staged), `Y` is the worktree status
     (non-space = unstaged modifications), and `??` marks untracked files.
     Classify into one of the three branches below from that output alone.
   - **All unstaged** (nothing staged, working tree has changes): run
     `git add .` to stage all changes (unstaged + untracked). The user wants to
     commit everything. No stash is created.
   - **All staged** (index has changes, nothing unstaged or untracked):
     everything the user curated is already in the index — commit it as-is. No
     stash is created.
   - **Unstaged & Staged** (mixed): assume the user curated the index
     deliberately. Run
     `git stash push --keep-index --include-untracked -m "kix-commit-autostash"`
     to set aside unstaged + untracked changes so they don't leak into the
     commit, and remember that a stash was created.
   - **In all branches, after staging:** invoke
     [`/kix:save-session --no-commit`](../save-session/SKILL.md) — it writes
     this session's archive (`docs/conversations/<stem>/raw.jsonl.gz` +
     `summary.md`, and `.prettierignore` if needed) into the checkout and
     `git add`s it, without committing. (It's a no-op when there's no
     transcript, e.g. a plain chat session — fine; carry on.) Don't
     re-implement any of that here. The archive then rides along in this commit
     — the transcript is the work this session did. Finally capture the
     post-staging index with `git write-tree` and remember the SHA as
     `ORIG_INDEX_TREE` (you may need it in Step 6 to roll back fix attempts).
2. Run `git diff --no-ext-diff --staged` to get the diff to be committed.
3. Write a commit message following `Commit message` instructions in
   `AGENTS.md`/`CLAUDE.md`. If none, base yourself from
   `git log -1 --pretty=%B`.
   - **NEVER ADD** `Co-Authored-By` footer note, as you're actually helping me
     generate the commit message, not writing the code yourself.
4. Display the generated commit message inside a fenced code block (open and
   close with three backticks on their own lines) so it renders as a distinct
   block and preserves literal formatting (commit messages often contain `#`,
   `*`, or backticks that would otherwise be reflowed as markdown).
5. Run `git commit -m "..."` using a heredoc to preserve formatting.
   - **On success**, delete `.git/kix-commit-state.json` if it exists — any
     resume state has been consumed.
6. **On error:**
   - **Interactive mode** (no `!`): display the error and abort. Do **not**
     attempt to fix it yourself. Still run Step 7 to restore any stashed
     changes.
   - **Auto-fix mode** (`!`): diagnose the failure (e.g. pre-commit hook
     lint/format errors), fix the issue, re-stage with `git add .`, and retry
     the commit. (If a stash was created in Step 1, the excluded files are not
     in the working tree, so `git add .` is safe.) Keep retrying as long as you
     see **progress** between attempts. Progress means at least one of:
     - the error output is materially different from the previous attempt
       (different errors, fewer errors, different files), or
     - your fix actually changed files (`git diff --staged` differs from the
       previous attempt).

     **Stop retrying** if neither holds — that means you're about to repeat the
     same fix and get the same failure.

     When you stop, the working tree + index contain your fix attempts and **no
     commit was created**. **Do not** continue to Step 7 yet. Instead:
     1. **Write the resume state to `.git/kix-commit-state.json` before
        prompting the user.** Do this first, so the state survives a session
        kill while waiting for the user's reply. Required fields:
        `orig_index_tree` (the SHA from Step 1), `had_stash` (true if a stash
        was created in Step 1), `arguments` (the original `$ARGUMENTS`),
        `commit_message` (the draft from Step 3), `last_staged_diff` (the
        staged diff from the most recent attempt), and `claude_session_id` (the
        current Claude session id, so a future resume in a fresh session can
        pull context from the original session if needed).
     2. Report the failure clearly: the commit was not created, the fix loop
        stopped, your fix attempts are in the working tree + index, and resume
        state has been written to `.git/kix-commit-state.json`. If a stash was
        created in Step 1, add a note that the `kix-commit-autostash` stash is
        also still in place.
     3. Ask the user how to proceed:
        - **Rollback** — throw away all fix attempts and restore the working
          tree + index to the exact state from before `/commit` was called. Use
          `ORIG_INDEX_TREE` (saved in Step 1) to restore the post-staging
          snapshot. Delete `.git/kix-commit-state.json` — the rollback restored
          a clean pre-`/commit` state, so there's nothing to resume. If a stash
          was created in Step 1, then run Step 7 to pop it; otherwise skip
          Step 7.
        - **Continue** — leave the working tree, index, stash, and resume state
          file exactly as they are; return control so the user (or another
          tool, AI-assisted or not) can investigate and fix the issue manually.
          **Skip Step 7** — anything still stashed stays in place and is the
          user's to resolve. Tell the user that the next `/commit` invocation
          will resume from the saved state, or they can delete
          `.git/kix-commit-state.json` to discard.
     4. Wait for the user's choice before doing anything destructive.

     Do **not** fabricate or report a commit SHA, and do **not** claim success
     for commit-dependent workflows.

7. **If a stash was created in Step 1**, run `git stash pop` to restore the
   user's working tree. Run this on success, on interactive-mode abort, and
   when the user picks **Rollback** in Step 6. Do **not** run it when the user
   picks **Continue** — that path intentionally leaves the stash in place.
   - If `git stash pop` reports merge conflicts (likely when an auto-fix
     touched the same files the user had unstaged), resolve them: inspect the
     conflict markers and pick the correct content (typically the auto-fixed
     version is already what the user would want). After resolving, run
     `git reset` to clear the index back to the post-commit state, and verify
     with `git status` that the working tree matches the user's pre-commit
     state plus any auto-fixes. If the stash was kept due to conflicts, drop it
     explicitly with `git stash drop` once resolved.
