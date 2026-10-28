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

## Deterministic checkpoints

`preflight-checks` (on PATH from the kix plugin's `bin/`; else
`claude-code/bin/preflight-checks` in a kix-agents checkout) runs every check
that needs no judgement in one call. Preflight calls it with `--format tsv`:
one bare tab-separated `<name> <status> <detail>` line each, no table padding
to spend tokens on (the default, `pretty`, is a table for a person at a
terminal). Read its lines instead of running the git commands yourself:

| Line                      | Status                                  | What it says                                                               |
| ------------------------- | --------------------------------------- | -------------------------------------------------------------------------- |
| `default`                 | fact                                    | `<base>`, e.g. `origin/main` (`-`: no default branch found)                |
| `from`                    | fact                                    | the HEAD `diff-review`'s marker saw, when an ancestor of HEAD; `-`         |
| `shortstat`               | fact                                    | diff from `<from>` (else the merge base with `<base>`) to HEAD             |
| `markdown`                | fact                                    | Markdown files the branch or the dirty tree touches                        |
| `fetch`                   | fact                                    | `fetched`, `fresh` (cached), `failed` or `skipped`                         |
| `uncommitted-changes`     | pass · finding                          | uncommitted changes                                                        |
| `unlanded-commits`        | pass · finding · skip                   | commits not on `<base>`                                                    |
| `behind-default-branch`   | pass · finding · skip                   | `<base>` is not an ancestor of HEAD                                        |
| `open-checkboxes`         | fresh · stale · never · unknown · skip  | marker status; the detail ends with ` — <file:line list>`                  |
| `diff-review`             | fresh · stale · never · unknown · skip  | marker status of the code review                                           |
| `acceptance-criteria`     | fresh · stale · never · unknown · skip  | marker status; stale too when the branch's bead was updated                |
| `conversation-leftovers`  | fresh · stale · never · unknown · skip  | marker status; stale on new conversation                                   |
| `related-tracker-items`   | fresh · stale · never · unknown · skip  | marker status; _(Beads)_ stale too on any bd update                        |
| `unraised-follow-ups`     | fresh · stale · never · unknown · skip  | marker status                                                              |
| `post-landing-steps`      | fresh · stale · never · unknown · skip  | marker status                                                              |
| `findings-leftovers`      | pass · finding                          | open findings on this branch: `none open`, or their ids                    |
| `unreviewed-bead-changes` | pass · finding · stale · unknown · skip | beads changed since the user's last review (else session start): their ids |

A markable row (the seven between `behind-default-branch` and
`findings-leftovers`) reads its check's marker (_Markers_ below):

- `fresh` — nothing the check reads changed since its marker; the detail is
  `no changes since <at>`;
- `stale` — the detail names the delta, comma-joined:
  `new commits since <short>`, `rebased since <short>`, `dirty tree`,
  `<n> bd update(s) since <t>`, `<id> updated`, `conversation since <ts>`
  (`conversation unknown since <run>` when there is no transcript to read);
- `never` — no marker (`no marker`): the check never ran on this branch in this
  session;
- `unknown` — the marker can't tell, there is no transcript to read
  (`since <run>`);
- `skip` — no marker and nothing to look at; the detail says why (`no changes`,
  `no unchecked items`, `no tracker`).

It runs twice: at step 1 with `KIX_FETCH_TTL=0` (always fetches), and at the
start of step 2 with `--no-fetch`, after step 1 may have committed or rebased.

**Default branch.** Never assume `main`: `<base>` is the `default` line (e.g.
`origin/main`) and `<default>` is the branch name without `origin/`.

## Markers

Each check's runs and findings live in a per-session store under the git common
dir (`kix/checks/<session>/`), shared by every worktree of the repo and read
per branch. Only `preflight-checks` writes it — never edit its files:

- `preflight-checks start` — opens a run and prints its
  `🛫 preflight check started here · <time>` line;
- `preflight-checks mark <check> [--bead <id>]` — records that `<check>` ran;
  stdin is a JSON array of its **new** findings (`[]` for none); prints their
  ids (`<check>-<n>`);
- `preflight-checks resolve <id> fixed | deferred <ref> | discarded <reason…>`
  — closes a finding;
- `preflight-checks findings [<check>]` — the open findings on this branch, as
  one JSON array (`id`, `check`, `category`, `file`, `line`, `summary`,
  `short_summary`, `failure_scenario`, `ref`; the optional ones only when set);
- `preflight-checks bd-mark review` — records that the user has seen every bead
  change up to now (the beads DB's dolt commit) and prints a
  `👀 beads reviewed up to <short> · <time>` line; a SessionStart hook writes
  the session's start mark the same way. `unreviewed-bead-changes` and `diff`
  count from the latest review mark, else the start mark;
- `preflight-checks diff [--from <sha>] [--html <file>]` — what changed, for
  the user to review: with `--from`, the commits `<sha>^..HEAD` (inline, or a
  stat when long), then every bead change in that window as a git-style diff —
  fields, deps, labels, comments — with a ⚠️ line when other sessions of the
  repo ran in it. `--html` also writes it all to `<file>` as a page: the
  commits in full, and the changed words inside each changed line highlighted,
  like GitHub's diff.

A marker records only that the check ran, and what it saw (HEAD, the tree, the
latest conversation, bd state). It is not an approval; the approval is the
user's "Ship" answer in `kix:ship`. A finding stays open until something
resolves it — `mark` takes only new ones, so nothing needs passing back to
carry it to the next run.

## Asking questions

Every AskUserQuestion, in this skill and in every kix skill that points here
(`kix:ship`, `kix:close`, `kix:next-up`), goes out in this order:

1. the text the user needs to answer it — a finding block, the options
   explained, the compare link — in the reply;
2. a real command of its own (a `grep`, a `bd show`, a `git` call that the
   question is about);
3. the ❓ line;
4. the AskUserQuestion call.

The app summarizes the reply text that comes right before a question card, and
on mobile the user then gets a one-line summary instead of the block. A tool
call between the text and the card keeps the text whole (checked on mobile,
2026-10-24). Links never go inside the question: a link in a card cannot be
opened on mobile.

## Progress

The user wants to see where a run is while it runs. When each step ends, print
one progress line (none when it starts; the only other lines are the 🛫 line
from `preflight-checks start`, the ❓ line before a question and the ⏳ line
when a Fixes job starts, below), numbered across the whole run the user started
(the `<command>` of _Verdict_), not per skill. Each check of step 2 is a step
of its own:

| Step                                        | `/kix:preflight` | `/kix:ship` | `/kix:close` |
| ------------------------------------------- | ---------------- | ----------- | ------------ |
| Rebase (1)                                  | 1/12             | 1/16        | 1/18         |
| Diff review (2a)                            | 2/12             | 2/16        | 2/18         |
| Acceptance criteria (2b)                    | 3/12             | 3/16        | 3/18         |
| Conversation leftovers (2c)                 | 4/12             | 4/16        | 4/18         |
| Open checkboxes (2d)                        | 5/12             | 5/16        | 5/18         |
| Related tracker items (2e)                  | 6/12             | 6/16        | 6/18         |
| Unraised follow-ups (2f)                    | 7/12             | 7/16        | 7/18         |
| Post-landing steps (2g)                     | 8/12             | 8/16        | 8/18         |
| Report (3)                                  | 9/12             | 9/16        | 9/18         |
| Decide (4)                                  | 10/12            | 10/16       | 10/18        |
| Fixes (5)                                   | 11/12            | 11/16       | 11/18        |
| Verdict (6)                                 | 12/12            | 12/16       | 12/18        |
| Confirm, Gate, Push, Check (`kix:ship` 2–5) | —                | 13–16       | 13–16        |
| Mark task done, Archive (`kix:close` 2a–2b) | —                | —           | 17–18        |

Each line starts with an emoji for the step's state, then `<n>/<total>` and the
step name:

| Emoji | When                                                                | Example                                                |
| ----- | ------------------------------------------------------------------- | ------------------------------------------------------ |
| ✅    | the step finished and worked — with its result                      | `✅ 4/16 Conversation leftovers — 0 findings`          |
| ⏭️    | the step does not apply                                             | `⏭️ 10/16 Decide — no findings`                        |
| ⚠️    | the user must act on something, now or later — say what             | `⚠️ 12/16 Verdict — changed: …`                        |
| ❓    | right before each question to the user — with a short summary of it | `❓ 10/16 Decide — finding 2/6: tally vs split`        |
| ⏳    | a Fixes job starts                                                  | `⏳ 11.1/16 Fixes — job 1/2: ❓ before every question` |

Fixes (progress step 11 in every run) numbers each job as a sub-step: `11.1`,
`11.2`, … Print its ⏳ line when the job starts and its ✅ or ⚠️ line, with the
commit or task id, when the job is done:
`✅ 11.1/16 Fixes — job 1/2: ❓ before every question (bb5098b)`. The step's
own ✅ line follows the last job.

Before **every** AskUserQuestion — in any step of preflight, `kix:ship` or
`kix:close`, each one-by-one finding question and each discard-reason question
included — print a ❓ line right before calling the tool:
`❓ <n>/<total> <Step> — <very short summary of what is about to be asked>`
(e.g. `❓ 10/16 Decide — finding 2/6: tally vs split`,
`❓ 13/16 Confirm — ship these 3 commits?`,
`❓ 18/18 Archive — archive this session?`). The step still ends with its ✅ or
⚠️ line; Decide's ✅ line counts each kind of decision (e.g.
`✅ 10/16 Decide — 2 fixes queued, 1 skipped`).

A run that finishes ends with its last step's own line, saying what that step
actually did — `✅ 16/16 Check — 14 commits landed on main (1435da0..a21b626)`,
not a bare `done`.

⚠️ means "don't lose this": anything the user has to do after the run, even
when it blocks nothing and needs no answer now (a question needing an answer
now is ❓). Use it for a run that stopped before its last step, and for any
step result that leaves the user something to do later — a deferred task to
pick up, a branch or worktree to clean, a skill to reinstall, another session
that must ship first. Put it on the step line where it shows up
(`⚠️ 6/16 Related tracker items — dot-a7j done by this branch, close it after the ship`).
Every run that leaves anything pending ends with a ⚠️ block listing each item
and what to do, after the last step's line:

```
⚠️ Stopped at 12/16 Verdict — to do next:
- skim bb5098b..44b795d, then run /kix:ship again
- close dot-a7j after the ship
```

Every step gets its own line, printed as that step ends — even when several
steps end with nothing to say. Never fold them into one summary ("steps 1–6
clear"):

```
✅ 1/16 Rebase — already on main
✅ 2/16 Diff review — 0 findings
⏭️ 3/16 Acceptance criteria — no changes since 2026-10-22T12:01:07Z
✅ 4/16 Conversation leftovers — asks 0 · unanswered 0/0 · deferred 0 · promised 0 · inferred 0
```

Each step runs at least one real command of its own (a grep, a `bd` search, a
`git` call — whatever the step actually needs), and its progress line goes out
right after that command, as its own message. Never put several steps' lines in
one text block: the app shrinks such a block into one summary line.

## 1. Rebase onto the default branch

Before any review, bring the branch up to date, so everything is reviewed on
top of the current `<default>`. Start with one call — it fetches origin and
reads everything below:

```bash
KIX_FETCH_TTL=0 preflight-checks --format tsv
```

On an `uncommitted-changes` finding, commit first (project commit procedure) —
a rebase needs a clean tree. A `fetch` of `failed` means origin was
unreachable: say so, and go on against the `<base>` this clone already has.

**Skip when already on `<default>`.** The rebase is a step of its own, apart
from the commit above: a `behind-default-branch` row of `pass`
(`already on <base>`: `<base>` is an ancestor of HEAD) means nothing would
move. Skip the rebase and the force-push, and end the step with
`✅ 1/<total> Rebase — already on <default>`. The commit of a dirty tree does
not change that answer — it only adds on top of HEAD. Only a `finding` row runs
what follows.

Otherwise rebase onto `<base>` with the `kix:rebase` skill when it is available
— it re-runs the pre-commit hook on every commit; slow, but worth the wait.
Invoke it with a leading `?` (`kix:rebase ? <base>`) to force its interactive
mode whatever the user's configured default: the abort-on-conflict step below
needs the rebase to stop on a conflict, not auto-resolve it. An older
`kix:rebase` (its _Invocation modes_ list no `?` marker) would read the `?` as
part of the branch name: invoke it with just `<default>` then — interactive is
its only default. Without it, `git rebase <base>`. Then
`git push --force-with-lease origin HEAD` (on `<default>` itself there is no
branch push).

If the rebase stops on a conflict, abort it (`git rebase --abort`) and stop
everything: "Before anything else, this branch needs a rebase onto `<default>`,
and it conflicts. Nothing lands until the branch sits on `<default>`."
Resolving the conflict is the user's call.

## 2. Collect findings

Run the seven checks in the main session, before asking anything. No check goes
to an agent: an agent starts without the conversation, and most checks read it
— the code review too, to tell a bug from intended behavior — so an agent
either misses it or pays for a copy of it. A measured run found nothing an
agent caught that the inline run missed, at about three times the tokens.

Open the step with two calls — step 1 may have committed or moved the branch
since its own run:

```bash
preflight-checks start
preflight-checks --no-fetch --format tsv
```

`start` prints `🛫 preflight check started here · <time>`: print that line as
the step's first output, as it is. It is what a check with an `unknown` row
looks for in your context later: the 🛫 line whose time matches the row's
`since <run>` — an earlier run's line, not the one this run just printed.

Then take each markable row in the order of the _Progress_ table (2a–2g:
`diff-review`, `acceptance-criteria`, `conversation-leftovers`,
`open-checkboxes`, `related-tracker-items`, `unraised-follow-ups`,
`post-landing-steps`), by its status:

- **`fresh`** — nothing it reads changed since its marker: don't run it. Its
  open findings are still in the store, and step 3 reads them from there; run
  `preflight-checks findings <name>` as the step's own command and print
  `⏭️ <n>/<total> <Check> — no changes since <at>` (the row's detail), adding
  how many open findings it carries, if any.
- **`skip`** — nothing to look at: print `⏭️ <n>/<total> <Check> — <detail>`
  (e.g. `no unchecked items`), right after the status call. No marker.
- **`stale`, `never` or `unknown`** — read the check's file,
  `${CLAUDE_PLUGIN_ROOT}/skills/preflight/checks/<name>.md` (in a kix-agents
  checkout, `claude-code/skills/preflight/checks/<name>.md`), and run it over
  the row's delta: `stale` reviews only what the detail names, `never` the
  whole branch and session, `unknown` everything since the 🛫 line whose time
  matches the row's `since <run>` — an earlier run's line, not the one this run
  just printed (the file says how); a `stale` row whose detail includes
  `conversation unknown since <run>` reviews its conversation part the same
  way. First resolve its moot open findings, as the file's _Moot findings_
  says. Then mark it right away, before the next check, with its new findings
  on stdin:

  ```bash
  preflight-checks mark <name> <<'JSON'
  [{"category": "…", "file": "…", "line": 12, "summary": "…", "short_summary": "…", "failure_scenario": "…"}]
  JSON
  ```

  `acceptance-criteria` also passes `--bead <id>` (its file says when not).
  Each finding carries the fields step 3 reports — `file` and `line` only when
  it points at one: `category` as the check file gives it, `summary` the
  problem then the fix step 5 will run, fenced so it stands out in one line of
  plain text (line breaks get eaten): `… |—| SUGGESTED FIX: <fix> |—|`, and
  `failure_scenario` what is lost or goes wrong if the branch lands now. No new
  finding → `[]`. Print the check's ✅ line after `mark` (⏭️ when its check
  file says to skip), with its count of new findings (`conversation-leftovers`
  tallies by kind, as its file says).

Marking each check right after it runs means everything later in the run — the
Decide answers, a Fixes commit, the rerun answer — stales the checks that read
it. That is intended: the next run reviews just that delta.

Never write a marker or a finding yourself, and never pass an old finding to
`mark` again: it stays open on its own until something resolves it.

## 3. Report

The list is every open finding on this branch, from the store:

```bash
preflight-checks findings
```

That is the new findings step 2 just marked plus every one still open from
earlier runs — a `fresh` check's carried findings included, and those left for
later. Make **one** ReportFindings call with all of them, `diff-review` first.
It replaces any call the code-review skill made. Per finding, straight from its
JSON:

- `file` / `line`: where it lives — the code, the file with the checklist, or
  the file the conversation item is about. ReportFindings requires `file`, so a
  finding stored without one still gets one here: the branch's spec or plan,
  else the touched file closest to the item. `line` only when it points at one;
- `category`: as the check file gives it — for `diff-review`, the category the
  code review gave; `acceptance`, `conversation`, `checklist`, `tracker`;
  `related`, `idea`, `next-step` or `pitfall` for `unraised-follow-ups`;
  `after-ship` for `post-landing-steps`;
- `summary`: the problem, then the fix, fenced
  (`… |—| SUGGESTED FIX: <fix> |—|`, as step 2 wrote it), then the finding's id
  as metadata at the very end: `… |—| [id: diff-review-1]`. ReportFindings has
  no id field and rejects unknown ones, so the id rides in the summary; step 5
  names it in `resolve`;
- `failure_scenario`: what is lost or goes wrong if the branch lands now.

Then print the same list in chat, complete: the ReportFindings card renders
poorly on mobile (Remote Control), so the chat list must stand on its own —
nothing only the card shows. Per finding:

```
N/T. `<file>:<line>` — <problem> [id: <id>]
   Fix: <suggested fix>
   If left: <failure scenario>
```

Wherever a finding is named — the chat list, a question, a ❓ line, a job's ⏳
or ✅ line — give its number out of the total: `finding 6/9`, `6/9.`.

Zero findings → go to step 6 (Verdict).

## 4. Decide

Walk **every** finding from the report — every check's, `diff-review` and
`post-landing-steps` alike, and those carried from earlier runs — one
AskUserQuestion per finding, one question per call. There is no "apply all"
question first: the first question is finding 1's. Ask **all** of them first,
back to back: an answer only records the decision, nothing runs yet. No fix,
commit, task or `bd update` happens between two questions — step 5 starts only
after the last finding (and its discard reason) is answered, so the user
answers in one sitting and walks away while the queue runs. Before each
question, print the finding in the reply as a short block the user can read and
scroll back to — the card collapses to the chosen label once answered — then
run a command and print the ❓ line, as _Asking questions_ says. Print it as
Markdown, not in a code block, with exactly this shape — a bold heading, then
one labelled bullet per line, never a prose paragraph:

```
**Finding 6/9 — `<file>:<line>`**
- **Problem:** <what goes wrong and when — one line>
- **If left:** <the failure scenario — what breaks, for whom>
- **Fix (recommended):** <the fix> — <why this one over the others>
- **Alt — <other fix>:** <what it does, its trade-off>   (one per extra fix)
- **Note:** <only what is specific to deferring, discarding or leaving this
  finding, e.g. an existing task that already covers it — omit otherwise>
```

**Problem**, **If left** and **Fix** are always there, even under caveman ultra
— caveman shortens each bullet to fragments, it never drops a bullet or merges
them into a paragraph.

The question is one short line pointing at that block — "Finding 6/9 — take the
recommended fix?" — never the finding itself. Options, in this order, each with
its description:

- the suggested fix (Recommended);
- each other real fix, when there is more than one — list them, keep your pick
  first;
- the defer option, by repo type:
  - _(Kingdone)_ "Create arrival" — "Creates an arrival in your inbox (Gates)
    to do this another time; releases the ship after a re-run.";
  - _(Beads)_ "Create task" — "Creates a bd task to do this another time;
    releases the ship after a re-run.";
  - _(Neither)_ no defer option;

  An after-ship finding gets no defer option: its suggested fix already leaves
  it for later, in the task itself;

- "Discard" — "ATTENTION: DISMISSES THE FINDING FOR GOOD AND RELEASES THE SHIP.
  It does not matter; ship anyway. Asks for the reason.";
- "Leave for later" — "Not now, no decision yet. Keeps the finding open, which
  blocks the ship until a later preflight resolves it."

AskUserQuestion takes at most four options: when the fixes, the defer option,
"Discard" and "Leave for later" do not fit, drop the least likely extra fix and
mention it in the block above. "Other" is always there; follow whatever the
user types.

When the user picks "Discard", ask right away, in its own AskUserQuestion, why
— the reason is required. The question is short ("Why discard finding 6/9?");
the finding is already in the block above. Offer 2–3 likely reasons for this
specific finding as options (e.g. "Not a real problem", "Intended behavior",
"Not worth the cost"); "Other" takes free text. Only a discard with a reason
counts: a skipped or empty answer leaves the finding undecided — ask again, or
treat it as "Leave for later".

## 5. Run the queue

Every decision that changes files or the tracker becomes one job. Jobs run
**one at a time**, in order, in the main session: finish one (its commit and
push) before starting the next. Never run two at once — each commits, and a
pre-commit hook may reject a commit while other changes sit unstaged. No job
goes to an agent: the jobs run in sequence anyway, so an agent saves no time,
and it would start without the conversation that explains the fix.

Each job follows these rules, and ends by closing its finding in the store with
`preflight-checks resolve <id> …` — the outcome each rule below names:

- **Fix:** apply it and make one atomic commit for it (project commit procedure
  — `kix:commit` when available), then push the branch. A fix to a bd issue is
  a `bd update` (and `bd dep add` for a link), then `bd dolt push` when the
  repo has a Dolt remote — no commit; the job's ✅ line names the issue id
  instead of a commit. Then `resolve <id> fixed`, only once its commit (or bd
  edit) is in.

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
  source edit together (`docs(gates): add arrival for …`) and push. Then
  `resolve <id> deferred "Gates/<title>"`.

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
  `bd dolt push` when the repo has a Dolt remote, then
  `resolve <id> deferred <task id>`.

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

  Then `resolve <id> deferred <bead id>` (_(Kingdone)_ the quest note's path; a
  ⚠️ line instead, _(Neither)_ included: `deferred "⚠️ block"`).

- **Session title and link** (arrival or task) come from
  `mcp__ccd_session_mgmt__get_session` with `"self"`. When those tools are not
  available (a session started from the phone through a terminal
  `claude remote-control` server), take the title from the conversation and
  write it without a link.

- **Discard:** no job — just `resolve <id> discarded <reason>`, with the reason
  the user gave, when the queue runs.
- **Leave for later:** nothing at all — the finding stays open in the store,
  and the next run reports it again.

After the queue, call ReportFindings again with step 3's list, each finding's
`outcome` read from the `resolve` each job ran, and what is still open from
`preflight-checks findings`: a finding it still returns is open and gets no
`outcome`; one it no longer returns was resolved — `fixed` for a `fixed`,
`skipped` for a `deferred` or `discarded` (after-ship ones included). A
discarded finding's `summary` ends with `|—| DISCARDED: <reason> |—|`. Reprint
the chat list with each finding's result — fixed (with its commit), deferred
(arrival link or task id), discarded — <reason>, or still open.

## 6. Verdict

End every run with exactly one verdict. Callers (`kix:ship`, and `kix:close`
through `kix:ship`) move on only on **clear**. Below, `<command>` is the slash
command of the skill the user started — `/kix:preflight`, `/kix:ship` or
`/kix:close` — even when they started it in plain words.

**Showing the diff.** Give the compare link when the remote is on GitHub, one
link only, always as a labeled Markdown link — for the branch diff
`[<default>...<HEAD short> on GitHub](https://github.com/<owner>/<repo>/compare/<default>...<HEAD sha>)`,
for this run's commits
`[<first short>^..<HEAD short> on GitHub](.../compare/<first commit>^...<HEAD sha>)`,
the caret written as a literal `^`, never `%5E`, so the first commit's own
changes show. It opens anywhere, phone included. The link goes in the reply
itself, never only inside an AskUserQuestion: links do not render in a question
card on mobile. When the remote is not on GitHub, print the range's
`git log --oneline` and `git diff --stat` in the reply instead. Never open the
app's diff pane (`mcp__ccd_view__show_pane`) — it fails more often than not —
and never tell the user a keyboard shortcut.

Read the store's state again first — step 5 may have resolved findings or
committed since step 2's call:

```bash
preflight-checks --no-fetch --format tsv
```

- **Changed** — step 5 committed anything (fixes, arrivals, checklist edits),
  or `unreviewed-bead-changes` reads `finding` or `stale`: a bead changed that
  the user has not reviewed — by a Fix job, by the session's own work or by
  hand; a bd edit commits nothing, but the user has not seen it either — or a
  Fix job edited a tracker item (`bd update`, `bd dep add`), which still counts
  when the row reads `skip` because it can't read the beads DB. The rebase and
  step 1's commit of a dirty tree do not count: step 2 checked them. Show the
  diff of the step 5 commits (above) and name the changed beads from the row's
  detail (else the items the Fix jobs edited) in the reply, then say: "There
  were changes. Review them yourself — skim the diff — and if they look like
  what you expect, rerun." Then ask the rerun question (below). Those commits
  and items are not checked yet; the next run checks them.
- **Open** — the `findings-leftovers` row reads `finding`: its detail lists the
  ids still open (left for later, or never decided). List what is still open,
  show the branch diff (above), then ask the rerun question (below) for when
  the user is ready to decide them.
- **Clear** — `findings-leftovers` reads `pass`, `diff-review` reads `fresh` or
  `skip`, `unreviewed-bead-changes` reads `pass` or `skip`, and step 5
  committed nothing and edited no tracker item. Run
  `preflight-checks bd-mark review` — a clear run counts as the user's review
  of the beads — and say so. When preflight was run on its own, stop here — it
  never ships.
- **Anything else** — neither changed, open nor clear (e.g. `diff-review` is
  not fresh, no finding is open and nothing was committed): treat it as
  **changed**: say so and ask the rerun question (below).

**Rerun.** A link can't run a slash command, but an answer can. After a
**changed** or **open** verdict's ⚠️ block, write what is being asked and each
option in the reply, then follow _Asking questions_: a command, the ❓ line
(e.g. `❓ 12/16 Verdict — rerun /kix:ship?`), then the AskUserQuestion card.
The only link is the compare link the verdict already printed in the reply —
the step 5 commits for **changed**, the branch diff for **open** — never a
second link with a different range, and never inside the question. The question
depends on the verdict:

- **Changed** — the reply says outright that new commits landed that the user
  has not seen: "`<n>` new commits landed since your last look
  (`<first short sha>..<HEAD short sha>`). The next run checks them, but you
  haven't seen them." — naming the changed beads instead of (or next to) the
  commits when `unreviewed-bead-changes` lists any. The question: "Run
  `<command>` again?" Options:
  - "I reviewed — run `<command>` again" (Recommended) — "You skimmed the new
    commits. The rerun checks them again on its own.";
  - "Show me what changed" — "Prints this run's commits and every bead change
    since your last review here, then asks again.";
  - "Run again, skip my review" — "Rerun now without looking. Only the
    automated review checks the new commits.";
  - "Not now" — "Stop. The ⚠️ block stays."

  On "Show me what changed", run
  `preflight-checks diff --from <first step 5 commit> --html <file>` (no
  `--from` when step 5 committed nothing), with `<file>` a new
  `preflight-diff-<time>.html` in your scratchpad directory (else
  `${TMPDIR:-/tmp}`). The page is what the user reads: send it with
  SendUserFile (`display: render`) and give a browser link to it in the reply,
  `[Open the diff in the browser](file://<file>)` — a `file://` URL, not a bare
  path, which the app opens as source. Don't print the text output then; it
  would only repeat the page. Without SendUserFile (a plain terminal), print
  the text output in the reply as it is instead — never a summary of it. Either
  way, repeat its ⚠️ line about other sessions in the reply when it has one.
  Never retype the page's HTML. Then ask the same question again, without this
  option.

- **Open** — nothing new was committed; the reply lists what is still open. The
  question: "Rerun `<command>` to decide them?" Options: "Run `<command>`
  again" (Recommended) · "Not now".

On any run option, rerun `<command>` right away, from its first step, with
fresh progress numbering. On "I reviewed", run
`preflight-checks bd-mark review` first; on "Run again, skip my review", don't
— the unseen bead changes show again next time. On "Run again, skip my review",
the skip goes on record: the rerun's final ⚠️ block (add one if the run would
otherwise end without it) carries
`- <first short sha>..<HEAD short sha> went through without your review — skim it`,
even when that run ships. On "Not now", stop — nothing runs after the answer.

## Common mistakes

- Two ReportFindings lists (one from code-review, one of yours) instead of one.
- A chat list that leaves out what the ReportFindings card shows.
- A one-by-one question with no finding block printed right before it, or with
  the whole finding stuffed into the question text instead.
- A finding block written as a paragraph, or missing its **Problem**, **If
  left** or **Fix** bullet.
- Asking "Apply all" or any other batch question before the first finding —
  Decide always walks the findings one by one.
- One-by-one that skips the `diff-review` findings, or the ones carried from an
  earlier run.
- One-by-one that applies each fix right after its answer (ask, fix, ask, fix)
  instead of asking every question first and running the queue after the last.
- Skipping `unraised-follow-ups`, or padding it with generic advice.
- Doing an after-ship item before the ship, or creating a task, arrival, label
  or heading for it instead of writing it in the current task the way the
  project already does.
- Searching the tracker only by the branch's issue id, or only in the touched
  files.
- Waving through a session that only created or rewrote tracker items because
  there is no diff — those items are its work, and `related-tracker-items`
  reviews each one.
- Running the code review on a session with no diff, or answering a finding on
  a bd issue with a code change instead of a `bd update`.
- Listing only the questions the user left unanswered, not the ones you did.
- Running two queue jobs at once, or bundling several fixes in one commit.
- Calling a run **clear** after it committed anything, or while
  `findings-leftovers` reads `finding`.
- Shipping from here — preflight only gives a verdict.
- Opening the diff pane or telling the user a keyboard shortcut instead of
  giving the compare link.
- Treating "Leave for later" as a discard.
- Discarding without a reason, or inventing one for the user.
- Writing a marker or finding line by hand instead of through
  `preflight-checks`.
- Running a check whose row is `fresh`.
- Reviewing a stale check's whole history instead of its delta.
- Marking the checks all at the end of the run instead of each right after it
  runs, or passing an old open finding to `mark` again.
- Sending a check or a Fixes job to an agent instead of running it in the main
  session.
- Reviewing before the rebase.
- Running `kix:rebase` or the force-push when the `behind-default-branch` row
  reads `pass` — nothing moves, and the hook reruns on every commit for
  nothing.
- Hardcoding `main` instead of the detected default branch.
- Numbering progress per skill (`1/12` inside a `/kix:ship`) instead of across
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
- Answering "I reviewed" without `preflight-checks bd-mark review` first, or
  running it on "Run again, skip my review".
- Summarizing the `preflight-checks diff` output instead of sending its page
  (or, in a plain terminal, printing it), or dropping its ⚠️ line about other
  sessions.
- Showing what changed without `--html`, without sending the page, or with a
  bare-path link (it opens the HTML source) — or printing the text diff next to
  the page, or retyping its HTML into a widget.
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
