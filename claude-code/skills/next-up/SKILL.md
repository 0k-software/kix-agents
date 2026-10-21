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
answer. It starts the work it recommends only when the user picks "Start here"
(Step 6) — otherwise that goes to a new session — and never retitles this
session for the tracker moves it makes.

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

| Problem                                                                                                                                                                                                                                                                                 | Fix                                                                                        |
| --------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- | ------------------------------------------------------------------------------------------ |
| in_progress issue whose work landed (PR merged, its branch in `origin/<default>`, or a commit there citing its id)                                                                                                                                                                      | `bd close <id> --reason="shipped to <default>"`                                            |
| closed issue whose work has not landed (PR still open, branch commits not in `origin/<default>`)                                                                                                                                                                                        | `bd reopen <id>`                                                                           |
| epic whose status breaks the epic-status rule                                                                                                                                                                                                                                           | `bd update <epic> --status=<…>` — the mixed case is a question: set in_progress / leave it |
| collision with a sweeping epic, either direction: current work makes the sweep harder, or the sweep will move or rewrite the current work                                                                                                                                               | fold / hybrid / keep both (Step 3)                                                         |
| ordering hint living in a description or notes instead of an edge ("do after X", "whichever lands second accounts for the other")                                                                                                                                                       | `bd dep add <later> <earlier>`                                                             |
| ready `task` whose description already reads as shaped                                                                                                                                                                                                                                  | `bd update <id> --type=<bug\|feature\|chore>`                                              |
| stale in_progress: no branch, no worktree, no recent commit for it                                                                                                                                                                                                                      | back to open (`bd update <id> --status=open`) / leave it                                   |
| worktree whose branch landed with at least one commit, whose tree is clean (`git -C <path> status --porcelain` empty), and that no active session works in (`list_sessions`, when available) — a branch merely sitting at the default branch is a fresh session's worktree, never stale | remove it (`git worktree remove <path>`) / leave it                                        |
| unmerged branch no bead points at (and, outside PR-less repos, an open PR no bead points at)                                                                                                                                                                                            | file a bead for it / leave it — never delete the branch                                    |

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
  status, a stale in_progress, a worktree removal, an orphan branch): those are
  still asked one by one.
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

**#1 from this session first.** What this session already settled beats the
tracker's order — when kix:close called next-up, that is the closing session.
Only ready beads count; first match wins:

1. **Named next** — the session says explicitly which bead comes next: the
   user's own words ("kxa-xyz is next", "create a P1 for right after this
   one"), or a bead filed in this session with a note that it follows this
   work. A bead that only came up in the conversation does not count.
2. **Its epic's next child** — the session's bead (the one it claimed or worked
   on) has a parent epic with open children: the epic's next ready child, in
   the order its edges imply.
3. Neither → no session pick; the ranking below picks #1.

A session pick is #1 and the rest keep the ranking's order after it — unless
the ranking's own #1 is **Urgent** (below) and is another bead. Then ask, with
AskUserQuestion, which one is #1: each option names the bead by id and title
and says why it is there ("named in this session", "next child of kxa-5l3
"Close rewrite"", "P1 bug"). The other one follows it.

Either way, #1's line says which rule picked it: "named in this session", "next
ready child of <epic id> "<epic title>"", or the ranking's own why.

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

**Where.** A start runs in a new session or here, in this one. First
`git fetch origin`: the previous branch may have just gone to `<default>`, and
every check and branch below must see its tip. Here is possible only when this
session's own work has landed: the tree is clean (`git status --porcelain`
prints nothing) and `HEAD` holds no commit missing from `origin/<default>`
(`git merge-base --is-ancestor HEAD origin/<default>`) — the next bead never
starts on top of unlanded work. When it is possible, ask "New session" · "Start
here". Recommend "New session" when `mcp__ccd_session__start_session` exists
(load it with ToolSearch if it is deferred) — "Its own worktree session; this
one stays as it is." — and "Start here" when it does not (plain CLI, the
phone), where a new session means pasting a prompt by hand — "Paste a prompt
into a new session yourself.". "Start here": "This session moves to a fresh
branch from `<default>` and starts it, the conversation so far kept." When
"Start here" is not possible, go to a new session without asking, and say why
in one line (`Not here: <branch> holds unlanded work — /kix:ship it first`).

On a start, build the prompt:

```
Work bead <id> "<title>" (<priority> <type>). Start with `bd show <id>` — its
description, design and notes are the spec — and `bd update <id> --claim`.

Context: <what it is, in a sentence>. <What it waits on, or what it unblocks.>
<Why it is #1: the rule that picked it.> <Decisions taken in this next-up run
that touch it.>

Process: /using-superpowers, then the repo's own flow — <commit/ship steps from
the repo's CLAUDE.md or memories, e.g. "commit on the branch, then offer
/kix:ship">.
```

**New session, desktop app** (`start_session` exists): start the session — the
user's "Start" answer is their go-ahead — with `initiation: "user_asked"`,
`context: "fresh"`, `use_worktree: true`, a short `title` (`<id> <title>`), the
prompt as `prompt` and the context paragraph as `background`. Then turn Remote
Control on for it: `mcp__ccd_session_mgmt__set_remote_control` with the new
session's id and `enabled: true`. The tool needs a session that has run a turn:
when it is refused for that, call it again once more right before next-up
returns, and again when the note of the new session's first turn arrives,
whichever comes first. When kix:close called next-up, the archive may come
before that note: close's _Side sessions_ step retries it then. Say in one line
which session started, linked by its id, and whether Remote Control is on.

**New session without `start_session`** (plain CLI, the phone), or a start the
app refused: print the prompt in a `text` code block for the user to paste into
a new session in its own worktree.

**Start here.** When kix:close called next-up, stop here and hand the prompt
back to close: close finishes its own cleanup first and then runs these steps.
Otherwise, in order:

1. **Fresh branch.** A new branch `<id>-<two-or-three-word slug of the title>`
   (`kxa-e5h-start-here`) at the tip of `origin/<default>` as fetched in
   _Where_ — fetch again if anything ran since, so it sits on top of the commit
   the previous branch just landed:
   - in a linked worktree (`git rev-parse --git-dir` differs from
     `git rev-parse --git-common-dir`):
     `git switch --no-track -c <branch> origin/<default>` — `--no-track`, or a
     bare `git push` / `git pull` would target `<default>`. The previous branch
     stays as it is; its work is already on `<default>`.
   - in the main checkout: never switch it — other worktrees and the plugin may
     read it. Enter a new worktree with the `EnterWorktree` tool
     (`name: <branch>`, loaded with ToolSearch if deferred); then make sure
     `HEAD` is `origin/<default>` (`git merge --ff-only origin/<default>` when
     it is behind). Without that tool, do not start here: print the prompt for
     a new session instead.

   Then confirm: `git rev-parse HEAD` equals `git rev-parse origin/<default>`.

2. **Claim and title.** `bd update <id> --claim < /dev/null`, then run the
   `kix:title` skill with the bead's id as its argument — the new bead is this
   session's main item now, and its title state reads the claim.
3. **Keep the conversation.** Never clear the session, nor offer or suggest
   `/clear`: clearing loses the earlier context, which may be needed later. The
   printed prompt is the new task's anchor; compaction handles the length.
4. **Work.** Print the prompt in a `text` code block, then follow it as this
   session's task: `bd show`, /using-superpowers, the repo's flow (the claim is
   already done).

Outside "Start here", this session stays on planning: never start the work
here.

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
- Ranking from the tracker alone when the session already named the next bead
  or works under an epic with a ready child — or picking between a session pick
  and an Urgent bead without asking.
- Starting the recommended work in this session without the user's "Start
  here", or retitling it for tracker moves.
- Starting here on top of unlanded work, before fetching, or in the main
  checkout's own branch.
- Clearing the session, or offering `/clear`, when starting here.
