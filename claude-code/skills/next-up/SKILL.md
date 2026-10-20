---
name: next-up
description:
  Use when the user types /kix:next-up, or asks what to work on next in a repo
  tracked with beads (bd) — "what's next", "what should I pick up" — typically
  when few sessions are left, or when kix:close offers it before archiving.
---

# Next up

The user wants one answer: **what should the next session work on?** Read the
repo's beads, fix the tracker with the user one decision at a time, then name
the next five pieces of work and hand the first one off to a new session.

**Answer, don't read.** A long briefing makes the user read everything for fear
of missing something, and the reading turns into one-by-one decisions anyway.
So gather and think silently, and turn every decision into its own question.
Nothing that needs the user lives only in a paragraph; findings that need no
decision ("nothing urgent", an empty category) are not printed at all.

**Writes on yes only.** next-up runs `bd` and `git worktree` commands itself,
but only the ones the user approved, and only in the queue step, after the last
answer. It never starts the work it recommends — that goes to a new session —
and never retitles this session for the tracker moves it makes.

**Names.** Every bead, epics included, is named by its id and its title
(`kxa-9so "Bar"`), everywhere: the fix list, the fix blocks, the questions, the
next-up list, the hand-off prompt. Never a bare id.

**Links** (a PR, a compare view) go in the reply text, never inside an
AskUserQuestion: a link in a question card cannot be opened on mobile.

**No progress lines.** No emoji, no ❓/✅ step lines — the fix headings carry
the count.

**Language.** Everything you print and ask follows the language the user is
speaking. Beads may be written in other languages too: read them for meaning
whatever their language, and quote their titles as written.

**Beads only, for now.** When the repo has no `.beads/` directory or
`command -v bd` fails, say in one line that next-up needs a beads tracker, and
stop.

## Conventions

These are the defaults. The repo's own bd memories refine or override them
(Step 1), so read those first and let them win.

- **An epic is a Shape Up project**: a shaped bet with an appetite, a single
  feature big enough to be broken into pieces that depend on one another. Not a
  theme bucket. Loose issues with no epic are fine. The issue type alone marks
  an epic — no label.
- **Epic status** follows its children, first match wins: closeable when every
  child is closed; `blocked` when it has open children and every one is
  blocked; `in_progress` when any child is in_progress; `open` otherwise. An
  epic holding both closed and open children, none in_progress, is a question,
  not a rule: its closed children may have been finished as part of other work,
  so the epic was never started. Ask (Step 2) — never force `in_progress`.
- **A bead closes only after its work lands** on the default branch — its PR
  merged, or its branch's commits in `origin/<default>`. Opening a PR, or
  committing on a branch, leaves it in_progress.
- **Label overlap** between an epic's children and other work means area
  overlap.
- **Type `task` = still being shaped.** Work on a task is shaping, never
  implementing; it ends as a bug/feature/chore, a split, or an epic. A question
  is a `decision` (a choice) or a `spike` (a fact to find out); a spike that
  must be answered first blocks its decision.
- **Sweeping epics** are the large ones in flight that move or rename things
  across the codebase (renames, restructures, moves, prefix changes). A repo
  memory may name them; otherwise judge from each epic's pitch.

## Step 1 — Gather

Silent: print nothing in this step.

Run every `bd` call with stdin from `/dev/null` (`< /dev/null`): bd can block
waiting on stdin in a non-interactive shell.

```bash
bd memories --json < /dev/null               # repo conventions, full text
bd list --status=open,in_progress,blocked --limit 0 --json < /dev/null
bd ready --exclude-type epic --limit 0 --json < /dev/null
bd blocked --json < /dev/null
git status --short && git worktree list
git fetch origin --prune
git branch -r --merged origin/<default>      # branches whose work already landed
git branch -r --no-merged origin/<default>   # branches still holding work
git log origin/<default> --oneline -E --grep='<id>([^.[:alnum:]]|$)'   # cites <id>
```

`<default>` is the default branch
(`git symbolic-ref --short refs/remotes/origin/HEAD`); never assume `main`.

Bound the id in that grep: a bare `--grep='<id>'` is a substring match, so
`okc-2h2.1` also matches every `okc-2h2.12` commit.

**PR-less repos.** A repo works without PRs when a bd memory says so (e.g.
`no-prs-local-checks`), `origin` is not on GitHub, or the GitHub repo has pull
requests turned off (`gh api repos/{owner}/{repo} --jq .has_pull_requests`
prints `false`). There, make no other `gh` call at all: work has landed when it
is in `origin/<default>`, and nothing else counts. Otherwise also read the PRs:

```bash
gh pr list --state open --json number,title,headRefName,isDraft,reviewDecision
gh pr list --state merged --limit 50 --json number,title,headRefName,mergedAt
```

For the detail of many issues at once (description, notes, design,
dependencies, parent), pass all ids to one call:

```bash
bd show <id1> <id2> <id3> ... --json < /dev/null   # one array for every id
bd list ... --json < /dev/null | jq -r '.[].id' | xargs bd show --json
```

(zsh doesn't word-split `$ids`, so `bd show $ids` passes one bad argument; pipe
through `xargs`, whose children get stdin from `/dev/null`.)

Re-read every epic's children on each run — never reuse a list from an earlier
run or from a memory.

**bd gotchas:**

- `bd memories` without `--json` truncates each memory.
- `bd show` takes many ids and returns one JSON array. Don't loop over single
  ids in the shell.
- `bd list --parent <epic> --all` can still show a dotted child (`x.1`) under
  its old parent after it was reparented. Trust the JSON `.parent` field.
- `bd list` and `bd ready` cap output at 100 rows (`Showing 100 of …`). Pass
  `--limit 0`.
- To hide epics from `bd ready`, use `--exclude-type epic`. bd 1.0.3 silently
  ignored `--exclude-type` in `bd ready`; there, filter `.issue_type` from the
  JSON.

## Step 2 — Fix list

Turn every tracker problem into a small, independent fix, one command (or a
short set) each:

| Problem                                                                                                                                   | Fix                                                                                        |
| ----------------------------------------------------------------------------------------------------------------------------------------- | ------------------------------------------------------------------------------------------ |
| in_progress issue whose work landed (PR merged, its branch in `origin/<default>`, or a commit there citing its id)                        | `bd close <id> --reason="shipped to <default>"`                                            |
| closed issue whose work has not landed (PR still open, branch commits not in `origin/<default>`)                                          | `bd reopen <id>`                                                                           |
| epic whose status breaks the epic-status rule                                                                                             | `bd update <epic> --status=<…>` — the mixed case is a question: set in_progress / leave it |
| collision with a sweeping epic, either direction: current work makes the sweep harder, or the sweep will move or rewrite the current work | fold / hybrid / keep both (Step 3)                                                         |
| ordering hint living in a description or notes instead of an edge ("do after X", "whichever lands second accounts for the other")         | `bd dep add <later> <earlier>`                                                             |
| ready `task` whose description already reads as shaped                                                                                    | `bd update <id> --type=<bug\|feature\|chore>`                                              |
| stale in_progress: no branch, no worktree, no recent commit for it                                                                        | back to open (`bd update <id> --status=open`) / leave it                                   |
| worktree whose branch already landed or sits at the default branch                                                                        | `git worktree remove <path>`                                                               |
| unmerged branch no bead points at (and, outside PR-less repos, an open PR no bead points at)                                              | file a bead for it / leave it — never delete the branch                                    |

Print the list once, strict: numbered, one line per fix, the verb and every
bead it touches as id + title — no why, no command:

```
Tracker fixes (4):
1. Close kxa-abc "Foo skill" — landed on main
2. Fold kxa-9so "Bar" into kxa-5l3 "Close rewrite"
3. Retype kxa-def "Baz" task → feature
4. Remove worktree brave-wu (merged)
```

**Order.** Put first the fixes whose answer can change or cancel others (a
fold, a collision, an epic's status), then the ones they touch, then the rest.
Fixes so tightly linked that one answer decides the other are asked together:
one AskUserQuestion call takes up to four questions.

No fixes → one line saying the tracker is clean, and go to Step 5.

## Step 3 — Decide

First question: "Apply all" (Recommended) · "Go one by one".

- **Apply all:** queue every fix with its recommended option. No more
  questions, except a fix that has no recommended option (the mixed-epic
  status, a stale in_progress, an orphan branch): those are still asked one by
  one.
- **Go one by one:** one question per fix (or per linked group), in the list's
  order. Right before each question, print the fix in the reply as a short
  Markdown block — the card collapses to the chosen label once answered, and
  the block is what the user scrolls back to:

  ```
  **Fix 2/4 — Fold kxa-9so "Bar" into kxa-5l3 "Close rewrite"**

  - **What:** …
  - **Why:** …
  - **Command:** `bd …`
  ```

  The card: "Apply" (Recommended when it is) · "Skip"; "Other" is always there
  and means change — follow what the user types, and re-propose the changed fix
  (block and card) before moving on.

  A collision gets real options instead of Apply: **fold** (the work becomes
  part of the sweeping epic), **hybrid** (do the piece now in the shape the
  epic wants), **keep both** (with an order: `bd dep add`). Explain each in the
  block with bead titles, recommended first.

  Before asking a fix, check the earlier answers: a fix an earlier answer made
  moot is dropped, and one it changed is rewritten — say so in one line
  (`Fix 5/7 dropped — kxa-xyz "Qux" was folded in fix 2`).

**Nothing runs between questions.** An answer only records the decision; the
queue starts after the last one, so the user answers in one sitting.

## Step 4 — Run the queue

Run each approved fix in the list's order — the commands themselves, with
`< /dev/null` on every `bd` call. A command that fails: note its error and
carry on with the next. Then, when the repo has a Dolt remote, `bd dolt push`.

Print one plain line: `3 applied, 1 skipped` (adding `, 1 failed` and each
failure's error when any failed).

## Step 5 — Next up

Print the top five, numbered, one line each:

```
Next up:
1. kxa-abc "Foo skill" — finishes kxa-5l3 "Close rewrite", its last ready child
2. kxa-def "Baz" — unblocks kxa-ghi "Qux" and kxa-jkl "Quux"
```

Rank, first rule wins:

1. **Urgent** — P0/P1 bugs, defects that corrupt or mis-write user data,
   regressions on shipped work, anything time-boxed. Its why says plainly "stop
   X, do this".
2. **Started epics** — ready children of an in_progress epic, in the order its
   edges imply. Finishing started work comes before opening new work.
3. **The chain that unblocks the most** — among ready issues, the one whose
   closing unblocks the most downstream work.
4. **Shaping before implementing** — a ready `task` is shaping work; never
   recommend implementing it. An open `decision` comes after the `spike` that
   blocks it.

Sweeping-epic collisions kept as "keep both" in Step 3 order the two sides
here. Fewer than five ready → list what there is. None → say so, and stop.

## Step 6 — Hand off

Ask: "Start #1" (Recommended) · "Start another" · "Not now". "Start another" →
a second question with the other items (#2–#5) as options. "Not now" → stop.

On a start, build the prompt:

```
Work bead <id> "<title>" (<priority> <type>). Start with `bd show <id>` — its
description, design and notes are the spec — and `bd update <id> --claim`.

Context: <what it is, in a sentence>. <What it waits on, or what it unblocks.>
<Decisions taken in this next-up run that touch it.>

Process: /using-superpowers, then the repo's own flow — <commit/ship steps from
the repo's CLAUDE.md or memories, e.g. "commit on the branch, then offer
/kix:ship">.
```

**Desktop app** (`mcp__ccd_session__start_session` exists; load it with
ToolSearch if it is deferred): start the session — the user's "Start" answer is
their go-ahead — with `initiation: "user_asked"`, `context: "fresh"`,
`use_worktree: true`, a short `title` (`<id> <title>`), the prompt as `prompt`
and the context paragraph as `background`. Then turn Remote Control on for it:
`mcp__ccd_session_mgmt__set_remote_control` with the new session's id and
`enabled: true`. The tool needs a session that has run a turn: when it is
refused for that, call it again when the note of the new session's first turn
arrives. Say in one line which session started, linked by its id.

**Plain CLI** (no `start_session`), or a start the app refused: print the
prompt in a `text` code block for the user to paste into a new session in its
own worktree.

This session stays on planning: never start the work here.

## Common mistakes

- Printing a briefing — sections, analysis, empty categories — instead of a fix
  list and questions.
- Running a command between two questions, or one the user did not approve.
- Naming a bead by its id alone, epics included.
- A link inside an AskUserQuestion.
- Emoji or ❓/✅ progress lines.
- A `gh` call in a PR-less repo.
- Forcing `in_progress` on an epic that mixes closed and open children instead
  of asking.
- Asking a fix an earlier answer already made moot.
- Skipping `bd memories`, or letting these defaults beat a repo memory.
- Looping `bd show` over single ids, or trusting `bd list --parent` over
  `.parent`.
- Reading only the first 100 rows of `bd ready` / `bd list`.
- Recommending implementation straight from a `task`.
- Recommending new work while a started epic still has ready children.
- Starting the recommended work in this session, or retitling it for tracker
  moves.
