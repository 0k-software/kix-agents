---
name: next-up
description:
  Use when the user types /kix:next-up, or asks what to work on next in a repo
  tracked with beads (bd) — "what's next", "what should I pick up", "o que vem
  agora", "próxima tarefa" — typically when few sessions are left.
---

# Next-up briefing

The user wants one answer: **what should the next sessions work on, and in what
order?** Read the repo's beads, reason over them, and print a briefing. The
briefing is the whole deliverable.

**Read-only.** This skill analyzes and prints; it never acts. No
`bd create/update/close/dep/remember/forget`, no file edits, no commits, no
pushes, no `gh` writes. Every fix the briefing suggests is printed as a
copy-pasteable command for the user to approve and run — including tracker
drift you are sure about.

**Language.** The briefing follows the language the user is speaking.

## Conventions

These are the defaults. The repo's own bd memories refine or override them
(Step 1), so read those first and let them win.

- **An epic is a Shape Up project**: a shaped bet with an appetite, a single
  feature big enough to be broken into pieces that depend on one another. Not a
  theme bucket. Loose issues with no epic are fine.
- **Epic status** follows its children, first match wins: closeable when every
  child is closed; `blocked` when it has open children and every one is
  blocked; `in_progress` when any child is in_progress, or when it holds both
  closed and open children; `open` otherwise (no child started).
- **A bead closes only after its work lands** on the default branch — its PR
  merged, or its branch's commits in `origin/<default>` for work shipped
  without a PR. Opening a PR, or committing on a branch, leaves it in_progress.
- **Every open epic carries the label `epic`**, and no non-epic does — children
  created with `--parent` inherit it and should drop it.
- **An epic carries the union of its children's labels** (minus `epic`), so
  label overlap between an epic and other work means area overlap.
- **Type `task` = still being shaped.** Work on a task is shaping, never
  implementing; it ends as a bug/feature/chore, a split, or an epic. A question
  is a `decision` (a choice) or a `spike` (a fact to find out); a spike that
  must be answered first blocks its decision.
- **Sweeping epics** are the large ones in flight that move or rename things
  across the codebase (renames, restructures, moves, prefix changes). A repo
  memory may name them; otherwise judge from each epic's pitch.

## Step 1 — Gather

Run every `bd` call with stdin from `/dev/null` (`< /dev/null`): bd can block
waiting on stdin in a non-interactive shell.

```bash
bd memories --json < /dev/null               # repo conventions, full text
bd list --status=open,in_progress,blocked --limit 0 --json < /dev/null
bd ready --exclude-type epic --limit 0 --json < /dev/null
bd blocked --json < /dev/null
gh pr list --state open --json number,title,headRefName,isDraft,reviewDecision
gh pr list --state merged --limit 50 --json number,title,headRefName,mergedAt
git status --short && git worktree list
git branch -r --merged origin/<default>   # branches whose work already landed
git log origin/<default> --oneline -E --grep='<id>([^.[:alnum:]]|$)'   # cites <id>
```

Bound the id in that grep: a bare `--grep='<id>'` is a substring match, so
`okc-2h2.1` also matches every `okc-2h2.12` commit.

`<default>` is the default branch
(`git symbolic-ref --short refs/remotes/origin/HEAD`); never assume `main`.

For the detail of many issues at once (description, notes, design,
dependencies, parent), pass all ids to one call:

```bash
bd show <id1> <id2> <id3> ... --json < /dev/null   # one array for every id
bd list ... --json < /dev/null | jq -r '.[].id' | xargs bd show --json
```

(zsh doesn't word-split `$ids`, so `bd show $ids` passes one bad argument; pipe
through `xargs`, whose children get stdin from `/dev/null`.)

Re-read every epic's children on each run — never reuse a list from an earlier
briefing or from a memory.

**bd gotchas:**

- `bd memories` without `--json` truncates each memory.
- `bd show` takes many ids and returns one JSON array. Don't loop over single
  ids in the shell.
- `bd list --parent <epic> --all` can still show a dotted child (`x.1`) under
  its old parent after it was reparented. Trust the JSON `.parent` field.
- `bd list` and `bd ready` cap output at 100 rows (`Showing 100 of …`). Pass
  `--limit 0`.
- To hide epics from `bd ready`, use `--exclude-type epic`.
  `--exclude-label epic` also hides every child that inherited the `epic` label
  from `--parent` (flag those as drift, Step 2). bd 1.0.3 silently ignored
  `--exclude-type` in `bd ready`; there, fall back to `--exclude-label epic`
  and filter `.issue_type` from the JSON.

## Step 2 — Analyze and print

Print these sections in this order, each under its own heading. Name every bead
by its id and title, every PR by its number. When a section has nothing, say so
in one line rather than dropping it.

1. **TRACKER DRIFT** — work done but not marked so:
   - an issue still in_progress whose work has landed — PR merged, its branch
     (named with its id) merged into `origin/<default>`, or a commit on
     `origin/<default>` citing its id (branch names often carry no id);
   - an issue already closed whose work has not landed — PR still open, or
     branch commits not yet in `origin/<default>`;
   - an epic whose status breaks the epic-status rule;
   - an open epic without the `epic` label, or a non-epic carrying it;
   - an epic that is a theme, not a project: no `blocks` edge between its open
     children (parent-child and `related` edges don't count) — worth splitting
     into loose issues, or linking if its pitch says the pieces depend on one
     another.

   Follow each finding with the command that fixes it.

2. **URGENT** — anything that should interrupt current work instead of queuing
   behind it: P0/P1 bugs, defects that corrupt or mis-write user data,
   regressions on shipped work, work blocking a PR in review, anything
   time-boxed. Say plainly "stop X and do Y", or "nothing urgent".

3. **COLLISIONS** with sweeping epics, both directions. For each sweeping epic
   in flight, and each piece of current or ready work whose labels overlap it:
   - Does the current work make the epic harder — new code in an area about to
     move, new names about to be renamed, more surface for the sweep?
   - Does the epic invalidate the current work — it will be moved or rewritten
     wholesale, so it is better done after, or done now in the shape the epic
     wants?

   Name the beads on both sides and recommend an order or a reshaping.

4. **EPICS ALREADY STARTED** — each in_progress epic (or one mixing closed and
   open children): done/total, each open child with its blockers, and the order
   its dependency edges imply. Finishing started work comes before opening new
   work.

5. **IN-PROGRESS LOOSE ISSUES** — each in_progress issue with no epic: its PR
   state (`gh pr view <n> --json state,reviewDecision,statusCheckRollup`), and
   any uncommitted or unpushed work on its branch or worktree, and whether its
   branch has already landed on `origin/<default>` without a PR. Also list open
   PRs no bead points at, and worktrees whose branch already merged or sits at
   the default branch (print the `git worktree remove` for each).

6. **CHAIN THAT UNBLOCKS THE MOST** — among ready issues, the one whose closing
   unblocks the most downstream work, drawn as an ascii chain:

   ```
   dot-a1 Script facts ──▶ dot-b2 Watermark checks ──▶ dot-c3 Instant path
                        └─▶ dot-d4 Skip rebase
   ```

7. **ORDERING HINTS** living in descriptions or notes rather than edges
   ("whichever lands second accounts for the other", "do after X"). Print the
   `bd dep add` that would make each one an edge.

8. **SHAPING vs IMPLEMENTING** — ready `task`s (shaping, not coding), open
   `decision`s, and `spike`s blocking a decision. When a task's description
   already reads as shaped, print the `bd update <id> --type=<…>` that ends the
   shaping, so the recommended order can include implementing it.

9. **RECOMMENDED ORDER** — a numbered list of what to do next, each line naming
   the bead and why it sits there. End with a question asking the user which
   one to start.

## Common mistakes

- Running any bd, git or gh write — even an "obvious" drift fix. Print it
  instead.
- Skipping `bd memories`, or letting these defaults beat a repo memory.
- Looping `bd show` over single ids, or trusting `bd list --parent` over
  `.parent`.
- Reading only the first 100 rows of `bd ready` / `bd list`.
- Hiding epics with `--exclude-label epic` and silently losing children that
  inherited the label.
- Recommending implementation straight from a `task`.
- Recommending new work while a started epic still has ready children.
- Checking collisions in one direction only.
- Dropping an empty section instead of saying it is empty.
