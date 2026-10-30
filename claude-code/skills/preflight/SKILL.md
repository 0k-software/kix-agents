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
the language the user is speaking: replies, the findings list, AskUserQuestion
questions and option labels, and the content of every note, task or commit body
you write (labels included — a Portuguese arrival says `Sessão do Claude:`).

**Speed.** Every tool call costs a model turn. Send independent calls together
in one message — the diff and the files around its hunks, caller greps, test
runs, lookups during a check, a Fix job's edits to several files. Print no
progress lines: no step numbers, no per-step ✅, ⏭️, ❓ or ⏳ lines.

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

## preflight-checks

`preflight-checks` (on PATH from the kix plugin's `bin/`; else
`claude-code/bin/preflight-checks` in a kix-agents checkout) does everything
that needs no judgement, and keeps each check's markers and findings in a
per-session store that only it writes — never edit its files. `--help` lists
every row and subcommand. What preflight uses:

- `preflight-checks start --format tsv [--bead <id>]` — **the brief.** Opens a
  run (its `🛫 preflight check started here · <time>` line), prints the rows
  below, then one `## <check> · <status> · <detail>` section per check that
  needs running: the check's instructions and a **Data:** list — the range and
  files, the bead's acceptance, design or notes, candidate findings, bd
  updates, the prompts since the check's marker, and its open findings. `<id>`
  is the branch's bead (an id in the branch name, the issue claimed or worked
  on in this session, or one the conversation names); without it, both calls
  use an id in the branch name. No bead: drop `--bead` here and in
  `mark --batch`.
- `preflight-checks mark --batch [--bead <id>] <<'JSON' … JSON` — records that
  the checks ran, all at once:
  `{"<check>": [<new findings>], …, "resolve": [["<id>", "fixed"], ["<id>", "discarded", "obsolete: <why>"]]}`.
  It checks everything before writing anything, then prints every open finding
  of the branch as one JSON array.
- `preflight-checks resolve <id> fixed [<commit>] | deferred <ref> | discarded <reason…>`
  — closes a finding. Pass a Fix job's commit (`HEAD` right after it): its
  commit then stales only `diff-review`.
- `preflight-checks findings` — the branch's open findings, as JSON.
- `preflight-checks --no-fetch --format tsv [--diff-html <file> [--from <sha>]]`
  — the rows alone; with `--diff-html`, it also writes the diff page
  (_Verdict_) and adds a `diff-page` row (the file, else `-`) and a `diff-url`
  row (its url in the user's shared folder, else `-`).
- `preflight-checks bd-mark review` and
  `preflight-checks diff [--from <sha>] [--html <file>]` — _Verdict_. `--html`
  writes the same as a page: the commits in full, and the changed words inside
  each changed line highlighted, like GitHub's diff.

The rows, one `<name> <status> <detail>` line each:

| Row                                                              | Status                                  | Says                                                                                                                                                                                    |
| ---------------------------------------------------------------- | --------------------------------------- | --------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| `default`, `from`, `shortstat`, `markdown`, `fetch`              | fact                                    | `<base>` (e.g. `origin/main`), diff-review's last head, …                                                                                                                               |
| `uncommitted-changes`                                            | pass · finding                          | uncommitted changes                                                                                                                                                                     |
| `unlanded-commits`                                               | pass · finding · skip                   | commits not on `<base>`                                                                                                                                                                 |
| `behind-default-branch`                                          | pass · finding · skip                   | `<base>` is not an ancestor of HEAD                                                                                                                                                     |
| the seven checks, from `open-checkboxes` to `post-landing-steps` | fresh · stale · never · unknown · skip  | the check's marker against what the check reads                                                                                                                                         |
| `findings-leftovers`                                             | pass · finding                          | open findings on this branch: their ids                                                                                                                                                 |
| `unreviewed-bead-changes`                                        | pass · finding · stale · unknown · skip | beads this session wrote with bd, and their deps, changed since the user's last review: their ids; other sessions' changes only as a "not shown" count (all beads without a transcript) |

A check is `fresh` when nothing it reads changed since its marker, `stale` with
what changed, `never` without a marker, `unknown` when its marker can't tell
(no transcript to read), `skip` when there is nothing to look at. Each check
watches only its own inputs — a Fix commit stales only `diff-review`, a bd
update only `related-tracker-items`, a new prompt only the conversation checks.

**Default branch.** Never assume `main`: `<base>` is the `default` row (e.g.
`origin/main`) and `<default>` is the branch name without `origin/`.

A marker records only that the check ran and what it saw; the approval is the
user's "Ship" answer in `kix:ship`. A finding stays open until something
resolves it, so nothing needs passing back to carry it to the next run.

**Links** never go inside a question card: a link there cannot be opened on
mobile — with one exception, the **changed** verdict's `diff-url` (_Verdict_).

**Pending items.** A run that leaves the user anything to do — a deferred task
to pick up, an item to close after the ship, a range that went through without
their review, a run that stopped early — ends with a ⚠️ block listing each item
and what to do:

```
⚠️ To do next:
- skim bb5098b..44b795d, then run /kix:ship again
- close dot-a7j after the ship
```

## 1. Rebase onto the default branch

Before any review, bring the branch up to date, so everything is reviewed on
top of the current `<default>`. One call fetches origin and prints the brief:

```bash
KIX_FETCH_TTL=0 preflight-checks start --format tsv --bead <id>
```

A `fetch` of `failed` means origin was unreachable: say so, and go on against
the `<base>` this clone already has. When `uncommitted-changes` reads `pass`
and `behind-default-branch` reads `pass` (`already on <base>`), nothing moves:
the brief is current — go to step 2.

Otherwise, on an `uncommitted-changes` finding, commit first (project commit
procedure) — a rebase needs a clean tree. On a `behind-default-branch` finding,
rebase onto `<base>` with the `kix:rebase` skill when it is available — it
re-runs the pre-commit hook on every commit; slow, but worth the wait. Invoke
it with a leading `?` (`kix:rebase ? <base>`) to force its interactive mode
whatever the user's configured default: the abort-on-conflict step below needs
the rebase to stop on a conflict, not auto-resolve it. An older `kix:rebase`
(its _Invocation modes_ list no `?` marker) would read the `?` as part of the
branch name: invoke it with just `<default>` then. Without it,
`git rebase <base>`. Then `git push --force-with-lease origin HEAD` (on
`<default>` itself there is no branch push). Never rebase when
`behind-default-branch` reads `pass` — the commit of a dirty tree only adds on
top of HEAD.

If the rebase stops on a conflict, abort it (`git rebase --abort`) and stop
everything: "Before anything else, this branch needs a rebase onto `<default>`,
and it conflicts. Nothing lands until the branch sits on `<default>`."
Resolving the conflict is the user's call.

After a commit or a rebase, print a new brief — the first one saw the old HEAD:

```bash
preflight-checks start --no-fetch --format tsv --bead <id>
```

## 2. Run the checks

The brief's sections are the work: one per check that is `stale`, `never` or
`unknown`. A check with no section is `fresh` or `skip`, or the brief marked it
itself (`marked by start: …`): don't run it, its open findings stay in the
store. Run the sections in the main session, before asking anything. No check
goes to an agent: most read the conversation — the code review too, to tell a
bug from intended behavior — and an agent either misses it or pays for a copy.

For each section, follow its instructions over its **Data:**, and only over the
delta its header names: `stale` reviews what changed since its marker, `never`
the whole branch and session, `unknown` everything since the 🛫 line whose time
its data names — an earlier run's line, not this run's (no such line, the
context was compacted: the whole session, and say so). Gather what the data
doesn't give in parallel calls.

`diff-review`'s section is a Skill call: load `code-review` at level `medium`
on its range, and take its findings as they come. Reading the diff yourself is
not the review — a short diff included.

**Moot findings.** A section's data lists the check's open findings
(`- open: <id> — …`). When the delta settled one — fixed by hand, or the user
said "never mind" — resolve it in the batch: `["<id>", "fixed"]`, or
`["<id>", "discarded", "obsolete: <why>"]`. No other outcome; leave the rest
open, and never put an old finding in the batch again.

Then mark every section's check in **one** call — a check with nothing new gets
`[]`, and a check with no section never goes in:

```bash
preflight-checks mark --batch --bead <id> <<'JSON'
{"diff-review": [{"category": "…", "file": "…", "line": 12, "summary": "… |—| SUGGESTED FIX: <fix> |—|", "short_summary": "…", "failure_scenario": "…"}],
 "open-checkboxes": [],
 "resolve": [["conversation-leftovers-2", "fixed"]]}
JSON
```

Each finding: `category` as the check gives it; `file` and `line` only when it
points at one; `summary` the problem, then the fix step 5 will run, fenced so
it stands out in one line of plain text (`… |—| SUGGESTED FIX: <fix> |—|`);
`failure_scenario` what is lost or goes wrong if the branch lands now.
`open-checkboxes`' data gives its candidates ready to paste: keep the real
ones, fill in their fix and failure, drop the rest.

## 3. Report

The list is the JSON `mark --batch` printed: every open finding on this branch,
new and carried. When the brief had no section (nothing to mark), read it with
`preflight-checks findings`. Print them in chat, `diff-review` first, straight
from their JSON — the chat list is the only view; no ReportFindings call of
your own (it renders poorly on mobile, and the store already holds everything):

```
N/T. `<file>:<line>` — <problem> [id: <id>]
   Fix: <suggested fix>
   If left: <failure scenario>
```

`<file>:<line>` only as far as the finding has them; with no `file`, the line
reads `N/T. <problem> [id: <id>]`. The problem and fix come from `summary` (the
fix inside its `SUGGESTED FIX` fence), the failure scenario from
`failure_scenario`; the id is what step 5 names in `resolve`.

Wherever a finding is named — the chat list, a question, a job — give its
number out of the total: `finding 6/9`, `6/9.`.

Zero findings → go to step 6 (Verdict).

## 4. Decide

Walk **every** finding from the report — every check's, `diff-review` and
`post-landing-steps` alike, and those carried from earlier runs — one question
per finding, asked in batches: one AskUserQuestion call holds up to four
questions, one per finding (findings 1–4, then 5–8, …). There is no "apply all"
question first: the first card holds finding 1's question. Ask **all** batches
first, back to back: an answer only records the decision, nothing runs yet. No
fix, commit, task or `bd update` happens between two batches — step 5 starts
only after the last batch (and its discard reasons) is answered, so the user
answers in one sitting and walks away while the queue runs.

Before each batch, print every finding of that batch in the reply, one block
after another, in one message — the card collapses to the chosen labels once
answered, and the blocks stay to scroll back to — then the card, right after
it. Nothing goes between the blocks and the card: one batch is one text, one
card. Print each block as Markdown, not in a code block, with exactly this
shape — a bold heading, then one labelled bullet per line, never a prose
paragraph:

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

Each question is one short line pointing at its block — "Finding 6/9 — take the
recommended fix?" — never the finding itself; its `header` is `Finding 6/9`.
Options, in this order, each with its description:

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

When the user picks "Discard" for any finding of a batch, ask why right after
that batch, before the next one — the reason is required. One AskUserQuestion
holds every discard of the batch, one question each, short ("Why discard
finding 6/9?"); the findings are already in the blocks above. Offer 2–3 likely
reasons for each specific finding as options (e.g. "Not a real problem",
"Intended behavior", "Not worth the cost"); "Other" takes free text. Only a
discard with a reason counts: a skipped or empty answer leaves the finding
undecided — ask again, or treat it as "Leave for later".

## 5. Run the queue

Every decision that changes files or the tracker becomes one job. Jobs run
**one at a time**, in order, in the main session: finish one (its commit)
before starting the next — each commits, and a pre-commit hook may reject a
commit while other changes sit unstaged. No job goes to an agent: it would
start without the conversation that explains the fix.

A job is two steps: its edits, all in one message (several files at once), then
**one** Bash call that commits and closes the finding — the pre-commit hook
runs the project's checks (a repo without one: put its check command first,
e.g. `make check &&`). Each job ends by closing its finding with the outcome
its rule names:

- **Fix:** one atomic commit, message in the project's style:

  ```bash
  git add <files> && git commit -m "<message>" && preflight-checks resolve <id> fixed HEAD
  ```

  A fix to a bd issue is a `bd update` (and `bd dep add` for a link) — no
  commit: `bd update … && preflight-checks resolve <id> fixed`.

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
  source edit together (`docs(gates): add arrival for …`), then
  `resolve <id> deferred "Gates/<title>"`.

- _(Beads)_ **Create task:** find the current work first — the issue the branch
  is about: an id in the branch name, the issue claimed or worked on in this
  session, or one the conversation names. If none is identifiable, create the
  task unrelated and say so. Then:

  ```bash
  t=$(bd create --type=task --priority=2 --silent \
    --title="<Imperative verb and what to do>" \
    --description="Claude session: [<session title>](<session link>)
  Source: <file>:<line>

  <Two or three lines of context: what was left and why.>" \
    <relation>) && preflight-checks resolve <id> deferred "$t" && echo "$t"
  ```

  `<relation>` is `--parent=<id>` when the current work is an epic, otherwise
  `--deps=discovered-from:<id>`; leave it out when there is none. When the
  finding is a checklist item, mark it `[-]` with `→ task created: <task id>`
  at its end and commit that edit (one commit).

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
    when that is where the project keeps them. No identifiable current issue →
    do not write it anywhere; the finding becomes a ⚠️ line in the closing ⚠️
    block, and say so.
  - _(Kingdone)_ the current quest's main note; commit it.

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

After the last job, one call pushes and reads the state for step 6:

```bash
git push --force-with-lease origin HEAD; bd dolt push; preflight-checks --no-fetch --format tsv --diff-html <file> [--from <first step 5 commit>]; preflight-checks findings
```

(`bd dolt push` only when a job touched the tracker and the repo has a Dolt
remote; no branch push on `<default>` itself. `<file>` is a new
`preflight-diff-<time>.html` in your scratchpad directory, else
`${TMPDIR:-/tmp}`; `--from` only when a job committed. The `diff-page` row
names the file when the call wrote it — the step 5 commits in full and every
unreviewed bead change, the changed words highlighted — else `-`. When the user
has a shared folder (`KIX_SHARE_DIR` and `KIX_SHARE_URL`, from the environment
or `~/.config/kix/config`: a folder served to their own devices), the page goes
there instead and the `diff-url` row is its url, else `-`.) Then reprint step
3's chat list with each finding's result, read from that `findings` output (a
finding it still returns is still open) — fixed (with its commit), deferred
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

Read the rows from step 5's last call. When step 5 ran no job, read them in one
call that also runs its discards:
`preflight-checks resolve <id> discarded <reason>; …; preflight-checks --no-fetch --format tsv --diff-html <file>`
— step 2's batch changed them since the brief, and the call writes the diff
page when a bead is unreviewed.

- **Changed** — step 5 committed anything (fixes, arrivals, checklist edits),
  or `unreviewed-bead-changes` reads `finding` or `stale`: a bead changed that
  the user has not reviewed — by a Fix job, by the session's own work or by
  hand; a bd edit commits nothing, but the user has not seen it either — or a
  Fix job edited a tracker item (`bd update`, `bd dep add`), which still counts
  when the row reads `skip` because it can't read the beads DB. The rebase and
  step 1's commit of a dirty tree do not count: step 2 checked them. Link the
  diff page right away, on the reply's first line, saying what it is:
  `[Diff page — the commits and bead changes to review](<url>)`. When
  `diff-url` is not `-`, `<url>` is that url — it opens on every device of
  theirs, so publish nothing; with the built-in browser
  (`mcp__Claude_Browser__*`), also open it in a background tab: `tabs_create`,
  then `navigate` with its `tabId` (when `tabs_create` fails because the pane
  is not open, `navigate` alone opens it without bringing it to the front). The
  desktop app then shows a preview card of the page, which never replaces the
  link — the phone has no card. Otherwise publish the `diff-page` file first,
  before any reply text, with the Artifact tool (`file_path: "<file>"`,
  `icon: "diff"`, `description`: "The commits and bead changes to review before
  the rerun"), and `<url>` is its `url`: a private claude.ai page, which opens
  on the phone too. Publish on every changed verdict, reruns included: each
  writes a new page. Without the Artifact tool, send the file with SendUserFile
  (`display: "render"`, `status: "normal"`, a `caption` saying what it is);
  without either, print its path. Never put a `file://` link in the reply: text
  holding one never reaches the user. Don't read the page (`cat`, Read) — it is
  for the user — and print no diff text: the page is the diff. A question, or
  the end of the turn, before the page is linked is held back by the
  `diff-link-gate.sh` hook, at most twice. When `diff-page` is `-` (the beads
  DB can't be read), show the diff of the step 5 commits (above) and name the
  items the Fix jobs edited instead. Then say: "There were changes. Review them
  yourself — skim the diff — and if they look like what you expect, rerun."
  Then ask the rerun question (below). Those commits and items are not checked
  yet; the next run checks them.
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

**Rerun without asking.** A **changed** verdict whose only changes are step 5's
Fix jobs — each one a fix the user picked from the offered options, not text
they typed under "Other", and no bead changed but by those jobs — reruns
`<command>` right away, without the rerun question: link the diff page as
**Changed** says, say in one line that it reruns to review the fix commits, and
go. Only once in a row: when that rerun ends **changed** again, ask. No
`bd-mark review` here — the user has not looked.

**Rerun.** A link can't run a slash command, but an answer can. After a
**changed** or **open** verdict's ⚠️ block, write what is being asked and each
option in the reply, then the AskUserQuestion card. The only link is the one
the verdict already printed in the reply — the branch diff for **open**, and
for **changed** the diff page's link (else the step 5 commits' compare link) —
never a second link with a different range, and never inside the question, with
one exception: a **changed** verdict's `diff-url` also goes in the question
text, as a bare url. The app may fold the reply text above a question card out
of sight, and the card is what the user always sees. The question depends on
the verdict:

- **Changed** — the reply says outright that new commits landed that the user
  has not seen: "`<n>` new commits landed since your last look
  (`<first short sha>..<HEAD short sha>`). The next run checks them, but you
  haven't seen them." — naming the changed beads instead of (or next to) the
  commits when `unreviewed-bead-changes` lists any. The question: "Run
  `<command>` again?", and, when `diff-url` is not `-`, "Diff page:
  `<diff-url>`" after it on the same line. Options:
  - "I reviewed — run `<command>` again" (Recommended) — "You skimmed the diff.
    The rerun checks it again on its own.";
  - "Run again, skip my review" — "Rerun now without looking. Only the
    automated review checks the new commits.";
  - "Not now" — "Stop. The ⚠️ block stays."

- **Open** — nothing new was committed; the reply lists what is still open. The
  question: "Rerun `<command>` to decide them?" Options: "Run `<command>`
  again" (Recommended) · "Not now".

On any run option, rerun `<command>` right away, from its first step. On "I
reviewed", run `preflight-checks bd-mark review` first; on "Run again, skip my
review", don't — the unseen bead changes show again next time. On "Run again,
skip my review", the skip goes on record: the rerun's final ⚠️ block (add one
if the run would otherwise end without it) carries
`- <first short sha>..<HEAD short sha> went through without your review — skim it`,
even when that run ships. On "Not now", stop — nothing runs after the answer.

## Common mistakes

- Running a check the brief gave no section, or reading a check file the brief
  already printed.
- Marking checks one by one, or a fresh check at all, or passing an old open
  finding to `mark` again.
- Reviewing a stale check's whole history instead of its delta.
- One tool call per lookup when they could go out together; a Fix job split
  into edit, test, commit and resolve calls; a push after every job.
- Printing progress lines.
- A ReportFindings call of your own — the chat list is the only view — or a
  chat list that leaves out a finding's fix, failure scenario or id.
- A Decide card whose findings' blocks were not all printed right before it, or
  with a finding stuffed into the question text; a block written as a
  paragraph, or missing its **Problem**, **If left** or **Fix** bullet.
- One finding per card, or text, commands and cards interleaved within a batch,
  instead of all of a batch's blocks, then one card of up to four questions.
- Asking "Apply all" or any other question that decides several findings at
  once — every finding gets its own question.
- A Decide that skips the `diff-review` findings or the carried ones, or that
  applies each fix right after its answer instead of asking every batch first.
- Doing an after-ship item before the ship, or creating a task, arrival, label
  or heading for it instead of writing it in the current task.
- Answering a finding on a bd issue with a code change instead of a
  `bd update`.
- Running two queue jobs at once, or bundling several fixes in one commit.
- Calling a run **clear** after it committed anything, or while
  `findings-leftovers` reads `finding`; shipping from here.
- Rerunning without asking after a fix the user typed under "Other", or twice
  in a row.
- Sending a check or a Fix job to an agent.
- Reviewing the diff yourself instead of loading `code-review` for
  `diff-review`.
- Reviewing before the rebase, or rebasing when `behind-default-branch` reads
  `pass`.
- Hardcoding `main` instead of the detected default branch.
- Opening the diff pane or telling the user a keyboard shortcut instead of the
  compare link.
- Treating "Leave for later" as a discard; discarding without a reason, or
  inventing one.
- Ending a **changed**, **open** or ship _Gate_ stop with only a text "run it
  again" instead of the rerun question.
- Answering "I reviewed" without `preflight-checks bd-mark review` first, or
  running it on "Run again, skip my review" or a rerun without asking.
- A **changed** verdict that doesn't link the `diff-url`, else publish the
  `diff-page` file as an Artifact and link its url, saying what it is, before
  any question, or that leaves the `diff-url` out of the rerun question — or
  that publishes it when `diff-url` is set, or that links it as `file://` (that
  text never reaches the user), reads the page, prints the diff as text, or
  retypes its HTML.
- A **changed** rerun reply that doesn't say new, unseen commits landed, or
  that offers only "I reviewed", or dropping the "without your review" ⚠️ item
  after "Run again, skip my review".
- Ending a run with pending items but no ⚠️ block.
- Offering a defer option in a repo that has no inbox, or Kingdone conventions
  (Gates, `R\$`) outside a Kingdone repo.
- Naming an arrival without linking it, or a task without its id; leaving the
  source checklist item without a pointer back.
- Writing in English to a user who speaks Portuguese.
