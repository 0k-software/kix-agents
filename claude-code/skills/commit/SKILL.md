---
name: commit
description: Commit current work using the project's commit procedure (staging strategy, message generation, pre-commit hook auto-fix).
argument-hint: [!|?] [reason for the change] | --mode [interactive|auto] [--save local|project|user]
---

Commit the current intent — everything if the index is clean, only what's
staged otherwise — and generate the commit message.

## Argument parsing

First check for the **`--mode` flag**: when the first word of `$ARGUMENTS` is
`--mode` or `--save` (`--save <scope>` alone means `--mode --save <scope>`),
don't commit — run [Setting the mode](#setting-the-mode) and stop. That section
validates what follows.

Otherwise, `$ARGUMENTS` may start with a mode marker:

- `!` (e.g. `! fixed the bug`) — force **auto-fix mode** for this run (see Step
  6).
- `?` (e.g. `? fixed the bug`) — force **interactive mode** for this run.

Strip the leading marker and whitespace to obtain the **context text**. If
there is no marker, the entire string is the context text and the mode is the
**configured mode** (see [Mode resolution](#mode-resolution)).

If the context text is non-empty, treat it as the reason/motivation behind the
changes and use it to write the commit body.

### Mode resolution

When `$ARGUMENTS` carries no marker, the mode is — first match wins:

1. The **session mode**: the last `/kix:commit --mode <mode>` earlier in this
   conversation (see [Setting the mode](#setting-the-mode)). It lasts only for
   this session, and is lost if the conversation is compacted before it.
2. The `KIX_COMMIT_MODE` environment variable. Claude Code builds it from the
   `env` blocks of its settings files, highest first: the repo's
   `.claude/settings.local.json`, the repo's `.claude/settings.json`, then
   `~/.claude/settings.json` — a local value beats the project's, which beats
   the user's.
3. `interactive`.

Valid values are `interactive` and `auto` (case-insensitive); ignore anything
else and fall through. Read the variable with
`printenv KIX_COMMIT_MODE || true`.

State the resolved mode and its source in one short line before Step 1 (e.g.
`mode: auto (session)` or `mode: auto (KIX_COMMIT_MODE)`), so a surprising
default is visible.

### Setting the mode

`/kix:commit --mode [interactive|auto] [--save local|project|user]`:

- **`--mode`** alone: report the resolved mode and its source. To name the
  settings file behind `KIX_COMMIT_MODE`, read the `env` blocks of the three
  files. The highest-priority file that sets it is the expected value: if it
  differs from the live variable, it was saved after this session started —
  list it as pending. List a lower file that sets a different value as shadowed
  by that one, never as pending. E.g.
  `commit mode: interactive (~/.claude/settings.json) · pending: auto (.claude/settings.local.json, next session)`.
  Change nothing.
- **`--mode <mode>`**: set the session mode — this and later `/kix:commit` runs
  in this conversation use it. Persist nothing.
- **`--save <scope>`**, with or without a `<mode>`: when a `<mode>` is given,
  set the session mode as above. Then write the mode — the given one, else the
  currently resolved one — as `"KIX_COMMIT_MODE": "<mode>"` into the `env`
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
  `KIX_COMMIT_MODE`, warn that it shadows the value just saved.

- **Invalid value or scope**: reply with the valid ones (`interactive`, `auto`;
  `local`, `project`, `user`). Change nothing.

End with one line, e.g.
`commit mode: auto (session) · saved to .claude/settings.json`.

## Resume detection

Before running the steps below, check for `.git/kix-commit-state.json`. If it
exists, a previous `/commit` run was paused via Step 6 **Continue** — this is a
**resume**, not a fresh run.

- Load `orig_index_tree`, `had_stash`, `arguments`, `mode`, `commit_message`,
  `last_staged_diff`, and `claude_session_id` from the file.
- If `claude_session_id` differs from the current session, the original
  conversation may have additional context (e.g. why a particular fix was
  chosen). Treat it as available-on-demand background; don't auto-fetch unless
  the resume hits an ambiguity that the saved state alone can't resolve.
- If the current `$ARGUMENTS` is empty, reuse the saved `arguments` and the
  saved `mode` (so the mode persists across resumes even if the configured
  default changed in between). If non-empty, the new value wins: a `!`/`?`
  marker sets the mode, and without one the mode is resolved fresh from the
  configured mode. A state file from before `mode` was saved has no `mode`
  field — derive it from the saved `arguments` (`!` → auto-fix, otherwise
  interactive).
- **Skip Step 1** — the staging strategy was decided on the original run. Run
  `git add .` to pick up any manual fixes the user made before resuming, and
  reuse the saved `ORIG_INDEX_TREE`.
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
   - **In all branches, after staging:** capture the post-staging index with
     `git write-tree` and remember the SHA as `ORIG_INDEX_TREE` (you may need
     it in Step 6 to roll back fix attempts).
2. Run `git diff --no-ext-diff --staged` to get the diff to be committed.
3. Generate the commit message by following
   [`/kix:commit-message`](../commit-message/SKILL.md) with the context text as
   its arguments. Read that skill and apply its steps here — style resolution
   (`Commit message` section in `AGENTS.md`/`CLAUDE.md`, else the repo's own
   history) and the rest — instead of duplicating them. Its _output contract_
   does not apply here: this skill is interactive, so the message goes into
   Step 4's code block rather than being the whole response. Its diff-source
   rule resolves to the staged diff, since Step 1 already staged everything
   that belongs in the commit. Its `Where the "why" comes from` ranking matters
   most here: `/kix:commit` always runs inside a live session, so this
   conversation — the problem, the approaches tried and dropped, the trade-offs
   the user chose between, the corrections they made — is available and should
   carry the body, subject to that section's two rules (explain only what this
   diff contains; never invent a rationale).
4. Display the generated commit message inside a fenced code block (open and
   close with three backticks on their own lines) so it renders as a distinct
   block and preserves literal formatting (commit messages often contain `#`,
   `*`, or backticks that would otherwise be reflowed as markdown).
5. Run `git commit -m "..."` using a heredoc to preserve formatting.
   - **On success**, delete `.git/kix-commit-state.json` if it exists — any
     resume state has been consumed.
6. **On error:**
   - **Interactive mode**: display the error and abort. Do **not** attempt to
     fix it yourself. Still run Step 7 to restore any stashed changes.
   - **Auto-fix mode**: diagnose the failure (e.g. pre-commit hook lint/format
     errors), fix the issue, re-stage with `git add .`, and retry the commit.
     (If a stash was created in Step 1, the excluded files are not in the
     working tree, so `git add .` is safe.) Keep retrying as long as you see
     **progress** between attempts. Progress means at least one of:
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
        was created in Step 1), `arguments` (the original `$ARGUMENTS`), `mode`
        (the resolved mode, `auto` or `interactive`), `commit_message` (the
        draft from Step 3), `last_staged_diff` (the staged diff from the most
        recent attempt), and `claude_session_id` (the current Claude session
        id, so a future resume in a fresh session can pull context from the
        original session if needed).
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
