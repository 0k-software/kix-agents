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
the language the user is speaking: replies, the findings, the questions and
their answer words, and the content of every note, task or commit body you
write (labels included — a Portuguese arrival says `Sessão do Claude:`).

**Questions** are plain text at the end of the reply, never AskUserQuestion: a
bold question, then each answer as a bullet (`- **<word>** — <what it does>`),
the recommended one first, marked `(recommended)` after its word, then the turn
ends. The user answers in their own words, several questions in one message,
with comments; read the answer for meaning.

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
whatever the user's configured default: a conflict is the user's call, so the
rebase asks them about each one (keep mine, keep theirs, keep both) instead of
resolving it on its own. An older `kix:rebase` (its _Invocation modes_ list no
`?` marker) would read the `?` as part of the branch name: invoke it with just
`<default>` then. Without it, `git rebase <base>`. Then push the branch (on
`<default>` itself there is no branch push). Only a branch origin already has
needs a force — the rebase rewrote the commits it holds; a branch that was
never pushed gets a plain first push:

```bash
if git ls-remote --exit-code --heads origin "$(git branch --show-current)" >/dev/null; then
  git push --force-with-lease origin HEAD
else
  git push -u origin HEAD
fi
```

Never force anywhere else: every other push only adds commits on top. Never
rebase when `behind-default-branch` reads `pass` — the commit of a dirty tree
only adds on top of HEAD.

A rebase that went through on its own (no conflict) needs no word to the user:
`<default>`'s new commits are not theirs to review, and the checks don't count
them — a commit whose patch came through unchanged keeps its marker (kxa-xsh).
Only a commit a conflict resolution rewrote stales them. If the user stops the
rebase at a conflict question, abort it (`git rebase --abort`) and stop
everything: "Before anything else, this branch needs a rebase onto `<default>`,
and it conflicts. Nothing lands until the branch sits on `<default>`." Without
`kix:rebase`, a plain `git rebase` that stops on a conflict ends the same way.

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
your own (it renders poorly on mobile, and the store already holds everything).
Each finding is one block, printed once — never a one-line `N/T.` list as well.
Print each block as Markdown, not in a code block, with exactly this shape — a
bold heading, a blank line, then one labelled bullet per line, never a prose
paragraph:

```
**Finding 6/9 — `<file>:<line>`**

- **Problem:** <what goes wrong and when — one line>
- **If left:** <the failure scenario — what breaks, for whom>
- **Fix (recommended):** <the fix> — <why this one over the others>
- **Fix — <other fix>:** <what it does, its trade-off>   (one per other fix)
- **Note:** <only what is specific to deferring, discarding or leaving this
  finding, e.g. an existing task that already covers it — omit otherwise>
```

`<file>:<line>` only as far as the finding has them; with no `file`, the
heading reads `**Finding 6/9**`. The problem and fix come from `summary` (the
fix inside its `SUGGESTED FIX` fence), **If left** from `failure_scenario`;
keep each finding's id from the JSON for step 5's `resolve`, without printing
it. List every real fix you see, not only the suggested one: the recommended
first, labelled so, then each other one with its trade-off. **Problem**, **If
left** and **Fix** are always there, even under caveman ultra — caveman
shortens each bullet to fragments, it never drops a bullet or merges them into
a paragraph.

Wherever a finding is named — a block, a question, a job — give its number out
of the total: `finding 6/9`.

Zero findings → go to step 6 (Verdict).

## 4. Decide

**Every** finding from the report — every check's, `diff-review` and
`post-landing-steps` alike, and those carried from earlier runs — needs the
user's decision, all asked at once: the blocks, then one request at the end of
the same reply, then the turn ends. Nothing runs before the answer, so the user
answers in one sitting and walks away while the queue runs:

```
**Please review the findings and tell me what to do with each.** Take a fix —
the recommended one or another — or describe your own. It's fine to postpone
any of them (<defer>, or just leave it open) or to discard it; a discard needs
a short reason why.
```

`<defer>` goes by repo type: _(Beads)_ "as a bd task"; _(Kingdone)_ "as an
arrival in your inbox"; _(Neither)_ drop it, leaving "just leave it open". An
after-ship finding is never deferred to a task — its suggested fix already
leaves it for later, in the task itself — and its **Note** says so.

Read the answer for meaning: "fix all but 3", "3 is intended" (a discard with
its reason), a comment that changes a fix. A fix the user describes in their
own words is theirs: follow it. Each finding ends with one decision — a fix, a
defer (task or arrival), a discard with its reason, or **later** (left open,
which blocks the ship until a later preflight resolves it). Before step 5: when
the answer leaves findings out, is unclear about one, or discards one without a
reason, ask again in one short question naming just those, asking for the
reason where it is missing, and end the turn. Never assume a decision or invent
a reason: **later** only when the user says so, or says to leave the rest.

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
- **Later:** nothing at all — the finding stays open in the store, and the next
  run reports it again.

After the last job, one call pushes and reads the state for step 6:

```bash
git push -u origin HEAD; bd dolt push; preflight-checks --no-fetch --format tsv --diff-html <file> [--from <first step 5 commit>]; preflight-checks findings
```

(`bd dolt push` only when a job touched the tracker and the repo has a Dolt
remote; no branch push on `<default>` itself. `<file>` is a new
`preflight-diff-<time>.html` in your scratchpad directory, else
`${TMPDIR:-/tmp}`; `--from` only when a job committed. The `diff-page` row
names the file when the call wrote it — the step 5 commits in full and every
unreviewed bead change, the changed words highlighted — else `-`. When the user
has a shared folder (`KIX_SHARE_DIR` and `KIX_SHARE_URL`, from the environment
or `~/.config/kix/config`: a folder served to their own devices), the page goes
there instead and the `diff-url` row is its url, else `-`.) Then print one line
per finding with its result, read from that `findings` output (a finding it
still returns is still open) —
``6/9 `<file>:<line>` — <short summary>: <result>``, the result being fixed
(with its commit), deferred (arrival link or task id), discarded — <reason>, or
still open.

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
changes show. It opens anywhere, phone included. When the remote is not on
GitHub, print the range's `git log --oneline` and `git diff --stat` in the
reply instead. Never open the app's diff pane (`mcp__ccd_view__show_pane`) — it
fails more often than not — and never tell the user a keyboard shortcut.

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
  for the user — and print no diff text: the page is the diff. The end of the
  turn (a question included) before the page is linked is held back by the
  `diff-link-gate.sh` hook, at most twice. When `diff-page` is `-` (the beads
  DB can't be read), show the diff of the step 5 commits (above) and name the
  items the Fix jobs edited instead. Then say: "There were changes. Review them
  yourself — skim the diff — and if they look like what you expect, rerun."
  Then ask the rerun question (below). Those commits and items are not checked
  yet; the next run checks them.
- **Open** — the `findings-leftovers` row reads `finding`: its detail lists the
  ids still open (left for **later**, or never decided). List what is still
  open, show the branch diff (above), then ask the rerun question (below) for
  when the user is ready to decide them.
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
Fix jobs — each one a fix from the block the user picked, not a fix they
described in their own words, and no bead changed but by those jobs — reruns
`<command>` right away, without the rerun question: link the diff page as
**Changed** says, say in one line that it reruns to review the fix commits, and
go. Only once in a row: when that rerun ends **changed** again, ask. No
`bd-mark review` here — the user has not looked.

**Rerun.** A link can't run a slash command, but an answer can. After a
**changed** or **open** verdict's ⚠️ block, ask the rerun question at the end
of the reply (_Questions_). The only link is the one the verdict already
printed — the branch diff for **open**, and for **changed** the diff page's
link (else the step 5 commits' compare link) — never a second link with a
different range. The question depends on the verdict:

- **Changed** — the reply says outright that new commits landed that the user
  has not seen: "`<n>` new commits landed since your last look
  (`<first short sha>..<HEAD short sha>`). The next run checks them, but you
  haven't seen them." — naming the changed beads instead of (or next to) the
  commits when `unreviewed-bead-changes` lists any. Then:

  ```
  **Run `<command>` again?**

  - **reviewed** — you skimmed the diff; the rerun checks it again on its own.
  - **skip review** — rerun now without looking; only the automated review checks the new commits.
  - **not now** — stop; the ⚠️ block stays.
  ```

- **Open** — nothing new was committed; the reply lists what is still open. The
  question: "**Rerun `<command>` to decide them?**" — **rerun** · **not now**.

On a rerun answer, rerun `<command>` right away, from its first step. On
**reviewed**, run `preflight-checks bd-mark review` first; on **skip review**,
don't — the unseen bead changes show again next time. On **skip review**, the
skip goes on record: the rerun's final ⚠️ block (add one if the run would
otherwise end without it) carries
`- <first short sha>..<HEAD short sha> went through without your review — skim it`,
even when that run ships. On **not now**, stop — nothing runs after the answer.
An answer that is none of these (a question, a new request): handle it, then
ask again.

## Common mistakes

- Running a check the brief gave no section, or reading a check file the brief
  already printed.
- Marking checks one by one, or a fresh check at all, or passing an old open
  finding to `mark` again.
- Reviewing a stale check's whole history instead of its delta.
- One tool call per lookup when they could go out together; a Fix job split
  into edit, test, commit and resolve calls; a push after every job.
- Printing progress lines.
- A ReportFindings call of your own — the blocks are the only view.
- A one-line `N/T.` findings list, or the list and the blocks both; a block
  written as a paragraph, or missing its **Problem**, **If left** or **Fix**
  bullet.
- An AskUserQuestion call anywhere in the run, or a Decide split into batches
  or one question per finding instead of one plain-text question after all the
  blocks.
- A Decide that skips the `diff-review` findings or the carried ones, that
  assumes a decision the answer left out, or that starts the queue before every
  finding has one.
- Doing an after-ship item before the ship, or creating a task, arrival, label
  or heading for it instead of writing it in the current task.
- Answering a finding on a bd issue with a code change instead of a
  `bd update`.
- Running two queue jobs at once, or bundling several fixes in one commit.
- Calling a run **clear** after it committed anything, or while
  `findings-leftovers` reads `finding`; shipping from here.
- Rerunning without asking after a fix the user described in their own words,
  or twice in a row.
- Sending a check or a Fix job to an agent.
- Reviewing the diff yourself instead of loading `code-review` for
  `diff-review`.
- A force push anywhere but right after a rebase of a branch origin already
  has.
- Reviewing before the rebase, or rebasing when `behind-default-branch` reads
  `pass`.
- Hardcoding `main` instead of the detected default branch.
- Opening the diff pane or telling the user a keyboard shortcut instead of the
  compare link.
- Treating **later** as a discard; discarding without a reason, or inventing
  one.
- Ending a **changed**, **open** or ship _Gate_ stop with only a text "run it
  again" instead of the rerun question.
- Answering **reviewed** without `preflight-checks bd-mark review` first, or
  running it on **skip review** or a rerun without asking.
- A **changed** verdict that doesn't link the `diff-url`, else publish the
  `diff-page` file as an Artifact and link its url, saying what it is, before
  any question — or that publishes it when `diff-url` is set, or that links it
  as `file://` (that text never reaches the user), reads the page, prints the
  diff as text, or retypes its HTML.
- A **changed** rerun reply that doesn't say new, unseen commits landed, or
  that offers only **reviewed**, or dropping the "without your review" ⚠️ item
  after **skip review**.
- Ending a run with pending items but no ⚠️ block.
- Offering a defer option in a repo that has no inbox, or Kingdone conventions
  (Gates, `R\$`) outside a Kingdone repo.
- Naming an arrival without linking it, or a task without its id; leaving the
  source checklist item without a pointer back.
- Writing in English to a user who speaks Portuguese.
