---
name: preflight
description:
  Use when the user types /kix:preflight, or asks whether the current branch is
  ready to land on the default branch ("tá pronto pra main?", "revisa a
  branch", "pode subir?"), or when another skill (kix:ship, and kix:close through kix:ship)
  needs the branch checked before it moves.
---

# Preflight the branch

Preflight answers one question — **can this branch land on the default branch
without losing anything?** — and turns every loose end into a fix, a deferred
item (when the repo has an inbox for them), or an explicit dismissal. It is the
only place a review happens: `kix:ship` and `kix:close` run it, and never
review on their own.

**Language.** This skill is written in English; everything you produce follows
the language the user is speaking: replies, the findings list, ReportFindings
text, AskUserQuestion questions and option labels, and the content of every
note, task or commit body you write (labels included — a Portuguese arrival
says `Sessão do Claude:`).

## Repo type

Detect it once, before step 1, from the repository root
(`git rev-parse --show-toplevel`). The first match wins:

1. **Kingdone** — `Gates/Gates.md` exists (the Obsidian vault layout). Deferred
   work becomes an **arrival** note in `Gates/`.
2. **Beads** — a `.beads/` directory exists and `command -v bd` succeeds.
   Deferred work becomes a **bd task**.
3. **Neither** — there is no inbox. Nothing gets deferred by this skill; the
   user handles open items their own way.

Everything marked _(Kingdone)_ or _(Beads)_ below applies only to that type. In
a Kingdone repo the vault's own conventions (its `CLAUDE.md`) apply to every
job: renames through the Obsidian CLI, and so on.

**Default branch.** Never assume `main`:

```bash
git symbolic-ref --short refs/remotes/origin/HEAD 2>/dev/null \
  || { git remote set-head origin --auto >/dev/null && git symbolic-ref --short refs/remotes/origin/HEAD; }
```

This prints e.g. `origin/main`. Below, `<base>` is that ref and `<default>` is
the branch name without `origin/`.

## Check marks

A checked commit carries a git note in `refs/notes/checks` whose first line
reads `checked <session id>` — the `$CLAUDE_CODE_SESSION_ID` of the session
that ran the checks — written by step 2 right after its checks ran on that
commit. The first word is what makes a commit checked; the session id only
decides whether _Already checked_ may skip (older notes read just `checked`).
The mark only records that the checks ran — it is not an approval; the approval
is the user's "Ship" answer in `kix:ship`. `kix:ship` reads it; only preflight
writes it.

## Progress

The user wants to see where a run is while it runs. When each step ends, print
one progress line (none when it starts; the only other lines are the ❓ line
before a question and the ⏳ line when a Fixes job starts, both below),
numbered across the whole run the user started (the `<command>` of _Verdict_),
not per skill. Each check of step 2 is a step of its own:

| Step                                        | `/kix:preflight` | `/kix:ship` | `/kix:close` |
| ------------------------------------------- | ---------------- | ----------- | ------------ |
| Rebase (1)                                  | 1/11             | 1/15        | 1/17         |
| Code review (2a)                            | 2/11             | 2/15        | 2/17         |
| Conversation (2b)                           | 3/11             | 3/15        | 3/17         |
| Checklists (2c)                             | 4/11             | 4/15        | 4/17         |
| Tracker (2d)                                | 5/11             | 5/15        | 5/17         |
| Look ahead (2e)                             | 6/11             | 6/15        | 6/17         |
| After ship (2f)                             | 7/11             | 7/15        | 7/17         |
| Report (3)                                  | 8/11             | 8/15        | 8/17         |
| Decide (4)                                  | 9/11             | 9/15        | 9/17         |
| Fixes (5)                                   | 10/11            | 10/15       | 10/17        |
| Verdict (6)                                 | 11/11            | 11/15       | 11/17        |
| Confirm, Gate, Push, Check (`kix:ship` 2–5) | —                | 12–15       | 12–15        |
| Mark task done, Archive (`kix:close` 2a–2b) | —                | —           | 16–17        |

Each line starts with an emoji for the step's state, then `<n>/<total>` and the
step name:

| Emoji | When                                                                | Example                                                |
| ----- | ------------------------------------------------------------------- | ------------------------------------------------------ |
| ✅    | the step finished and worked — with its result                      | `✅ 3/15 Conversation — 0 findings`                    |
| ⏭️    | the step does not apply                                             | `⏭️ 9/15 Decide — no findings`                         |
| ⚠️    | the user must act on something, now or later — say what             | `⚠️ 11/15 Verdict — changed: …`                        |
| ❓    | right before each question to the user — with a short summary of it | `❓ 9/15 Decide — finding 2/6: tally vs split`         |
| ⏳    | a Fixes job starts                                                  | `⏳ 10.1/15 Fixes — job 1/2: ❓ before every question` |

Fixes (progress step 10 in every run) numbers each job as a sub-step: `10.1`,
`10.2`, … Print its ⏳ line when the job starts and its ✅ or ⚠️ line, with the
commit or task id, when the job is done:
`✅ 10.1/15 Fixes — job 1/2: ❓ before every question (bb5098b)`. The step's
own ✅ line follows the last job.

Before **every** AskUserQuestion — in any step of preflight, `kix:ship` or
`kix:close`, each one-by-one finding question and each discard-reason question
included — print a ❓ line right before calling the tool:
`❓ <n>/<total> <Step> — <very short summary of what is about to be asked>`
(e.g. `❓ 9/15 Decide — finding 2/6: tally vs split`,
`❓ 12/15 Confirm — ship these 3 commits?`,
`❓ 17/17 Archive — archive this session?`). The step still ends with its ✅ or
⚠️ line; Decide's ✅ line counts each kind of decision (e.g.
`✅ 9/15 Decide — 2 fixes queued, 1 skipped`).

A run that finishes ends with its last step's own line, saying what that step
actually did — `✅ 15/15 Check — 14 commits landed on main (1435da0..a21b626)`,
not a bare `done`.

⚠️ means "don't lose this": anything the user has to do after the run, even
when it blocks nothing and needs no answer now (a question needing an answer
now is ❓). Use it for a run that stopped before its last step, and for any
step result that leaves the user something to do later — a deferred task to
pick up, a branch or worktree to clean, a skill to reinstall, another session
that must ship first. Put it on the step line where it shows up
(`⚠️ 5/15 Tracker — dot-a7j done by this branch, close it after the ship`).
Every run that leaves anything pending ends with a ⚠️ block listing each item
and what to do, after the last step's line:

```
⚠️ Stopped at 11/15 Verdict — to do next:
- skim bb5098b..44b795d, then run /kix:ship again
- close dot-a7j after the ship
```

Every step gets its own line, printed as that step ends — even when several
steps end with nothing to say. Never fold them into one summary ("steps 1–6
clear"):

```
✅ 1/15 Rebase — already on main
✅ 2/15 Code review — 0 findings
✅ 3/15 Conversation — asks 0 · unanswered 0/0 · deferred 0 · promised 0 · inferred 0
```

Each step runs at least one real command of its own (a grep, a `bd` search, a
`git` call — whatever the step actually needs), and its progress line goes out
right after that command, as its own message. Never put several steps' lines in
one text block: the app shrinks such a block into one summary line.

## 1. Rebase onto the default branch

Before any review, bring the branch up to date, so everything is reviewed on
top of the current `<default>`. On a dirty tree, commit first (project commit
procedure) — a rebase needs a clean tree.

**Notes guard.** Check marks must not survive a rebase: a rebased commit sits
on new code and needs a new review. Check:

```bash
git config --show-scope --get-all notes.rewriteRef
```

If any value is `refs/notes/checks`, or a glob that matches it
(`refs/notes/*`), unset that entry in the scope it came from —
`git config --<scope> --unset-all notes.rewriteRef '^<value>$'` (escape `*` as
`\*`) — and warn the user: which scope, which value, and that check marks would
otherwise follow rebased commits and fake the checks. A glob also stops
rewriting the other notes it covered; say so.

Fetch (the check marks too, so marks pushed from another clone count):

```bash
git fetch origin
git fetch origin refs/notes/checks:refs/notes/checks 2>/dev/null || true
```

Then rebase onto `<base>` with the `kix:rebase` skill when it is available — it
re-runs the pre-commit hook on every commit; slow, but worth the wait. Invoke
it with a leading `?` (`kix:rebase ? <base>`) to force its interactive mode
whatever the user's configured default: the abort-on-conflict step below needs
the rebase to stop on a conflict, not auto-resolve it. An older `kix:rebase`
(its _Invocation modes_ list no `?` marker) would read the `?` as part of the
branch name: invoke it with just `<default>` then — interactive is its only
default. Without it, `git rebase <base>`. Then
`git push --force-with-lease origin HEAD` (on `<default>` itself there is no
branch push).

A rebase that moved the branch leaves its old check marks behind on the old
commits: the code now sits on a new `<default>`, so it gets checked again. That
is intended.

If the rebase stops on a conflict, abort it (`git rebase --abort`) and stop
everything: "Before anything else, this branch needs a rebase onto `<default>`,
and it conflicts. Nothing lands until the branch sits on `<default>`."
Resolving the conflict is the user's call.

## 2. Collect findings

Run all six checks, in this order, in the main session, before asking anything.
No check goes to an agent: an agent starts without the conversation, and most
checks read it — the code review too, to tell a bug from intended behavior — so
an agent either misses it or pays for a copy of it. A measured run found
nothing an agent caught that the inline run missed, at about three times the
tokens.

**Skips.** After _Already checked_ (below), one Bash call finds the checks with
nothing to look at:

```bash
git diff --shortstat <from>..HEAD   # a: <from> as check a finds it, else <base>
git diff --name-only <base>...HEAD -- '*.md'   # c
```

| Check          | Skip when                                 |
| -------------- | ----------------------------------------- |
| a. Code review | nothing after `<from>`                    |
| c. Checklists  | no Markdown file touched                  |
| d. Tracker     | _(Neither)_ — there is no tracker to read |

A skipped check prints `⏭️ <n>/<total> <Step> — <reason>` (e.g.
`no Markdown touched`), right after that call. b, e and f always run.

**Already checked.** When, after step 1, the tree is clean and HEAD's mark was
written by this very session, the committed code is exactly what this session's
last run checked, so every check that reads only committed git state gives the
same answer: skip it. A rebase that moved the branch, or step 1's commit of a
dirty tree, leaves HEAD unchecked, so nothing is skipped then. A mark from
another session or clone (notes come from origin) skips nothing either: this
session has no findings of its own to carry over. Decide it with this one test
— no judgement, no reading the conversation:

```bash
[ -z "$(git status --porcelain)" ] && [ -n "$CLAUDE_CODE_SESSION_ID" ] \
  && git notes --ref=checks show HEAD 2>/dev/null | grep -qx "checked $CLAUDE_CODE_SESSION_ID" \
  && echo SKIP
```

It matches any line of the note, not only the first: when a rejected notes push
falls back to `git notes merge -s union` (below), two sessions' lines stack on
the same commit.

Skip only when it prints `SKIP`; otherwise run every check.

| Check           | When the test prints `SKIP`                                                          |
| --------------- | ------------------------------------------------------------------------------------ |
| a. Code review  | skip — reads only the diff                                                           |
| b. Conversation | run — reads the session                                                              |
| c. Checklists   | skip — same files, and this same session already ran it                              |
| d. Tracker      | _(Kingdone)_ skip — the vault is in HEAD; _(Beads)_ run — bd state lives outside git |
| e. Look ahead   | run — reads the session and the tracker too                                          |
| f. After ship   | run — reads the session and the task                                                 |
| Mark the checks | skip — HEAD already carries the mark                                                 |

A skipped check prints
`⏭️ <n>/<total> <Step> — HEAD <short sha> already checked` and carries over
every finding of its kind from this session's latest ReportFindings call that
has no `outcome` — still open, into the new report as they were. Its line still
follows a real command (the test above).

**a. Code review.** Find `<from>`, the newest commit this session checked (see
_Check marks_) — a mark from another session or clone does not count, for the
same reason _Already checked_ ignores it: its findings are not here to carry
over:

```bash
[ -n "$CLAUDE_CODE_SESSION_ID" ] && for c in $(git rev-list <base>..HEAD); do
  git notes --ref=checks show "$c" 2>/dev/null | grep -qx "checked $CLAUDE_CODE_SESSION_ID" \
    && { echo "$c"; break; }
done
```

Run the `code-review` skill at level `medium` on everything after it — or on
the whole branch against `<base>` when it prints nothing — plus any uncommitted
change — unless _Already checked_ skips it. Keep its findings for the combined
report below.

**b. Conversation.** Read the whole session and list:

- things the user asked for that were not done, or were done only in part;
- questions you asked that the user never answered — an AskUserQuestion the
  user skipped, dismissed or rejected is unanswered;
- questions the user asked that you never answered, or answered only in part —
  a question buried in a longer message counts;
- things the user deferred ("later", "tomorrow", "I'll look at it");
- follow-ups you promised;
- inferred loose ends: what the work implies but nobody said (run it for real,
  update a doc or note the change contradicts, a memory to record; _(Kingdone)_
  test it in Obsidian). Say where each came from.

If the conversation was summarized earlier, say so: findings before the summary
are only as good as the summary.

This check's progress line tallies each of the six kinds, e.g.
`✅ 3/15 Conversation — asks 0 · unanswered 0/0 · deferred 0 · promised 0 · inferred 1`;
`unanswered x/y` is questions the user left unanswered / questions you left
unanswered.

**c. Checklists.** For every Markdown file the branch (or the dirty tree)
touched — _(Kingdone)_ every note outside `Gates/` — look at its unchecked
`- [ ]` items. Each one is a finding when the file is marked done (a completed
quest or plan, a closed status, a "done" heading) or the item is pending work
the session left behind. Usual causes: it was cancelled, it was deferred
somewhere nobody linked, or it was done and not ticked.

**d. Tracker.** Search the tracker for items related to the work — by the
files, the feature, the names and the terms the branch touches, not only by the
id in the branch name:

- _(Beads)_ open and in-progress bd issues (`bd list --limit 0` — plain
  `bd list` stops at 50 —, `bd search <term>`, `bd show <id>` for their
  dependencies);
- _(Kingdone)_ arrivals in `Gates/`, quests anywhere (in progress, planned or
  someday), and unchecked `- [ ]` items in any note, not only the touched ones;
- _(Neither)_ skip this check.

List each item the work affects, either way:

- this work does it, fully or in part — it can be closed, ticked or updated;
- it depends on this work, or is blocked by it — it should know this lands (a
  note, a link, an unblocked dependency);
- this work depends on it, or conflicts with work it plans;
- it plans something this work changes or makes obsolete.

Each is a finding with a concrete suggested fix: close or tick it, add a note
or link saying what landed, add or drop a dependency, or rewrite the plan. The
issue or quest the branch itself is about is not a finding: `kix:close` marks
it done after the ship — unless this session created or rewrote it (below).

**Items this session wrote.** A session whose work is the tracker itself — it
created a bd issue or an arrival, or rewrote one's title, description, design
or acceptance — has nothing for the code review (no diff: check a skips), but
those items are its deliverable and get checked here, each one. Find them from
the conversation (every `bd create` / `bd update` it ran, every arrival it
wrote), then `bd show <id>` each. For each item, a finding for anything below:

- **Well-formed** — an imperative title that says what gets done; a description
  with why it exists and what to do, enough for a session that never saw this
  conversation; a real type and priority; acceptance criteria when it is more
  than a one-liner; `--parent` or deps where the conversation or the tracker
  puts it (an epic it belongs under, what blocks it); what the user actually
  said, not a narrower or broader version of it.
- **Related** — search the tracker for it the same way as above (its files,
  feature, names and terms): a duplicate or near-duplicate (merge, or close one
  as a duplicate), an item it overlaps, an epic it belongs under, an item it
  depends on or blocks. Each missing link is a finding.
- **Unanswered** — open questions the item leaves: a choice it names but does
  not make, a "TBD", a design decision the conversation raised and nobody
  settled. The fix is to ask the user now and write the answer into the item.
- **Pitfalls** — what the plan misses: edge cases, callers or sibling configs
  it will have to touch, other sessions or branches working on the same thing,
  a migration or reinstall it will need. The fix is a line in the item, not new
  work.

Fixes for these are `bd update` (or an edit to the arrival), never code. These
findings use the category `tracker`. A session that only wrote tracker items
still runs b, e and f as usual; b's unanswered questions and e's pitfalls about
the item go in this check instead, so nothing is reported twice.

**e. Look ahead.** From the work done — the diff, the conversation, the touched
files — list what nobody raised: nothing already in the conversation or in the
tracker (check d) goes here:

- related things the change touches or should touch but nobody mentioned (other
  callers, sibling configs, docs, other repos or branches that depend on it);
- ideas the work suggests — improvements worth having, not needed now;
- next steps — the natural follow-up work;
- possible pitfalls — how it could break, be misused or surprise later (edge
  cases, environments, concurrency with other sessions or branches, upgrades).

Each is a finding like any other, with a concrete suggested fix: usually the
defer option (a task or an arrival), or doing it now when it is small. Only
real, specific items — no generic advice; say what triggered each.

**f. After ship.** A closed task means nothing is left to do: the work is in
use, or — for a task other tasks depend on — ready for them to start. From the
diff, the conversation and the touched files, list what still has to happen
**after** the branch lands on `<default>` before that is true: data migrations,
database schema migrations, configuration changes on a machine or a service, a
deploy, an install or reinstall (`make install`, a skill, a plugin), a secret
or env var to set, a restart, a manual check in the real app. Only what cannot
be done before the ship — anything doable now is a look-ahead finding (check e)
with the fix "do it now".

Each is a finding (`category: after-ship`) whose suggested fix is to write it
down in the current task, never to do it: the "Note in the task" job of step 5.
Skip what the task already says. `kix:close` reads the task before marking it
done, so what the task says is still pending keeps it open. _(Neither)_ there
is no tracker: the finding's fix is a ⚠️ line in the run's closing ⚠️ block.

**Mark the checks.** As soon as the six checks have run (or been skipped by
_Already checked_, which also skips this mark), mark the commit they looked at
— HEAD — as checked. The mark says only that: the checks ran on this commit. It
is not an approval; the approval is the user's "Ship" answer in `kix:ship`. Any
later commit (a fix, an arrival) is not checked, and the next preflight checks
it.

```bash
git notes --ref=checks add -f -m "checked ${CLAUDE_CODE_SESSION_ID:-unknown}" HEAD
git push origin refs/notes/checks
```

If the notes push is rejected, run
`git fetch origin refs/notes/checks:refs/notes/checks-remote`,
`git notes --ref=checks merge -s union refs/notes/checks-remote`, and push
again.

## 3. Report

Make **one** ReportFindings call with every finding from the six checks, code
review first. It replaces any call the code-review skill made. Per finding:

- `file` / `line`: where it lives — the code, the file with the checklist, or
  the file the conversation item is about;
- `category`: for code-review findings, the category the code review gave;
  otherwise `conversation`, `checklist` or `tracker`, or for the look-ahead
  check `related`, `idea`, `next-step` or `pitfall`, or `after-ship` for the
  after-ship check;
- `summary`: the problem, then the fix "apply all" will run, fenced so it
  stands out in one line of plain text (line breaks get eaten):
  `… |—| SUGGESTED FIX: <fix> |—|`;
- `failure_scenario`: what is lost or goes wrong if the branch lands now.

Then print the same list in chat, complete: the ReportFindings card renders
poorly on mobile (Remote Control), so the chat list must stand on its own —
nothing only the card shows. Per finding:

```
N/T. `<file>:<line>` — <problem>
   Fix: <suggested fix>
   If left: <failure scenario>
```

Wherever a finding is named — the chat list, a question, a ❓ line, a job's ⏳
or ✅ line — give its number out of the total: `finding 6/9`, `6/9.`.

Zero findings → go to step 6 (Verdict).

## 4. Decide

First AskUserQuestion, a single question: "Apply all suggested fixes"
(Recommended) · "Go one by one".

- **Apply all:** queue every suggested fix (step 5). No more questions.
- **One by one:** walk **every** finding from the report — code review,
  conversation, checklist, tracker, look-ahead and after-ship alike — one
  AskUserQuestion per finding, one question per call. Ask **all** of them
  first, back to back: an answer only records the decision, nothing runs yet.
  No fix, commit, task or `bd update` happens between two questions — step 5
  starts only after the last finding (and its discard reason) is answered, so
  the user answers in one sitting and walks away while the queue runs. Right
  before each question, after its ❓ line, print the finding in the reply as a
  short block the user can read and scroll back to — the card collapses to the
  chosen label once answered. Print it as Markdown, not in a code block, with
  exactly this shape — a bold heading, then one labelled bullet per line, never
  a prose paragraph:

  ```
  **Finding 6/9 — `<file>:<line>`**
  - **Problem:** <what goes wrong and when — one line>
  - **If left:** <the failure scenario — what breaks, for whom>
  - **Fix (recommended):** <the fix> — <why this one over the others>
  - **Alt — <other fix>:** <what it does, its trade-off>   (one per extra fix)
  - **Note:** <only what is specific to deferring, discarding or leaving this
    finding, e.g. an existing task that already covers it — omit otherwise>
  ```

  **Problem**, **If left** and **Fix** are always there, even under caveman
  ultra — caveman shortens each bullet to fragments, it never drops a bullet or
  merges them into a paragraph.

  The question is one short line pointing at that block — "Finding 6/9 — take
  the recommended fix?" — never the finding itself. Options, in this order,
  each with its description:
  - the suggested fix (Recommended);
  - each other real fix, when there is more than one — list them, keep your
    pick first;
  - the defer option, by repo type:
    - _(Kingdone)_ "Create arrival" — "Creates an arrival in your inbox (Gates)
      to do this another time; releases the ship after a re-run.";
    - _(Beads)_ "Create task" — "Creates a bd task to do this another time;
      releases the ship after a re-run.";
    - _(Neither)_ no defer option;

    An after-ship finding gets no defer option: its suggested fix already
    leaves it for later, in the task itself;

  - "Discard" — "ATTENTION: DISMISSES THE FINDING FOR GOOD AND RELEASES THE
    SHIP. It does not matter; ship anyway. Asks for the reason.";
  - "Leave for later" — "Not now, no decision yet. Keeps the finding open (no
    outcome) in ReportFindings, which blocks the ship until a later preflight
    resolves it."

  AskUserQuestion takes at most four options: when the fixes, the defer option,
  "Discard" and "Leave for later" do not fit, drop the least likely extra fix
  and mention it in the block above. "Other" is always there; follow whatever
  the user types.

  When the user picks "Discard", ask right away, in its own AskUserQuestion,
  why — the reason is required. The question is short ("Why discard finding
  6/9?"); the finding is already in the block above. Offer 2–3 likely reasons
  for this specific finding as options (e.g. "Not a real problem", "Intended
  behavior", "Not worth the cost"); "Other" takes free text. Only a discard
  with a reason counts: a skipped or empty answer leaves the finding undecided
  — ask again, or treat it as "Leave for later". Under "Apply all" nothing is
  discarded, so no reason is needed.

## 5. Run the queue

Every decision that changes files or the tracker becomes one job. Jobs run
**one at a time**, in order, in the main session: finish one (its commit and
push) before starting the next. Never run two at once — each commits, and a
pre-commit hook may reject a commit while other changes sit unstaged. No job
goes to an agent: the jobs run in sequence anyway, so an agent saves no time,
and it would start without the conversation that explains the fix.

Each job follows these rules:

- **Fix:** apply it and make one atomic commit for it (project commit procedure
  — `kix:commit` when available), then push the branch. A fix to a bd issue is
  a `bd update` (and `bd dep add` for a link), then `bd dolt push` when the
  repo has a Dolt remote — no commit; the job's ✅ line names the issue id
  instead of a commit.

- _(Kingdone)_ **Create arrival:** one note in `Gates/`:

  ```markdown
  # <Infinitive verb and what to do>

  Claude session: [<session title>](<session link>), on DD/MM.
  <Two or three lines of context: what was left and why.>

  ## Checklist

  - [ ] <Concrete step, linking the exact note when there is one>
  ```

  Write `R\$`, never a bare `$`. Then edit the note the finding came from,
  whenever there is one, so it points at the arrival: a checklist item becomes
  `[-]` with `→ arrival created: [[Gates/<title>|<title>]]` at its end;
  anything else (a paragraph, a heading, a decision) gets a line saying it left
  a pending item in that arrival, with the link. Commit the arrival and the
  source edit together (`docs(gates): add arrival for …`) and push.

- _(Beads)_ **Create task:** find the current work first — the issue the branch
  is about: an id in the branch name, the issue claimed or worked on in this
  session, or one the conversation names. If none is identifiable, create the
  task unrelated and say so. Then:

  ```bash
  bd create --type=task --priority=2 \
    --title="<Imperative verb and what to do>" \
    --description="Claude session: [<session title>](<session link>)
  Source: <file>:<line>

  <Two or three lines of context: what was left and why.>" \
    <relation>
  ```

  `<relation>` is `--parent=<id>` when the current work is an epic, otherwise
  `--deps=discovered-from:<id>`; leave it out when there is none. When the
  finding is a checklist item, mark it `[-]` with `→ task created: <task id>`
  at its end, commit that edit (one commit) and push. Finish with
  `bd dolt push` when the repo has a Dolt remote.

- **Note in the task:** write the item into the current work's own content — no
  new task, arrival, label or heading of our own. Say when it applies, in the
  words the moment calls for ("after this is merged to `<default>`", "before
  deploying", "after the deploy"), and what to do. Follow how the project
  already writes such things. Look for a stored habit first — _(Beads)_
  `bd memories after-ship`; _(Kingdone)_ the project's memory. Only when there
  is none, look at how its other tasks or quests phrase them and where they put
  them (when nothing shows a habit, append a short paragraph), then store what
  you found so the next run skips the search — _(Beads)_
  `bd remember --key after-ship-convention "<where and how>"`; _(Kingdone)_ a
  project memory.

  - _(Beads)_ the current issue's description
    (`bd update <id> --description=…`, keeping what is there), or its notes
    when that is where the project keeps them; then `bd dolt push` when the
    repo has a Dolt remote. No identifiable current issue → do not write it
    anywhere; the finding becomes a ⚠️ line in the closing ⚠️ block, and say
    so.
  - _(Kingdone)_ the current quest's main note; commit it and push.

- **Session title and link** (arrival or task) come from
  `mcp__ccd_session_mgmt__get_session` with `"self"`. When those tools are not
  available (a session started from the phone through a terminal
  `claude remote-control` server), take the title from the conversation and
  write it without a link.

- **Discard / Leave for later:** no job.

When the queue is empty, call ReportFindings again with each decided finding's
`outcome`: `fixed` for an applied fix, `skipped` for a discard and for an
arrival or task (after-ship ones included). A discarded finding's `summary`
ends with `|—| DISCARDED: <reason> |—|`. A finding left for later gets no
outcome: it stays open. Reprint the chat list with each finding's result —
fixed (with its commit), deferred (arrival link or task id), discarded —
<reason>, or still open.

## 6. Verdict

End every run with exactly one verdict. Callers (`kix:ship`, and `kix:close`
through `kix:ship`) move on only on **clear**. Below, `<command>` is the slash
command of the skill the user started — `/kix:preflight`, `/kix:ship` or
`/kix:close` — even when they started it in plain words.

**Showing the diff.** Give the compare link when the remote is on GitHub, one
link only — for the branch diff
`https://github.com/<owner>/<repo>/compare/<default>...<HEAD sha>`, for this
run's commits `.../compare/<first commit>^...<HEAD sha>`, the caret so the
first commit's own changes show. It opens anywhere, phone included. The link
goes in the reply itself, never only inside an AskUserQuestion: links do not
render in a question card on mobile. When the remote is not on GitHub, print
the range's `git log --oneline` and `git diff --stat` in the reply instead.
Never open the app's diff pane (`mcp__ccd_view__show_pane`) — it fails more
often than not — and never tell the user a keyboard shortcut.

- **Changed** — step 5 committed anything (fixes, arrivals, checklist edits),
  or a Fix job edited a tracker item (`bd update`, `bd dep add`) — a bd edit
  commits nothing, but the user has not seen it either. The rebase and step 1's
  commit of a dirty tree do not count: step 2 checked them. Show the diff of
  the step 5 commits (above) and, for each edited item, `bd show <id>` in the
  reply, then say: "There were changes. Review them yourself — skim the diff —
  and if they look like what you expect, rerun." Then ask the rerun question
  (below). Those commits and items are not checked yet; the next run checks
  them.
- **Open** — any finding in the latest ReportFindings has no `outcome` (left
  for later). List what is still open, show the branch diff (above), then ask
  the rerun question (below) for when the user is ready to decide them.
- **Clear** — HEAD's first note line starts with `checked`, every finding in
  the latest ReportFindings has an `outcome`, and step 5 committed nothing and
  edited no tracker item. Say so. When preflight was run on its own, stop here
  — it never ships.

**Rerun.** A link can't run a slash command, but an answer can. After a
**changed** or **open** verdict's ⚠️ block, print a ❓ line (e.g.
`❓ 11/15 Verdict — rerun /kix:ship?`), write what is being asked and each
option in the reply, as the global _Asking questions_ rule says, and ask with
AskUserQuestion. The only link is the compare link the verdict already printed
in the reply — the step 5 commits for **changed**, the branch diff for **open**
— never a second link with a different range, and never inside the question.
The question depends on the verdict:

- **Changed** — the reply says outright that new commits landed that the user
  has not seen: "`<n>` new commits landed since your last look
  (`<first short sha>..<HEAD short sha>`). The next run checks them, but you
  haven't seen them." — naming the edited tracker items instead of (or next to)
  the commits when a Fix job edited any. The question: "Run `<command>` again?"
  Options:
  - "I reviewed — run `<command>` again" (Recommended) — "You skimmed the new
    commits. The rerun checks them again on its own.";
  - "Run again, skip my review" — "Rerun now without looking. Only the
    automated review checks the new commits.";
  - "Not now" — "Stop. The ⚠️ block stays."
- **Open** — nothing new was committed; the reply lists what is still open. The
  question: "Rerun `<command>` to decide them?" Options: "Run `<command>`
  again" (Recommended) · "Not now".

On any run option, rerun `<command>` right away, from its first step, with
fresh progress numbering. On "Run again, skip my review", the skip goes on
record: the rerun's final ⚠️ block (add one if the run would otherwise end
without it) carries
`- <first short sha>..<HEAD short sha> went through without your review — skim it`,
even when that run ships. On "Not now", stop — nothing runs after the answer.

## Common mistakes

- Two ReportFindings lists (one from code-review, one of yours) instead of one.
- A chat list that leaves out what the ReportFindings card shows.
- A one-by-one question with no finding block printed right before it, or with
  the whole finding stuffed into the question text instead.
- A finding block written as a paragraph, or missing its **Problem**, **If
  left** or **Fix** bullet.
- One-by-one that skips the code-review findings.
- One-by-one that applies each fix right after its answer (ask, fix, ask, fix)
  instead of asking every question first and running the queue after the last.
- Skipping the look-ahead check, or padding it with generic advice.
- Doing an after-ship item before the ship, or creating a task, arrival, label
  or heading for it instead of writing it in the current task the way the
  project already does.
- Searching the tracker only by the branch's issue id, or only in the touched
  files.
- Waving through a session that only created or rewrote tracker items because
  there is no diff — those items are its work, and check d reviews each one.
- Running the code review on a session with no diff, or answering a finding on
  a bd issue with a code change instead of a `bd update`.
- Listing only the questions the user left unanswered, not the ones you did.
- Running two queue jobs at once, or bundling several fixes in one commit.
- Calling a run **clear** after it committed anything, or while any finding has
  no outcome.
- Shipping from here — preflight only gives a verdict.
- Opening the diff pane or telling the user a keyboard shortcut instead of
  giving the compare link.
- Treating "Leave for later" as a discard.
- Discarding without a reason, or inventing one for the user.
- Rerunning a git-only check (code review, checklists, a Kingdone tracker
  search) when the _Already checked_ test prints `SKIP`, or skipping the
  conversation, look-ahead or a bd tracker search because HEAD is checked.
- Skipping on a check mark written by another session (or with
  `$CLAUDE_CODE_SESSION_ID` unset) — only an exact `checked <this session id>`
  skips.
- Sending a check or a Fixes job to an agent instead of running it in the main
  session.
- Taking the code-review range from a check mark another session or clone
  wrote.
- Reviewing before the rebase, or rebasing with `notes.rewriteRef` still
  carrying check marks.
- Hardcoding `main` instead of the detected default branch.
- Numbering progress per skill (`1/11` inside a `/kix:ship`) instead of across
  the whole run, or dropping the line for a skipped step, printing a line when
  a step starts instead of when it ends, or folding several steps into one
  line.
- Printing several steps' progress lines in one text block instead of one
  message per step, each right after that step's own command.
- Asking the user anything without printing the ❓ line first, or printing it
  after the question.
- Running Fixes jobs without their `<step>.<job>` ⏳ and ✅ lines.
- Naming a finding by its number alone (`finding 6`) instead of out of the
  total (`finding 6/9`).
- Ending a **changed**, **open** or ship _Gate_ stop with only a text "run it
  again" instead of the rerun question.
- A **changed** rerun reply that doesn't say new, unseen commits landed, or
  that offers only "I reviewed" — a user who skips the review on purpose must
  have an honest option — or dropping the "without your review" ⚠️ item after
  "Run again, skip my review".
- Ending a run with pending items but no ⚠️ block, or marking something the
  user must do later with ✅.
- Offering a defer option in a repo that has no inbox, or Kingdone conventions
  (Gates, `R\$`) outside a Kingdone repo.
- Counting a skipped or dismissed question as answered.
- Naming an arrival without linking it, or a task without its id; leaving the
  source checklist item without a pointer back.
- Writing in English to a user who speaks Portuguese.
