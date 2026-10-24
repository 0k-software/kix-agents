# Check library with markers — Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use
> superpowers:subagent-driven-development (recommended) or
> superpowers:executing-plans to implement this plan task-by-task. Steps use
> checkbox (`- [ ]`) syntax for tracking.

**Goal:** Split `kix:preflight`'s checks into named standalone checks whose
markers and findings live on disk (append-only JSONL per session), and rewire
preflight and ship to run through them, retiring the `refs/notes/checks` git
notes.

**Architecture:** `claude-code/bin/preflight-checks` (Bash + jq) gains a
session store under the git common dir, four subcommands (`start`, `mark`,
`resolve`, `findings`) and one status row per check computed from markers. The
LLM checks' instructions move out of `claude-code/skills/preflight/SKILL.md`
into one file each under `claude-code/skills/preflight/checks/`. Preflight's
step 2 runs only checks whose row is not `fresh`.

**Tech Stack:** Bash 3.2+ (macOS), git 2.x, jq ≥ 1.6, bd 1.2.x, Claude Code
transcript JSONL, Prettier (`make check`), shell suites (`make test`).

**Spec:** [`docs/kix/kxa-102/spec.md`](spec.md) — read it first; this plan
argues from it and does not repeat its rationale. Where they differ, the spec
wins.

## Global Constraints

- Skill text is English only (bd memory `skills-english-only`).
- Every commit through `kix:commit` (pre-commit hook runs Prettier; `make test`
  runs when a `scripts/test-*.sh` or `claude-code/bin/preflight-checks` is
  staged). `make check` and `make test` green before each commit.
- No push of the feature branch, no PR (bd memory `no-prs-local-checks`).
  Landing is `/kix:ship`, offered at the end.
- Every test suite that runs git unsets
  `GIT_DIR GIT_WORK_TREE GIT_INDEX_FILE GIT_OBJECT_DIRECTORY GIT_COMMON_DIR GIT_PREFIX GIT_ALTERNATE_OBJECT_DIRECTORIES`
  at its top, as `scripts/test-preflight-checks.sh` does (kxa-6df).
- Store path:
  `$(git rev-parse --path-format=absolute --git-common-dir)/kix/checks/<session>/{markers,findings}.jsonl`;
  `<session>` = `--session` value, else `$CLAUDE_CODE_SESSION_ID`, else
  `unknown`.
- Both files append-only, one compact JSON object per line (`jq -c`); never
  rewritten. Last line per key wins (`check` in markers, `id` in findings,
  later lines merged over earlier ones for findings).
- Every stored line carries `branch` = `git branch --show-current`, or `HEAD`
  when detached. Every read filters to the current branch.
- Times are UTC `YYYY-MM-DDTHH:MM:SSZ` (`date -u +%Y-%m-%dT%H:%M:%SZ`).
- Check names (exact): `uncommitted-changes`, `unlanded-commits`,
  `behind-default-branch`, `open-checkboxes`, `diff-review`,
  `acceptance-criteria`, `conversation-leftovers`, `related-tracker-items`,
  `unraised-follow-ups`, `post-landing-steps`, `findings-leftovers`.
- Markable checks (accepted by `mark`): `open-checkboxes`, `diff-review`,
  `acceptance-criteria`, `conversation-leftovers`, `related-tracker-items`,
  `unraised-follow-ups`, `post-landing-steps`.
- Outcomes (exact): `open`, `fixed`, `deferred` (needs `ref`), `discarded`
  (needs `reason`).
- jq is required; without it the script prints
  `preflight-checks: jq is required` to stderr and exits 1.

## Review Focus

1. A transcript with a malformed or truncated last line (Claude Code mid-write)
   — the script skips unparseable lines (`jq -R 'fromjson?'`), never errors.
2. Two worktrees of one repo in one session — same store (common dir), rows
   filtered by branch, so a marker from worktree A never makes worktree B
   fresh.
3. A finding whose `summary` holds a newline, quotes, `|` or non-ASCII text —
   stays one JSONL line and round-trips byte-identical through `findings`.
4. Marker HEAD rebased away (not an ancestor of HEAD) — `diff-review` is
   `stale` with `rebased since <short>`, `from` fact `-`, review range falls
   back to the merge base.
5. Detached HEAD — lines stored and read under branch `HEAD`, no error.

Each line has its test in the owning task below.

---

## File map

| File                                                | Change                                                                  |
| --------------------------------------------------- | ----------------------------------------------------------------------- |
| `claude-code/bin/preflight-checks`                  | renames, notes removal, store, subcommands, status rows                 |
| `scripts/test-preflight-checks.sh`                  | update for renames and notes removal (Task 1), new `from`/rows (Task 3) |
| `scripts/test-preflight-store.sh` (new)             | store + subcommands + staleness (Tasks 2–4)                             |
| `claude-code/skills/preflight/checks/<name>.md` (7) | new: one per markable check                                             |
| `claude-code/skills/preflight/SKILL.md`             | rewired step 1/2, Report/Decide/Fixes/Verdict, progress table, mistakes |
| `claude-code/skills/ship/SKILL.md`                  | step 1 wording, step 3 Gate, step 4 notes push removed                  |
| `CHANGELOG.md`                                      | `[Unreleased]` entries                                                  |
| `CLAUDE.md`                                         | Architecture line for `preflight-checks` and `checks/`                  |

---

### Task 1: Rename the deterministic checks, retire git notes

**Files:**

- Modify: `claude-code/bin/preflight-checks` (usage text, `cp_*` functions,
  `do_fetch`, `marked_by_session`, `newest_marked`, run section)
- Modify: `scripts/test-preflight-checks.sh`

**Interfaces:**

- Produces: rows `uncommitted-changes`, `unlanded-commits`,
  `behind-default-branch`, `open-checkboxes` (temporarily still
  `pass`/`finding` with the `file:line` list, as `before-shipping` today);
  functions `cp_uncommitted_changes`, `cp_unlanded_commits`,
  `cp_behind_default_branch`, `cp_open_checkboxes`. Rows `notes-guard` and
  `marker` are gone. Fact `from` is always `-` until Task 3.

- [x] **Step 1: Update the tests to the new names**

  In `scripts/test-preflight-checks.sh`: rename every `dirty-tree`, `unlanded`,
  `rebase`, `before-shipping` row lookup to the new names; delete the
  "notes.rewriteRef guard" and "check marks" cases and the `marker` assertions;
  in "fresh clone" the pass loop is
  `uncommitted-changes unlanded-commits behind-default-branch open-checkboxes`
  and `line count` is `9`; in "--format pretty" `rows` is `11` and the finding
  row is `| open-checkboxes | finding | todo.md:1 |`. Add:

  ```bash
  echo "fetch never touches refs/notes/checks"
  setup
  out=$(KIX_FETCH_TTL=0 "$BIN" --format tsv --session s1)
  check "no notes ref" "$(git show-ref refs/notes/checks | wc -l | tr -d ' ')" "0"
  teardown
  ```

  (Push a `refs/notes/checks` note to origin from `$work/seed` first so the
  case would fail on today's fetch.)

- [x] **Step 2: Run, expect failures** —
      `bash scripts/test-preflight-checks.sh` → FAIL on the renamed rows.

- [x] **Step 3: Implement** — rename the functions and row names; delete
      `cp_notes_guard`, `cp_marker`, `marked_by_session`, `newest_marked`, the
      notes fetch line in `do_fetch`; `from` emits `-` (Task 3 fills it);
      `shortstat` reads from the merge base. Update the usage text to the new
      names and drop `--session`'s "check marks" wording (it now picks the
      store).

- [x] **Step 4: Run** `make test` → `all passed` for every suite.

- [x] **Step 5: Commit** —
      `refactor(kxa-102): name preflight-checks rows by what they check, drop git notes`

---

### Task 2: Session store and the `start` / `mark` / `resolve` / `findings` subcommands

**Files:**

- Modify: `claude-code/bin/preflight-checks` (argument parsing, store helpers,
  subcommands, `findings-leftovers` row)
- Create: `scripts/test-preflight-store.sh` (same harness as
  `test-preflight-checks.sh`: `setup`/`teardown`/`check`, throwaway origin, env
  unset at the top; `BIN` overridable by `PREFLIGHT_CHECKS_BIN`)

**Interfaces:**

- Consumes: Task 1's row names.
- Produces (used by Tasks 3–6):
  - `preflight-checks start [--session ID]` → appends
    `{"run":"<time>","branch":"<b>"}` to `markers.jsonl`; prints exactly
    `🛫 preflight check started here · <time>`.
  - `preflight-checks mark <check> [--bead <id>] [--session ID]` ← stdin JSON
    array of new findings (each: `category`, `summary`, optional `file`,
    `line`, `short_summary`, `failure_scenario`, `ref`). Assigns `id` =
    `<check>-<n>`, `n` = 1 + number of distinct ids already starting with
    `<check>-` in `findings.jsonl` (all branches). Appends each as
    `{"id","check","outcome":"open","at","branch",...fields}`, then one marker
    line `{"check","at","run","branch","findings":[ids],...snapshot}`. `run` =
    the latest run line's time on this branch, else `at`. Prints the new ids,
    one per line. Unknown check or stdin not a JSON array → stderr message,
    exit 1, nothing written. (Snapshot fields arrive in Tasks 3–4; here the
    marker carries only the common fields.)
  - `preflight-checks resolve <id> fixed|deferred <ref>|discarded <reason…>` →
    appends `{"id","outcome","at","branch"}` plus `ref` / `reason` (the rest of
    the arguments joined by spaces). Unknown id, missing ref/reason, or another
    outcome → exit 1, nothing written.
  - `preflight-checks findings [<check>]` → JSON array (`jq -c`, one array on
    one line) of current findings on this branch whose merged `outcome` is
    `open`, sorted by id, each merged from all its lines.
  - Default call gains the last row `findings-leftovers`: `pass` / `none open`,
    or `finding` / ids `, `-joined.
  - Helper `store_dir` (absolute path, created on first write), `now` (UTC
    time), `cur_branch`.

- [x] **Step 1: Write failing tests** in `scripts/test-preflight-store.sh`, one
      `echo` case each:
  - "start prints the anchor line": output matches
    `^🛫 preflight check started here · [0-9-]{10}T[0-9:]{8}Z$`; the last
    `markers.jsonl` line has that `run`.
  - "mark assigns ids and records the run": `start`, then
    `echo '[{"category":"x","summary":"a"},{"category":"x","summary":"b"}]' | $BIN mark diff-review`
    prints `diff-review-1` and `diff-review-2`; a second `mark diff-review`
    with one finding prints `diff-review-3`; the marker's `run` equals the
    start time; `findings diff-review | jq length` = `3`.
  - "mark with [] still writes a marker": `findings` length `0`, markers line
    count `+1`.
  - "mark rejects junk": `mark nope`, and `echo '{}' | mark diff-review` → exit
    `1`, both files unchanged.
  - "resolve closes a finding, history kept": `resolve diff-review-1 fixed`;
    `findings` no longer lists it; `grep -c diff-review-1 findings.jsonl` =
    `2`. `resolve diff-review-2 deferred kxa-abc` and
    `resolve diff-review-3 discarded not a real problem` → merged `reason` is
    `not a real problem`. `resolve diff-review-9 fixed`,
    `resolve diff-review-2 deferred`, `resolve diff-review-2 maybe` → exit `1`.
  - "findings-leftovers row": with one open finding the default call's row is
    `finding` / `diff-review-1`; after resolving it, `pass` / `none open`.
  - "awkward text round-trips" (Review Focus 3): a summary
    `"line1\nline2 | \"q\" ação"` comes back byte-identical from `findings`,
    and `findings.jsonl` grows by exactly one line.
  - "branches never mix" (Review Focus 2, 5): mark a finding on branch `a`;
    `git switch -c b` → `findings` is `[]` and `findings-leftovers` `pass`;
    `git worktree add ../wt a` and, from `../wt`, `findings` lists it.
    `git switch --detach` → `mark` works and `findings` shows only `HEAD`'s.
  - "no session id": `env -u CLAUDE_CODE_SESSION_ID $BIN mark diff-review`
    writes under `kix/checks/unknown/`.
  - "jq missing": run with a `PATH` holding only git and coreutils symlinks →
    exit `1`, stderr `preflight-checks: jq is required`.

- [x] **Step 2: Run** `bash scripts/test-preflight-store.sh` → FAIL
      (subcommands unknown).

- [x] **Step 3: Implement** — dispatch on the first argument
      (`start|mark|resolve|findings`, else today's report); options may follow
      the subcommand. Merge findings with `jq -s 'group_by(.id) | map(add)'`
      over lines read with `jq -cR 'fromjson? // empty'`, then filter `branch`
      and `outcome`.

- [x] **Step 4: Run** `make test` → all suites pass.

- [x] **Step 5: Commit** —
      `feat(kxa-102): store check markers and findings per session`

---

### Task 3: Status rows from markers (commits, tree, bd, bead)

**Files:**

- Modify: `claude-code/bin/preflight-checks`
- Modify: `scripts/test-preflight-store.sh`, `scripts/test-preflight-checks.sh`

**Interfaces:**

- Consumes: Task 2's store helpers and marker lines.
- Produces:
  - `mark` writes the snapshot fields per check: `head` (full SHA) and `clean`
    (bool) for `open-checkboxes`, `diff-review`, `acceptance-criteria`,
    `related-tracker-items`, `unraised-follow-ups`, `post-landing-steps`; `bd`
    (= `at`) for `related-tracker-items` in a Beads repo (`.beads/` exists and
    `command -v bd`); `bead` `{"id","updated"}` for `acceptance-criteria` when
    `--bead` is given (`updated` from `bd show <id> --json`, `.updated_at` of
    the object or of the array's first element). Bead not found → exit 1,
    nothing written.
  - Default call: one row per markable check, in this order after
    `behind-default-branch`: `open-checkboxes`, `diff-review`,
    `acceptance-criteria`, `conversation-leftovers`, `related-tracker-items`,
    `unraised-follow-ups`, `post-landing-steps`; then `findings-leftovers`
    last. 16 rows in all.
  - Row status and detail (exact strings; reasons `, `-joined in this order):
    - `fresh` / `no changes since <marker at>` — the marker exists and none of
      its fields are stale.
    - `stale` / reasons: `new commits since <short marker head>` (marker head
      an ancestor of HEAD, differs) · `rebased since <short marker head>` (not
      an ancestor) · `dirty tree` (tree dirty now, or marker `clean` false) ·
      `<n> bd update(s) since <marker bd>`
      (`bd list --all --updated-after <bd> --json | jq length` > 0) ·
      `<id> updated` (bead `updated_at` differs).
    - `never` / `no marker`.
    - `skip` / reason — only with no marker: `diff-review` with no commits
      since the merge base and a clean tree → `no changes`;
      `related-tracker-items` with neither `.beads/`+`bd` nor `Gates/Gates.md`
      → `no tracker`; `open-checkboxes` with an empty list →
      `no unchecked items`.
    - `open-checkboxes` appends ` — <file:line list>` to a `stale`/`never`
      detail; the list covers Markdown changed since its marker head when that
      is an ancestor of HEAD (else since the merge base) plus the dirty tree,
      via today's `touched_markdown` + `unchecked_items` with a `<from>`
      argument.
  - Fact `from` = `diff-review`'s marker head on this branch when an ancestor
    of HEAD, else `-`; `shortstat` from it when set (as before Task 1).

- [x] **Step 1: Write failing tests** in `scripts/test-preflight-store.sh`
      (stub `bd`: a script first on `PATH` that answers `list … --json` with
      the contents of `$work/bd-list.json` and `show <id> --json` with
      `$work/bd-show.json`; `mkdir .beads` to make the repo Beads):
  - "never, then fresh, then stale on a commit": `diff-review` row `never` /
    `no marker`; commit, `mark diff-review` with `[]` → `fresh`; commit again →
    `stale` / `new commits since <short>`; `from` fact = the marked SHA.
  - "dirty tree stales": after a fresh mark, `echo x > y` → `stale` /
    `dirty tree`; marking on a dirty tree then cleaning still reads `stale`.
  - "rebased away" (Review Focus 4): mark, `git commit --amend -m x` → `stale`
    / `rebased since <short>`, `from` = `-`.
  - "fresh wins over skip": on a branch with no commits past origin/main, no
    marker → `diff-review` `skip` / `no changes`; after a `mark` → `fresh`.
  - "bd updates stale related-tracker-items": Beads repo, mark, set
    `bd-list.json` to `[{"id":"x"}]` → `stale` / `1 bd update(s) since <time>`;
    non-Beads, non-Kingdone repo → `skip` / `no tracker`; a repo with
    `Gates/Gates.md` → `never`.
  - "bead update stales acceptance-criteria":
    `mark acceptance-criteria --bead kxa-1` with `updated_at` T1 → `fresh`;
    change the stub to T2 → `stale` / `kxa-1 updated`.
  - "open-checkboxes delta": commit `a.md` with `- [ ] x`, row `never` /
    `no marker — a.md:1`; mark; commit `b.md` with `- [ ] y` → `stale` /
    `new commits since <short> — b.md:1` (`a.md` not listed).
  - In `scripts/test-preflight-checks.sh`: `line count` `16`, pretty `rows`
    `18`, the `open-checkboxes` finding row becomes
    `| open-checkboxes | never | no marker — todo.md:1 |`.

- [x] **Step 2: Run** both suites → FAIL.

- [x] **Step 3: Implement** `marker_status <check>` (prints status and detail,
      tab-separated) and the per-check field table as one `case` on the check
      name; `cp_open_checkboxes` becomes its status row.

- [x] **Step 4: Run** `make test` → all pass.

- [x] **Step 5: Commit** —
      `feat(kxa-102): report each check fresh or stale from its marker`

---

### Task 4: Conversation staleness from the transcript

**Files:**

- Modify: `claude-code/bin/preflight-checks`
- Modify: `scripts/test-preflight-store.sh`

**Interfaces:**

- Consumes: Task 3's `marker_status`.
- Produces:
  - Transcript path: first match of
    `${CLAUDE_CONFIG_DIR:-$HOME/.claude}/projects/*/<session>.jsonl`; none when
    the session is `unknown`.
  - `mark` writes `turn` `{"uuid","ts"}` = the last parseable transcript line
    that has a `uuid` (its `uuid`, `timestamp`) for `conversation-leftovers`,
    `related-tracker-items`, `unraised-follow-ups`, `post-landing-steps`. No
    transcript → no `turn` field.
  - Status reasons, appended after Task 3's: `conversation since <ts>` — `ts`
    of the first entry after the marker's `turn` that is either a turn start
    (`type` `user`, `isMeta` not `true`, content a string or an array whose
    first element's `type` is not `tool_result`) or a `tool_result` whose
    `tool_use_id` is the `id` of an assistant `tool_use` named
    `AskUserQuestion`. "After": entries following the line with the marker's
    uuid; uuid absent from the file → entries with `timestamp` > the marker's
    `ts`.
  - No transcript, or marker without `turn`: when no other reason makes the row
    stale, status `unknown` / `since <marker run>`; otherwise `stale` with the
    reasons plus `conversation unknown since <marker run>`.

- [x] **Step 1: Write failing tests** — helper `tx_turn <uuid> <ts> <text>`,
      `tx_ask <uuid> <ts> <tool id>` (assistant tool_use named
      `AskUserQuestion`), `tx_result <uuid> <ts> <tool id>`,
      `tx_bash <uuid>     <ts> <tool id>` append lines to
      `$work/cfg/projects/p/s1.jsonl`; run with `CLAUDE_CONFIG_DIR=$work/cfg`:
  - "new prompt stales": turn u1, mark `conversation-leftovers` → `fresh`; turn
    u2 at T2 → `stale` / `conversation since T2`.
  - "own tool output does not": after the mark, `tx_bash` + its result →
    `fresh`.
  - "question answers stale": `tx_ask` id q1, then `tx_result` for q1 at T3 →
    `stale` / `conversation since T3`.
  - "meta lines do not": a `user` line with `isMeta: true` → `fresh`.
  - "uuid gone, timestamp fallback": rewrite the file without the marker's
    uuid, keep a later turn → `stale`; only earlier turns → `fresh`.
  - "malformed line skipped" (Review Focus 1): append `{"type":"user",` →
    status unchanged, exit `0`.
  - "no transcript": unset config dir to an empty dir → `unknown` /
    `since <run>`; with a new commit too, `related-tracker-items` → `stale` /
    `new commits since <short>, conversation unknown since <run>`.

- [x] **Step 2: Run** → FAIL.

- [x] **Step 3: Implement** with one `jq -cR 'fromjson? // empty'` pass that
      collects the AskUserQuestion tool ids, then finds the first qualifying
      entry after the marker.

- [x] **Step 4: Run** `make test` → all pass. Also run the default call once in
      this session (`preflight-checks --no-fetch`) and confirm the transcript
      is found (rows read `never`, not `unknown`).

- [x] **Step 5: Commit** —
      `feat(kxa-102): stale conversation checks on new turns and question answers`

---

### Task 5: One instruction file per check

**Files:**

- Create:
  `claude-code/skills/preflight/checks/{diff-review,acceptance-criteria,conversation-leftovers,open-checkboxes,related-tracker-items,unraised-follow-ups,post-landing-steps}.md`

**Interfaces:**

- Produces: each file starts `# <check name>` then four bold-led paragraphs in
  this order — **Reads** (what it looks at), **Delta** (how to narrow to the
  row's detail: commits since `<short>`, conversation since `<ts>` or below the
  `🛫 … · <run>` line when `unknown`, `bd list --all --updated-after`),
  **Findings** (kinds, `category` values as today: code review's own,
  `conversation`, `checklist`, `tracker`, `related`/`idea`/`next-step`/
  `pitfall`, `after-ship`, and new `acceptance`), **Moot findings** (read
  `preflight-checks findings <check>`; resolve the ones the delta settled as
  `fixed` or `discarded "obsolete: …"`). Then the body moved from preflight
  step 2 a–f, wording kept.
- `diff-review`: today's 2a, range `from`..HEAD (else `<base>...HEAD`) plus the
  dirty tree, `code-review` skill at `medium`.
- `conversation-leftovers`: today's 2b list and tally line; adds "preflight's
  own process questions are not leftovers; finding questions are
  `findings-leftovers`' job".
- `open-checkboxes`: today's 2c, judging the row's `file:line` list.
- `related-tracker-items`: today's 2d including "Items this session wrote".
- `unraised-follow-ups`: today's 2e. `post-landing-steps`: today's 2f.
- `acceptance-criteria` (new): `bd show <bead>`; each design item and
  acceptance criterion not delivered by the diff and the session, or delivered
  in part, is a finding (category `acceptance`); no bead or neither field →
  `⏭️` and `mark` with `[]` and no `--bead`.

- [x] **Step 1: Create the seven files**, moving text, not rewriting it.
- [x] **Step 2: Verify** `make check` passes and
      `grep -c '' claude-code/skills/preflight/checks/*.md` lists 7 files.
- [x] **Step 3: Commit** —
      `feat(kxa-102): one instruction file per preflight check`

(No deletion from SKILL.md here: Task 6 swaps the text for pointers, so the
skill stays whole between commits.)

---

### Task 6: Rewire preflight

**Files:**

- Modify: `claude-code/skills/preflight/SKILL.md`

**Interfaces:**

- Consumes: Tasks 1–5 (row names, subcommands, check files).

Changes, section by section:

- [x] **Step 1: Deterministic checkpoints** — row table lists the 16 rows with
      the new names and statuses (`fresh · stale · never · unknown · skip` for
      markable rows; `findings-leftovers` pass · finding). Keep "It runs twice"
      (step 1 with fetch, step 2 with `--no-fetch`).
- [x] **Step 2: Check marks → Markers** — replace the section: the store, that
      only the script writes it, `start`/`mark`/`resolve`/`findings` one line
      each, and that a marker records only that the check ran.
- [x] **Step 3: Step 1 Rebase** — drop "and the check marks" from the fetch
      sentence, the **Notes guard** paragraph and the "leaves its old check
      marks behind" paragraph; rename `dirty-tree`/`rebase` rows.
- [x] **Step 4: Step 2 Collect findings** — new body: `preflight-checks start`
      (print its 🛫 line as the step's first output), then
      `preflight-checks --no-fetch --format tsv`. For each markable row in
      table order: `fresh` → `⏭️ <n>/<total> <Check> — no changes since …`;
      `skip` → `⏭️` with the detail; else read `checks/<name>.md` (path
      `${CLAUDE_PLUGIN_ROOT}/skills/preflight/checks/`) and run it over the
      row's delta, then pipe its new findings to `preflight-checks mark <name>`
      (`--bead` for `acceptance-criteria`) and resolve the moot ones. Remove
      the "Already checked" text and table, the "Skips" table and every 2a–2f
      body (now pointers to the files). Keep "No check goes to an agent".
- [x] **Step 5: Report** — the list is `preflight-checks findings` (all open on
      this branch) — fresh checks' carried findings included; ReportFindings
      ids follow the finding ids; categories as in the check files.
- [x] **Step 6: Decide / Run the queue** — each decision runs
      `preflight-checks resolve`: applied fix → `fixed` after its commit;
      task/arrival → `deferred <id or note>`; note in the task →
      `deferred <bead id>`; discard → `discarded <reason>`; "Leave for later" →
      nothing. Replace "ReportFindings again with outcome" by "after the queue,
      call ReportFindings with `outcome` from `findings`".
- [x] **Step 7: Verdict** — **Open** = `findings-leftovers` row `finding`;
      **Clear** = `findings-leftovers` `pass`, `diff-review` `fresh` or `skip`,
      and step 5 committed nothing and edited no tracker item. Remove the
      "first note line starts with `checked`" test.
- [x] **Step 8: Progress** — add `Acceptance criteria (2b)` after code review
      (renamed `Diff review (2a)`), renumber: preflight `/12`, ship `/16`,
      close `/18`, every later row +1, and every example line's total. Rename
      the step names to the check names' plain form (Conversation leftovers,
      Open checkboxes, Related tracker items, Unraised follow-ups, Post-landing
      steps).
- [x] **Step 9: Common mistakes** — drop the four notes/check-mark bullets and
      the _Already checked_ one; add: "Writing a marker or finding line by hand
      instead of through `preflight-checks`", "Running a check whose row is
      `fresh`", "Reviewing a stale check's whole history instead of its delta".
- [x] **Step 10: Verify** — `make check`;
      `grep -n 'notes\|check mark\|marker`\|dirty-tree\|before-shipping\|Already
      checked' claude-code/skills/preflight/SKILL.md` shows no stale reference
      (the word "notes" may remain for bd/quest notes).
- [x] **Step 11: Commit** —
      `feat(kxa-102): preflight runs through the check library`

---

### Task 7: Ship, docs, changelog

**Files:**

- Modify: `claude-code/skills/ship/SKILL.md` (step 1 wording, steps 3–4,
  progress totals 16/18)
- Modify: `CHANGELOG.md`, `CLAUDE.md`

- [x] **Step 1: Ship** — step 1: "even when every check is fresh (preflight
      skips them then…)"; step 3 Gate block becomes `git status --porcelain`,
      `git fetch origin`, `preflight-checks --no-fetch --format tsv`; stop
      unless `uncommitted-changes` pass, `behind-default-branch` pass,
      `diff-review` `fresh` or `skip`, `findings-leftovers` pass (the stop
      message lists which failed); step 4 drops the notes push and its retry
      paragraph. Progress `12–15` → `13–16` of `16` (`18` from close).
- [x] **Step 2: CHANGELOG** `[Unreleased]` — `### Changed`: preflight checks
      run from a check library with per-check markers; rows renamed (list old →
      new); `### Added`: `acceptance-criteria` and `findings-leftovers` checks,
      `preflight-checks start|mark|resolve|findings`; `### Removed`:
      `refs/notes/checks` check marks and the `notes-guard` row. Also fix the
      earlier `preflight-checks` entry's row list.
- [x] **Step 3: CLAUDE.md** Architecture `bin/` bullet: `preflight-checks` also
      keeps per-session check markers and findings; add
      `claude-code/skills/preflight/checks/` to the skill-folder sentence.
- [x] **Step 4: Verify** — `make check && make test`;
      `grep -rn 'notes/checks\|check mark' claude-code CLAUDE.md` → nothing.
- [x] **Step 5: Commit** —
      `feat(kxa-102): ship gates on the check library, notes gone`

---

### Task 8: After-landing note and end-to-end run

- [x] **Step 1:** Append to kxa-102's notes (bd memory
      `after-ship-convention`):
      `After this lands on main: delete the old check marks — locally git update-ref -d refs/notes/checks (and refs/notes/checks-remote) in every kix repo clone, and on origin git push origin :refs/notes/checks for kix-agents, dotfiles and Stingdom (each remote delete only after kelvin's explicit yes); /reload-plugins.`
- [-] **Step 2: Live run** — in this session, run `/kix:preflight` from the
  worktree's plugin copy (read the worktree's SKILL.md, call
  `claude-code/bin/preflight-checks` by path). Expect: every markable row runs
  once and is marked; a second run right after prints `⏭️` for every
  commit-only check and `stale` / `conversation since …` only for the
  conversation checks (the first run's Decide answers), which review just that
  delta. Report what happened; fix anything off as its own commit. → plumbing
  checked live (start/mark/status); the full run waits for landing (kxa-102
  note).
- [x] **Step 3:** `make check && make test`, `git status` clean, then offer
      `/kix:ship`.
