# Show what changed at the preflight rerun question — Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use
> superpowers:subagent-driven-development (recommended) or
> superpowers:executing-plans to implement this plan task-by-task. Steps use
> checkbox (`- [ ]`) syntax for tracking.

**Goal:** Preflight's **changed** rerun question offers "Show me what changed",
which prints this run's commits and every bead change since the user's last
review as git-style diffs; any unseen bead change makes the verdict
**changed**.

**Architecture:** `claude-code/bin/preflight-checks` (Bash + jq) gains bead
marks in its per-session store (`bd.jsonl`), a `bd-mark` subcommand, a `diff`
subcommand that renders `git diff` plus `dolt diff -r json` of the beads DB,
and an `unreviewed-bead-changes` checkpoint row. A new SessionStart hook writes
the session-start mark. `claude-code/skills/preflight/SKILL.md` Verdict reads
the new row and offers the new option.

**Tech Stack:** Bash 3.2+ (macOS), git 2.x, jq ≥ 1.6, bd 1.2.2 (embedded dolt
mode), dolt 2.x CLI, Prettier (`make check`), shell suites (`make test`).

**Spec:** [`docs/kix/kxa-a9i/spec.md`](spec.md) — read it first. Where they
differ, the spec wins.

## Global Constraints

- Skill text is English only (bd memory `skills-english-only`).
- Only `preflight-checks` writes the store
  (`<git common dir>/kix/checks/<session>/`); new files there are JSON lines,
  append-only, unparseable lines skipped (reuse `store_lines`).
- The beads DB lives only in the main checkout:
  `<dirname of git common dir>/.beads/embeddeddolt/<dolt_database>`, the name
  read from `.beads/metadata.json` (`"dolt_database": "kxa"`). Worktrees have
  no `embeddeddolt/`.
- `bd diff --json` omits deps, labels and comments (tested 2026-10-24); use
  `dolt diff -r json <mark>` (no second ref — diffs against the working set,
  which holds bd writes not yet dolt-committed).
- CI has neither bd nor dolt: every test that needs them prints
  `  skip: <what> (no bd/dolt)` and passes; the renderer is tested from fixture
  JSON so it runs in CI.
- Code diff inline limit: 80 lines of `git diff` output; above it, `--stat`.
- Bead diffs always print in full.
- The SessionStart hook never fails the session: exit 0, no stdout, on every
  path.
- Every commit through `kix:commit`; `make check` and `make test` pass before
  each commit.

## Review Focus

- A repo without `.beads/` or without bd/dolt: `bd-mark` is a no-op (exit 0),
  `unreviewed-bead-changes` reads `skip`, `diff` prints the code part only.
- A session with no mark at all (hook missed it, plugin enabled mid-session):
  `unreviewed-bead-changes` reads `unknown` and the Verdict treats it as
  **changed** (the _Anything else_ rule) — never silently `pass`.
- A mark whose commit dolt no longer knows (`bd compact` / `bd flatten` rewrote
  history): `diff` says `mark <short> not in beads history` and falls back to
  listing `bd list --all --updated-after <mark at>` ids, row reads `stale`.
- A bead field that is multi-line text with no trailing newline on one side:
  the line diff still shows only the changed lines (no `\ No newline` noise).
- Running from a worktree: the DB is found through the git common dir, not
  `./.beads`.

Each has a test in the task that owns it (marked _(Review Focus)_).

---

### Task 1: Bead marks — `bd-mark start|review` and DB discovery

**Files:**

- Modify: `claude-code/bin/preflight-checks` (usage text, arg parsing, new
  functions, subcommand dispatch)
- Create: `scripts/test-preflight-bead-diff.sh`

**Interfaces:**

- Produces:
  - `bead_db_dir()` → prints the absolute dolt DB dir, or nothing (exit 1) when
    there is none.
  - `bead_head()` → prints dolt's current full commit hash (`dolt log -n 1`
    parsed, or `bd vc status --json | jq -r .commit`), nothing on failure.
  - `bead_window()` → prints one JSON object
    `{"kind":"review"|"start","commit":"<hash>","at":"<iso>"}` — the latest
    `review` line in `bd.jsonl`, else the first `start` line, else nothing.
  - `preflight-checks bd-mark start` — appends
    `{"kind":"start","commit":…,"at":…}` to `<store>/bd.jsonl` only when no
    `start` line exists yet; prints nothing.
  - `preflight-checks bd-mark review` — appends a `review` line every time;
    prints `👀 beads reviewed up to <short> · <at>`.
  - Both: exit 0 and write nothing when `bead_db_dir` or `bead_head` is empty.

- [x] **Step 1: Write the failing tests** in
      `scripts/test-preflight-bead-diff.sh`, header and helpers copied from
      `scripts/test-preflight-store.sh` (same `unset GIT_*`, `setup`,
      `teardown`, `check`). `setup_beads` runs
      `bd init --prefix t --quiet     --sandbox` in the repo and
      `bd --sandbox create` for two issues; it returns 1 (caller prints skip)
      when `bd` or `dolt` is missing. Cases:
  - "start mark is written once": `bd-mark start` twice →
    `jq -s 'map(select(.kind=="start"))|length' bd.jsonl` is `1`, `.commit`
    matches `^[0-9a-v]{32}$` (dolt's base32 hash).
  - "review mark appends and prints": output matches
    `^👀 beads reviewed up to [0-9a-v]{7} · `, two calls → two `review` lines.
  - "no beads → no-op": plain repo, `bd-mark start` exit 0, no `bd.jsonl`.
  - "worktree finds the main DB" _(Review Focus)_: `git worktree add ../wt`,
    run `bd-mark review` from `../wt` → line written under the main repo's
    `.git/kix/checks/s1/bd.jsonl`, commit equals the one seen from the main
    checkout.
- [x] **Step 2: Run** `bash scripts/test-preflight-bead-diff.sh` — expected
      FAIL (`unknown subcommand bd-mark` / usage on stderr).
- [x] **Step 3: Implement** the functions and subcommand above. Usage text gets
      `bd-mark start|review` under _Subcommands_ with one line each. Register
      the suite nowhere — `scripts/test-git-env.sh` picks `test-*.sh` up by
      name.
- [x] **Step 4: Run** the suite and `make test` — PASS (bd/dolt cases print
      skip lines where missing).
- [x] **Step 5: Commit** —
      `feat(kxa-a9i): record bead review marks in the     preflight store`.

### Task 2: Bead diff renderer

**Files:**

- Modify: `claude-code/bin/preflight-checks`
- Create: `scripts/fixtures/bead-diff/` — `dolt-diff.json` (captured from a
  scratch DB with: one issue created, one deleted, one with `status`, `notes`
  (multi-line) and `priority` changed, one dep added, one label removed, one
  comment added) and `expected.txt`
- Modify: `scripts/test-preflight-bead-diff.sh`

**Interfaces:**

- Produces: `render_bead_diff` — reads `dolt diff -r json` on stdin, prints
  git-style text on stdout, nothing for an empty diff. Exact shape (one block
  per issue, issues sorted by id, blank line between blocks):

  ```
  @@ t-abc · <title> · created @@
  +title: <title>
  +status: open
  +description:
  +  <line>
  ```

  ```
  @@ t-def · <title> · modified @@
  -status: open
  +status: closed
   notes:
   <unchanged context line>
  -<old line>
  +<new line>
  +dep: blocks t-xyz
  -label: foo
  +comment (kelvinst): <text>
  ```

  Fields shown, in this order, only when set (created/deleted) or changed
  (modified):
  `title, status, priority, issue_type, assignee, close_reason, description, design, acceptance_criteria, notes`.
  The last four are text: shown as a `<field>:` line plus a line diff
  (`diff -U2` of the two values, its `---`/`+++`/`@@` header lines dropped,
  `\ No newline` lines dropped); on created/deleted every line gets
  `+  `/`-  `. Tables read: `issues`, `dependencies`
  (`dep: <type> <depends_on_issue_id>`), `labels`, `comments`
  (`comment (<author>): <text>`, first line only plus `…` when longer). A dep,
  label or comment whose issue has no `issues` row change still gets a
  `modified` block, title read with `bd show <id> --json` (empty title when bd
  can't). Every other table (`events`, `config`, `metadata`,
  `schema_migrations`, …) is ignored.

- [x] **Step 1: Capture the fixture** — build the scratch DB in a temp dir with
      the six edits above, run `dolt diff -r json <first commit>` in its
      `.beads/embeddeddolt/<db>`, save as `dolt-diff.json`; hand-write
      `expected.txt` in the shape above.
- [x] **Step 2: Write the failing test** "renderer matches the fixture":
      `PREFLIGHT_CHECKS_RENDER=1 "$BIN" diff --dolt-json fixtures/…/dolt-diff.json`
      — hidden test hook: `diff --dolt-json FILE` renders FILE instead of
      running dolt — output equals `expected.txt`. Plus "no trailing newline"
      _(Review Focus)_: a modified `notes` going from `a\nb` to `a\nb\nc` (one
      side without final newline) renders exactly ` a`, ` b`, `+c` under
      `notes:`.
- [x] **Step 3: Run** — FAIL.
- [x] **Step 4: Implement** `render_bead_diff` (jq groups rows by issue id;
      text fields go through `diff -U2` on two temp files) and the
      `--dolt-json` flag.
- [x] **Step 5: Run** suite — PASS; `make check` — PASS.
- [x] **Step 6: Commit** —
      `feat(kxa-a9i): render bead changes as a git-style     diff`.

### Task 3: `diff` subcommand and the `unreviewed-bead-changes` row

**Files:**

- Modify: `claude-code/bin/preflight-checks`
- Modify: `scripts/test-preflight-bead-diff.sh`,
  `scripts/test-preflight-checks.sh` (the row list it asserts)

**Interfaces:**

- Consumes: `bead_db_dir`, `bead_head`, `bead_window` (Task 1),
  `render_bead_diff` (Task 2).
- Produces:
  - `preflight-checks diff [--from <sha>]` prints, in order:
    1. with `--from`: `## Code (<from short>^..<HEAD short>)` then a
       ` ```diff ` block of `git diff <from>^..HEAD` when it is ≤ 80 lines,
       else a ` ```text ` block of `git diff --stat <from>^..HEAD` and the line
       `Too long to show inline (<n> lines).`; without `--from`, no code part;
    2. `## Beads (since <review|session start> <short> · <at>)` then a
       ` ```diff ` block of `render_bead_diff`, or `No bead changes.`;
    3. when `other_sessions_since <at>` prints anything:
       `⚠️ Other sessions also touched this repo since <at> (<n>) — some bead changes may be theirs.`
  - `other_sessions_since <iso>` → prints the session ids (transcript file
    basenames without `.jsonl`) of
    `${CLAUDE_CONFIG_DIR:-$HOME/.claude}/projects/<enc>{,--claude-worktrees-*}/*.jsonl`
    modified after `<iso>`, excluding `$session`; `<enc>` is the main checkout
    path with every `/` and `.` replaced by `-`.
  - Checkpoint row `unreviewed-bead-changes`, after `findings-leftovers`:
    `pass · no bead changes since <short>`;
    `finding · <n> bead(s) changed since <short>: <ids comma-joined>`;
    `stale · mark <short> not in beads history` _(Review Focus)_ (then `<ids>`
    from `bd list --all --updated-after <at>`); `unknown · no bead mark`;
    `skip · no beads`.

- [x] **Step 1: Write the failing tests:**
  - "row pass after review": `bd-mark review` → row `pass/…`.
  - "row counts a bd update": `bd-mark review`,
    `bd --sandbox update <id> --notes x` → row
    `finding/1 bead(s) changed since <short>: <id>`.
  - "row sees a dep": `bd-mark review`, `bd --sandbox dep add a b` → `finding`.
  - "no mark → unknown" _(Review Focus)_.
  - "no beads → skip" _(Review Focus)_: plain repo → row `skip/no beads`;
    `diff` exits 0 and prints no `## Beads` section at all.
  - "unknown mark commit → stale" _(Review Focus)_: write a `review` line with
    `commit: "0000…"` by hand into `bd.jsonl` (test-only; the store rule is for
    the skill) → row `stale/mark 0000000 not in beads history…`.
  - "code part inline vs stat": one small commit → ` ```diff ` block; a commit
    adding 200 lines → `Too long to show inline (`.
  - "other sessions warn": create `$CLAUDE_CONFIG_DIR/projects/<enc>/s2.jsonl`
    touched now → warning names 1 session; only `s1.jsonl` → no warning.
  - In `test-preflight-checks.sh`, add `unreviewed-bead-changes` to the
    expected row names.
- [x] **Step 2: Run** both suites — FAIL.
- [x] **Step 3: Implement** `sub_diff`, `other_sessions_since`,
      `cp_unreviewed_bead_changes`; usage text documents `diff` and the row.
- [x] **Step 4: Run** `make test` — PASS.
- [x] **Step 5: Commit** —
      `feat(kxa-a9i): preflight-checks diff and the     unreviewed-bead-changes row`.

### Task 4: SessionStart hook writes the start mark

**Files:**

- Create: `claude-code/hooks/bead-session-mark.sh`
- Modify: `claude-code/hooks/hooks.json` (second `SessionStart` entry, matcher
  `startup`)
- Modify: `.beads/hooks/pre-commit` (add the hook to the `make test` gate
  regex, next to `title-first-prompt\.sh`)
- Modify: `scripts/test-preflight-bead-diff.sh`

**Interfaces:**

- Consumes: `preflight-checks bd-mark start --session <id>` (Task 1).
- Produces: the hook reads the SessionStart JSON on stdin, takes `.session_id`
  and `.cwd` with jq, runs
  `"${CLAUDE_PLUGIN_ROOT}/bin/preflight-checks" bd-mark start --session <id>`
  in `.cwd` with stdout/stderr to `/dev/null`, exits 0 always.

- [x] **Step 1: Write the failing tests:** "hook writes the start mark" (pipe
      `{"session_id":"s9","cwd":"<repo>"}` with
      `CLAUDE_PLUGIN_ROOT=<repo root>/claude-code` → `bd.jsonl` under
      `kix/checks/s9/` has one `start` line); "hook is silent and exits 0" on
      garbage stdin and outside a git repo (stdout empty, `$?` 0).
- [x] **Step 2: Run** — FAIL.
- [x] **Step 3: Implement** the hook (header comment in the style of
      `title-first-prompt.sh`: what it is for, which bead) and the `hooks.json`
      and pre-commit entries.
- [x] **Step 4: Run** `make test` — PASS.
- [x] **Step 5: Commit** —
      `feat(kxa-a9i): mark the beads DB at session     start`.

### Task 5: Preflight Verdict — the rule, the option, the marks

**Files:**

- Modify: `claude-code/skills/preflight/SKILL.md` (_Deterministic checkpoints_
  table; _6. Verdict_: _Showing the diff_, **Changed**, **Clear**, _Rerun_;
  _Common mistakes_)

**Interfaces:**

- Consumes: the `unreviewed-bead-changes` row, `preflight-checks diff --from`,
  `bd-mark review` (Tasks 1–3).

Text decisions (the implementer writes the prose, in the skill's voice):

- Table: one row for `unreviewed-bead-changes`, statuses
  `pass · finding · stale · unknown · skip`.
- **Changed** also when `unreviewed-bead-changes` reads `finding` or `stale`
  (any source — Fix job, the session's own work, by hand). The "for each edited
  item, `bd show <id>`" line is replaced by naming the changed ids from the
  row's detail.
- **Clear** also needs `unreviewed-bead-changes` `pass` or `skip`; on clear,
  run `preflight-checks bd-mark review` (the clear run counts as a review).
- `unknown` falls under the existing _Anything else_ → treated as changed.
- _Showing the diff_: the compare link is a labeled Markdown link
  `[<first short>^..<HEAD short> on GitHub](…/compare/<first>^...<HEAD>)` with
  a literal `^`, never `%5E`.
- **Changed** rerun question gets a 4th option, placed second: "Show me what
  changed" — "Prints this run's commits and every bead change since your last
  review here, then asks again." On it: run
  `preflight-checks diff --from <first step 5 commit>` (no `--from` when step 5
  committed nothing), print its output in the reply as-is, then ask the same
  question again without this option.
- "I reviewed — run `<command>` again": run `preflight-checks bd-mark review`
  before rerunning. "Run again, skip my review": no mark (the changes show up
  again next time).
- Common mistakes: add "Answering 'I reviewed' without `bd-mark review`, or
  writing it on 'skip my review'" and "Summarizing the `diff` output instead of
  printing it".

- [x] **Step 1: Edit** the sections above.
- [x] **Step 2: Check**
      `grep -n "unreviewed-bead-changes\|bd-mark review\|Show     me what changed" claude-code/skills/preflight/SKILL.md`
      shows the table row, Changed, Clear, the option and both mistakes;
      `make check` PASS.
- [x] **Step 3: Commit** —
      `feat(kxa-a9i): preflight offers to show what     changed, beads included`.

### Task 6: Docs

**Files:**

- Modify: `CLAUDE.md` (_Architecture Overview_: `preflight-checks` line
  mentions `diff`/`bd-mark`; `hooks.json` line lists `bead-session-mark.sh`;
  _Pre-commit hook_ paragraph lists the new hook in the `make test` gate)
- Modify: `CHANGELOG.md` (`[Unreleased]` → _Added_: one entry for the option +
  bead diffs + verdict rule; _Changed_: compare link is labeled with a literal
  `^`)

- [x] **Step 1: Edit** both files.
- [x] **Step 2: Run** `make check` — PASS.
- [x] **Step 3: Commit** —
      `docs(kxa-a9i): document bead diffs and the     session-start mark`.
