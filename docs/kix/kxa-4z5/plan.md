# Speed up preflight — Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:executing-plans
> to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for
> tracking.

**Goal:** Preflight's step 2 becomes one brief call, the judgement work, one
`mark --batch` — fewer tool calls than the old all-LLM preflight — and
`preflight-checks --no-fetch` stays near 1 s on a long session.

**Architecture:** `claude-code/bin/preflight-checks` (Bash + jq) reads the
transcript, the store and bd once per call; `start` becomes the brief (status
rows plus each stale check's instructions and data); `mark --batch` marks all
checks at once and prints the open findings. Staleness triggers narrow to each
check's own inputs, and commits a Fix job made (`resolve <id> fixed <commit>`)
stale only `diff-review`. `claude-code/skills/preflight/SKILL.md` loses the
progress lines and the per-check calls; ship and close follow.

**Tech Stack:** Bash 3.2+, git, jq ≥ 1.6, bd 1.2.2 / dolt (optional), Prettier,
shell suites (`make test`); `uv run --with claude-agent-sdk` for the bench.

**Spec:** bead kxa-4z5 (`bd show kxa-4z5`): design items 1–15 and the benchmark
harness notes.

## Global Constraints

- Only `preflight-checks` writes the store; files stay append-only JSON lines.
- Missing data (no transcript, bd unreadable) makes a check `unknown` or
  `stale`, never a failed run.
- The brief prints pointers and short excerpts, never a full diff or
  transcript.
- Skill text English only. No progress lines (item 8); the closing ⚠️ block for
  pending items stays.
- kxa-13v (drop apply-all) and kxa-a9i (`diff --html`) sit on unmerged branches
  touching the same SKILL.md sections: keep edits to Decide and the rerun
  question minimal so the second to land merges cleanly.

## Decisions

- **Per-check triggers (item 10).** `diff-review`: any commit, rebase, dirty
  tree. `acceptance-criteria`: bead updated, non-fix commits, rebase, dirty.
  `unraised-follow-ups`: non-fix commits, rebase, dirty, conversation.
  `post-landing-steps`: bead updated, non-fix commits, rebase, conversation.
  `conversation-leftovers`: conversation. `related-tracker-items`: bd updates
  only. `open-checkboxes`: a Markdown file with unchecked items changed since
  its marker head (committed or dirty).
- **Fix commits.** `resolve <id> fixed [<commit>]` stores the commit's full
  sha; a commit range whose every commit is a stored fix commit is "fix commits
  only".
- **Conversation.** Only new prompts and queued commands stale; an
  AskUserQuestion answer does not (after a marker, it is preflight's own Decide
  or Verdict question).
- **Auto-marks (items 7, 12).** `start` marks with `[]` itself:
  `open-checkboxes` stale with no unchecked item left; `acceptance-criteria`
  with no bead, or a bead without design and acceptance.
- **Candidates (item 7).** Unchecked boxes print as a ready JSON array for
  `mark --batch`; the model drops the false positives.

## Tasks

- [ ] **1. One pass per call.** Transcript parsed once (one jq pass to a TSV
      index of uuids and prompts), markers read once, `git status` once, bd
      read once (one `bd list --updated-after <earliest>` filtered per marker,
      one `bd show` per bead). Existing suites pass unchanged except the
      AskUserQuestion case. Measure on this session's transcript.
- [ ] **2. Scoped staleness.** Triggers above; `resolve … fixed <commit>`;
      tests: a fix commit stales only `diff-review`; a Markdown edit without
      boxes leaves `open-checkboxes` fresh; bd updates leave everything but
      `related-tracker-items` fresh; a question answer stales nothing.
- [ ] **3. `mark --batch`.** stdin
      `{"<check>": [findings], …, "resolve":     [["<id>", "fixed"|"discarded", "<reason>"]]}`,
      `--bead` applies to `acceptance-criteria` and `post-landing-steps`;
      validates everything before writing; prints the branch's open findings
      (JSON). Tests: ids, one marker per check, junk rejected with nothing
      written.
- [ ] **4. The brief.** `start [--bead ID] [--no-fetch] [--format …]` writes
      the run anchor, prints the 🛫 line, the rows, then one section per
      `stale`/`never`/`unknown` check: its instructions (the check file) and
      data — range and shortstat, bead criteria, candidate findings, bd
      updates, prompt excerpts since the marker, its open findings. Auto-marks
      as above. Tests on sections present/absent and the auto-marks.
- [ ] **5. Skills.** preflight SKILL.md: step 1 + 2 through `start`, judgement
      with parallel calls, one `mark --batch`, Report from its output; no
      Progress section; Fix jobs as one edit batch + one test-and-commit call,
      one push after the queue; Verdict reruns without asking after approved
      fixes only (once in a row). Check files trimmed (shared Moot rule moves
      to SKILL.md). ship/close lose their progress paragraphs. CLAUDE.md and
      CHANGELOG.
- [ ] **6. Bench.** `scripts/bench-preflight` (SDK host with auto-answer,
      PreToolUse guard, fixture builder, old vs new in parallel, JSONL logs,
      no-change rerun case). Record results on the bead.
