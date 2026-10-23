# kxa-102 — Check library: standalone checks with markers

Design agreed with kelvin on 2026-10-22. Parent epic: kxa-5l3 (its design field
has the stages/gates/actions picture this fits into).

## Why

`kix:preflight` runs six judgment checks plus a handful of git tests every
time, and the only thing that lets it skip work is one git note per commit
("checked <session>"), which says nothing about the conversation, the tracker
or which findings are still open. Carried-over findings live only in the
model's memory of its last ReportFindings call. The result: a second preflight
in the same session redoes most of the work, and what it skips or carries
depends on what the model remembers.

This bead splits the checks into a library of standalone checks. Each check
knows when it applies (has anything to look at) and what makes it stale, and
writes a deterministic marker after it runs. A check whose marker is fresh is
skipped and its open findings are carried from disk, not from memory. A stale
check reviews only the delta since its marker.

Example: a session that only filed beads has no commits, so `diff-review` does
not apply and costs nothing, while `conversation-leftovers` still runs.

## Goals

- One library of named checks, each runnable on its own, each reporting `fresh`
  / `stale` / `never` / `unknown` (or not applicable) from its marker.
- Markers and findings saved on disk by a script, never written or remembered
  by the model.
- `kix:preflight` rewired now to run through the library. kxa-efc (gate runner,
  `/check`) later replaces preflight's loop; this bead does not build gates.
- Git notes (`refs/notes/checks`) retired.

## Non-goals

- No gate runner, no `/check` command, no stage display, no per-gate config
  (kxa-efc, kxa-89c).
- No Stop hook running checks after every turn (kxa-v9v).
- No narrowing of tracker candidates by touched paths (kxa-6nb).
- No rename of the script (`preflight-checks` stays; kxa-efc may rename it).
- `post-landing-steps` naming and the `Before shipping:` bead paragraph are
  another bead's business (kxa-00b, kxa-dfo).

## Anti-goals

- The model copying ids, timestamps or SHAs into a marker by hand.
- A check marked fresh when something it reads changed (a missed commit, a
  missed user turn).
- A fix (resolving a finding) that also marks new commits or turns as reviewed.

## The checks

Names say what is checked. Deterministic checks are `cp_*` functions in
`claude-code/bin/preflight-checks` and always rerun (milliseconds). LLM checks
get one instruction file each in
`claude-code/skills/preflight/checks/<name>.md` — preflight reads only the
files of checks it runs.

| Check                    | Kind                       | Applies when                                  | Stale when                                                                   | Today                       |
| ------------------------ | -------------------------- | --------------------------------------------- | ---------------------------------------------------------------------------- | --------------------------- |
| `uncommitted-changes`    | script                     | always                                        | always rerun                                                                 | `dirty-tree`                |
| `unlanded-commits`       | script                     | a default branch is found                     | always rerun                                                                 | `unlanded`                  |
| `behind-default-branch`  | script                     | a default branch is found                     | always rerun                                                                 | `rebase`                    |
| `findings-leftovers`     | script                     | always                                        | always rerun                                                                 | new                         |
| `open-checkboxes`        | script lists, model judges | Markdown touched since its marker has `- [ ]` | HEAD or tree changed since its marker                                        | `before-shipping` + check c |
| `diff-review`            | LLM                        | a diff since its marker HEAD, or a dirty tree | HEAD or tree changed                                                         | check a (code review)       |
| `acceptance-criteria`    | LLM                        | the branch's bead has a design or acceptance  | HEAD or tree changed, or that bead updated                                   | new                         |
| `conversation-leftovers` | LLM                        | always                                        | a new turn started                                                           | check b                     |
| `related-tracker-items`  | LLM                        | a tracker exists (Beads or Kingdone)          | new turn, HEAD or tree changed; Beads: any bd issue updated after the marker | check d                     |
| `unraised-follow-ups`    | LLM                        | always                                        | new turn, HEAD or tree changed                                               | check e (look ahead)        |
| `post-landing-steps`     | LLM                        | always                                        | new turn, HEAD or tree changed                                               | check f (after ship)        |

Renames inside the script: `cp_dirty_tree` → `cp_uncommitted_changes`,
`cp_unlanded` → `cp_unlanded_commits`, `cp_rebase` →
`cp_behind_default_branch`, `cp_before_shipping` → `cp_open_checkboxes`.
`cp_notes_guard` and `cp_marker` go away (see _Git notes_).

**Check contents** carry over from today's preflight step 2 text, moved into
the check files:

- `diff-review` is today's code review (the `code-review` skill at `medium`) on
  the delta: from its marker HEAD when that commit is still an ancestor of
  HEAD, else the whole branch against the default branch. It reviews any diff —
  code, notes, docs (kelvin's Stingdom repo has no "code").
- `conversation-leftovers` lists, as today's check b: asks not done or done in
  part; questions the user left unanswered (a skipped or dismissed
  AskUserQuestion counts); questions the user asked that were not answered;
  things the user deferred; follow-ups promised; inferred loose ends.
  Preflight's own process questions never count, and findings questions are
  covered by `findings-leftovers` instead, so nothing is reported twice.
- `open-checkboxes`: the script lists `file:line` of unchecked `- [ ]` items
  (outside fenced code blocks, as `unchecked_items` does today) in Markdown
  touched since the check's marker HEAD (first run: since the merge base) plus
  the dirty tree; the model judges each one (pending work left behind, or done
  and not ticked), as today's check c.
- `acceptance-criteria` (new): the script never reports `skip` for it; the
  model skips through its check file when the branch has no bead or the bead
  has no design or acceptance. Reads the branch bead's design and acceptance
  criteria and checks the diff and the session deliver each item. A finding is
  an item not done or done in part.
- `related-tracker-items`, `unraised-follow-ups`, `post-landing-steps`: today's
  checks d, e, f, reviewing only their delta (new turns, new commits, and for
  Beads the issues from `bd list --all --updated-after <marker time>`). Items
  this session wrote stay part of `related-tracker-items`, as today.
- `findings-leftovers`: every finding in this session's findings file whose
  latest outcome is still `open` — left for later or never answered — from any
  check, including checks not rerun this time.

## Storage

One directory per session, in the git common dir so every worktree of the repo
shares it and no two sessions write the same file:

```
$(git rev-parse --git-common-dir)/kix/checks/<session-id>/
  markers.jsonl    one line per check run (and per preflight run start)
  findings.jsonl   one line per finding change
```

Both files are append-only. The current state is the last line per key (`check`
in markers, `id` in findings); earlier lines are history. No file is ever
rewritten, so a crash or a concurrent append never loses data.

**Marker line** — only the snapshot fields that check reads:

```json
{"check":"diff-review","at":"2026-10-22T12:01:07Z","run":"2026-10-22T12:00:41Z","head":"b9db0ab…","clean":true,"findings":["diff-review-1","diff-review-2"]}
{"check":"conversation-leftovers","at":"…","run":"…","turn":{"uuid":"d1eb22bf-…","ts":"2026-10-22T11:56:30.416Z"},"findings":[]}
{"check":"related-tracker-items","at":"…","run":"…","head":"…","clean":true,"turn":{…},"bd":"2026-10-22T12:00:41Z","findings":["related-tracker-items-1"]}
{"check":"acceptance-criteria","at":"…","run":"…","head":"…","clean":true,"bead":{"id":"kxa-102","updated":"2026-10-22T11:30:00Z"},"findings":[]}
```

| Field      | Written for                             | Meaning                                                          |
| ---------- | --------------------------------------- | ---------------------------------------------------------------- |
| `head`     | checks reading commits                  | full SHA of HEAD when marked                                     |
| `clean`    | same                                    | tree clean when marked; `false` makes the next status stale      |
| `turn`     | checks reading the conversation         | uuid + timestamp of the latest transcript entry when marked      |
| `run`      | every check                             | start time of the preflight run (the 🛫 line's time)             |
| `bd`       | `related-tracker-items` in a Beads repo | marker time used for `--updated-after`                           |
| `bead`     | `acceptance-criteria`                   | the branch bead's id and its `updated_at` when marked            |
| `findings` | every check                             | ids this run raised (history only; open state lives in findings) |
| `branch`   | every line, markers and findings        | `git branch --show-current` (detached: `HEAD`)                   |

A run-start line `{"run":"<time>"}` is appended when a preflight run starts
(see _Script interface_).

**Finding line** — the ReportFindings shape plus id and outcome:

```json
{"id":"diff-review-1","check":"diff-review","category":"correctness","file":"claude-code/bin/preflight-checks","line":212,"short_summary":"…","summary":"…","failure_scenario":"…","outcome":"open","at":"…"}
{"id":"diff-review-1","outcome":"fixed","at":"…"}
{"id":"related-tracker-items-1","outcome":"deferred","ref":"kxa-abc","at":"…"}
{"id":"conversation-leftovers-3","outcome":"discarded","reason":"…","at":"…"}
```

- `id` is `<check>-<n>`, assigned by the script, stable across runs: a rerun
  carries `diff-review-1` forward instead of creating a duplicate.
- `outcome`: `open` · `fixed` · `deferred` (with `ref`, the bead or arrival) ·
  `discarded` (with `reason`). Only `open` findings are carried and resurfaced.
- `file` / `line` are optional (conversation and tracker findings point at no
  file; tracker findings may carry `ref`).
- Every finding line also carries `branch` (below).
- A later line for the same id merges over the earlier ones (an outcome line
  carries only what changed).

**Old findings on a delta rerun.** A finding stays open through
`findings.jsonl` until something resolves it; `mark` takes only new findings,
nothing needs passing back to carry. A stale check reads its own open findings
(`findings <check>`) along with its delta, and when the delta made one moot —
fixed by hand, or the user said "never mind" — the check resolves it itself:
`fixed`, or `discarded` with the reason ("obsolete: …"). No other outcome.

**Branches.** Status, carry and `findings-leftovers` only look at lines whose
`branch` is the current branch, so a session that moves between worktrees or
branches never mixes markers, and findings raised on branch A never block
shipping branch B. Conversation findings are tied to the branch they were
raised on too (kxa-289 handles a session acting on a branch it does not own).

Resolving a finding appends to `findings.jsonl` only. The marker is untouched,
so the fix commit still makes `diff-review` stale — that is the point of the
split.

## Turns and the transcript

"A new turn started" (the tables above) means **new conversation after the
marker**: a typed prompt, an automated turn (a side-session event, a
notification), or an answer to an AskUserQuestion. The answers count because
they arrive inside the same turn as tool results: the Decide answers and the
Verdict's rerun answer (preflight reruns right away, in the same turn) carry
free text under "Other" and are conversation the checks have not read. Since
each check is marked right after it runs, everything after it — Decide, Fixes,
the rerun answer — stales the conversation checks, and the next run reviews
just that delta (cheap). Preflight's own process questions are never leftovers
themselves; only what the answers say is.

**With the transcript** (`~/.claude/projects/*/<session-id>.jsonl`, honoring
`CLAUDE_CONFIG_DIR`): a turn start is an entry with `type: "user"`, no
`isMeta: true`, whose content is a string or an array that does not start with
a `tool_result` (checked against a real transcript on 2026-10-22), or an entry
`type: "attachment"` whose `attachment.type` is `queued_command` (a message
typed while the model works, or an automated turn such as a task notification
or side-session event: real transcripts record these only as attachments, never
as `user` entries; any `origin` counts). Other attachment types never start a
turn. The script:

- at `mark`, records the uuid + timestamp of the latest transcript entry;
- at status time, reports `stale` when, after that entry (uuid not found: after
  that timestamp), there is a turn start or a `tool_result` answering an
  `AskUserQuestion` tool use, and prints where the delta begins (that entry's
  timestamp). Other tool results (Bash, Read, …) and assistant text never
  stale.

**Without the transcript** (not found, unreadable): the marker keeps the run
time only, and the check's status is `unknown since <run time>`. The model then
finds the run's start line, which carries that exact time
(`🛫 preflight check started here · 2026-10-22 12:00:41`), in its context and
reviews everything below it. No such line in context (compacted) → review the
whole session and say so.

## Script interface

`preflight-checks` keeps its current call and gains subcommands. `--session ID`
(default `$CLAUDE_CODE_SESSION_ID`) picks the session directory for all of
them. No session id (a terminal outside Claude Code, Codex) → the directory is
`unknown`, as today's `checked unknown` note; prompt-based checks then report
`unknown since <run time>` (no transcript to read), and everything else works,
ship included.

- **`preflight-checks [--format pretty|tsv] [--no-fetch]`** — as today: facts,
  then one row per check. Deterministic checks report `pass` / `finding` /
  `skip`. LLM checks and `open-checkboxes` report their marker status: `fresh`
  · `stale` · `never` · `unknown` · `skip` (does not apply). Freshness is
  decided first: a marker that matches (same HEAD, clean tree, no new
  conversation, …) is `fresh` even when the check would not apply now; `skip`
  is only for a check with no marker and nothing to look at (`diff-review` with
  no marker: no commits since the merge base and a clean tree). Each row has a
  detail saying the delta start (`since b9db0ab`, `since 2026-10-22 11:56`,
  `3 bd updates`). Rows carry no per-row open-findings count:
  `findings-leftovers` lists open finding ids, and
  `preflight-checks findings <check>` gives a check's own. An unreadable `bd`
  (non-zero exit or non-JSON) stales the row (`bd unreadable`,
  `<id> unreadable` for the bead check) rather than passing it. The `from` fact
  becomes `diff-review`'s marker HEAD (when still an ancestor of HEAD), else
  `-`; `shortstat` keeps reading from it. `open-checkboxes`' detail is its
  `file:line` list.
- **`preflight-checks start`** — appends a run-start line and prints the 🛫
  line with that time. Every `mark` until the next `start` records it as `run`.
- **`preflight-checks mark <check> [--bead <id>]`** — reads a JSON array of the
  run's **new** findings on stdin (may be `[]`); the script assigns ids and
  appends them to `findings.jsonl`. Old open ones stay open on their own.
  Appends the marker line, filling the snapshot fields for that check itself
  (HEAD, clean, turn, bd time, bead `updated_at` via `bd show --json`). Prints
  the assigned ids.
- **`preflight-checks resolve <id> fixed|deferred <ref>|discarded <reason>`** —
  appends an outcome line.
- **`preflight-checks findings [<check>]`** — current open findings (all, or
  one check's), as a JSON array, merged from their lines.

Tsv stays the scripting format; JSON only for findings in and out.

## Preflight, rewired

- Step 1 (rebase) unchanged, except the notes fetch/guard go away.
- Step 2 opens with `preflight-checks start`, then the status call. Each check
  that is `stale`, `never` or `unknown` runs from its file over its delta and
  is marked right after (`mark`). `fresh` → `⏭️` line, its open findings come
  from `findings` and join the report. `skip` → `⏭️` with the reason. The
  "Already checked" table and the check-mark section are replaced by this.
- Report/Decide/Fixes: each decision calls `resolve`. ReportFindings stays as
  the UI (kxa-59t decides its future); its list is built from the findings
  file.
- Verdict **Open** = `findings-leftovers` is non-empty.
- Progress numbering grows by one step for `acceptance-criteria`; the builder
  updates the table and every total.

## Ship

Step 3 (Gate) stops reading the git note. It runs
`preflight-checks --no-fetch --format tsv` after its fetch and requires
`uncommitted-changes` pass, `behind-default-branch` pass, `diff-review` `fresh`
(or `skip`: no commits) and `findings-leftovers` empty. Step 4 stops pushing
notes.

## Git notes

Retired: no writes, reads, fetches or pushes of `refs/notes/checks`;
`notes-guard`, `marked_by_session`, `newest_marked` and their tests go. Old
notes are removed: locally (`git update-ref -d refs/notes/checks`) and on
origin (`git push origin :refs/notes/checks`) for kix-agents — the remote
delete only after kelvin's explicit yes at that moment. Other repos that ran
kix (dotfiles, Stingdom) keep theirs: an after-ship note on the bead says to
delete them there.

## Tests

`scripts/test-preflight-checks.sh` (run by `make test` through
`test-git-env.sh`) grows cases for: renamed checks; `start`/`mark`/`resolve`/
`findings` round trips; id assignment and carry without duplicates; last line
per key wins; fresh → stale on a new commit, a dirty tree, a new turn in a stub
transcript, a bd update (stub `bd` on PATH), a bead update; uuid missing →
timestamp fallback; no transcript → `unknown since`; a fix (`resolve`) does not
freshen a check; `findings-leftovers` across checks. Removed: notes cases.

## Left to the builder

- Exact Markdown layout of each `checks/<name>.md` (keep today's wording where
  it moves).
- How the script finds the branch bead for `acceptance-criteria` when `mark`
  gets no `--bead` (the model passes it; the script may also try the branch
  name).
- jq vs awk for JSON (jq is already used elsewhere on kelvin's machines;
  checking it is installed and failing clearly when not is enough).
- CHANGELOG `[Unreleased]` entries.
