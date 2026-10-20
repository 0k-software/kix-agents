# next-up: decide fixes one by one, then hand off — Implementation Plan

> **For agentic workers:** executed natively in the planning session (user's
> choice). Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Rewrite `/kix:next-up` from a 9-section read-only briefing into a
walk: silent gather → strict fix list → one decision per fix → run the approved
queue → top-5 next-up list → hand off the first task to a new session.

**Architecture:** Markdown skill only. `claude-code/skills/next-up/SKILL.md` is
rewritten in place; `claude-code/skills/close/SKILL.md` gets two additions in
step 2b; `CHANGELOG.md` gets `[Unreleased]` entries.

**Tech Stack:** Claude Code skill format (frontmatter + Markdown), bd 1.2.x,
Prettier (`make check`).

**Spec:** `bd show kxa-ugx` — description, acceptance, notes and the design
field (the brainstorm's decisions). The design field wins where they differ.

## Global Constraints

- Every bead named as id + title, everywhere, epics included.
- Links only in the reply text, never inside an AskUserQuestion.
- No emoji and no ❓/✅ progress lines anywhere in next-up.
- Nothing runs between questions; the queue runs after the last answer.
- next-up never retitles the session and never starts the task's work.
- No `gh` calls in a PR-less repo (memory `no-prs-local-checks`, or `origin`
  not on GitHub).
- No epic-label convention, no theme-epic check (moved to kxa-q76).
- Close edit limited to step 2b's two additions (next-up offer, detach).
- `make check` passes.

## Review Focus

1. Tracker already clean → one line, straight to the next-up list (no Apply-all
   question).
2. Fewer than 5 ready items → list what exists; none → say so, skip the
   hand-off question.
3. Plain CLI (no `start_session`) → print the prompt in a code block; no Remote
   Control step.
4. `start_session` refused (e.g. turn started by another session) → fall back
   to the printed prompt.
5. Repo without beads (no `.beads/` or no `bd`) → say next-up needs beads and
   stop.

Each is pinned by a line in the task that owns it (verified by the grep steps).

---

### Task 1: next-up — frame, conventions, gather

**Files:** Modify `claude-code/skills/next-up/SKILL.md` (frontmatter + intro +
Conventions + Step 1).

- [ ] **Step 1:** Rewrite intro: title "Next up"; one-line purpose (what the
      next sessions work on, decided with the user, then handed off); "replace
      reading with answering" rule; drop the Read-only paragraph, replace with:
      writes happen only on the user's yes, in the queue step. Add: no beads →
      say so and stop (Review Focus 5). Language rule kept.
- [ ] **Step 2:** Conventions: delete the "union of children's labels" bullet's
      reliance on an epic label (keep label overlap = area overlap);
      epic-status rule: mixed closed/open children with none started in the
      epic's own work → ask, not forced in_progress. Keep task/decision/spike
      and sweeping-epic bullets.
- [ ] **Step 3:** Step 1 Gather: keep bd reads and gotchas; add PR-less
      detection (memory or non-GitHub `origin` → no `gh`, landed =
      `origin/<default>` only, unmerged branches no bead points at:
      `git branch -r --no-merged origin/<default>`). Say "silent: print
      nothing".
- [ ] **Step 4: Verify**
      `grep -nE "Read-only|carries the label|theme" claude-code/skills/next-up/SKILL.md`
      → no hits.

### Task 2: next-up — fix list, decide, queue

**Files:** Modify `claude-code/skills/next-up/SKILL.md` (new Steps 2–4).

- [ ] **Step 1:** Step 2 Fix list: fix kinds table from the design (close,
      reopen, epic status, collision, ordering hint → `bd dep add`, retype,
      stale in_progress, landed worktree → `git worktree remove`, orphan branch
      → file bead / leave). Strict list format with the example block.
      Ordering: deciding fixes first; linked ones asked together (≤4 per call).
      Clean tracker → one line, go to Step 5 (Review Focus 1).
- [ ] **Step 2:** Step 3 Decide: first question "Apply all" (Recommended) · "Go
      one by one". One by one: Markdown block shape (bold
      `Fix 2/4 — <id> "<title>"`, bullets What / Why / Command), then card
      Apply · Skip · Other = change; collisions: fold / hybrid / keep both,
      recommended first. Changed fix re-proposed. Moot fix dropped/rewritten
      with one line.
- [ ] **Step 3:** Step 4 Run: after last answer, in order, skill runs each
      command (`< /dev/null`); failure → note, continue; `bd dolt push` when a
      Dolt remote exists; summary line
      `<n> applied, <m> skipped[, <k> failed]`.
- [ ] **Step 4: Verify**
      `grep -nE "Apply all|Go one by one|applied, .* skipped|dolt push" claude-code/skills/next-up/SKILL.md`
      → hits for each.

### Task 3: next-up — next-up list, hand-off, common mistakes

**Files:** Modify `claude-code/skills/next-up/SKILL.md` (Steps 5–6 + Common
mistakes).

- [ ] **Step 1:** Step 5 Next up: top 5, `<n>. <id> "<title>" — <why>`; ranking
      rules (urgent → "stop X, do Y" in its why; started epics first; most-
      unblocking chain; task = shaping). Fewer than 5 → what exists; none → say
      so, stop (Review Focus 2).
- [ ] **Step 2:** Step 6 Hand off: card "Start #1" (Recommended) · "Start
      another" (follow-up card with #2–#5) · "Not now". Desktop:
      `start_session` `initiation: "user_asked"`, `context: "fresh"`,
      `use_worktree: true`, `background` + `prompt` (template block: id +
      title, context — what, waits on / unblocks, decisions this run — process:
      `/using-superpowers`, `bd update <id> --claim`, repo's commit/ship flow).
      Then `set_remote_control` (new id, true); refused for "no turn yet" →
      retry when its first-turn note arrives. Refused start or no tool → print
      prompt in a `text` code block (Review Focus 3, 4). Never start the work
      here; never retitle.
- [ ] **Step 3:** Common mistakes rewritten for the new flow (running anything
      between questions, bare ids, links in cards, emoji/progress lines, gh in
      PR-less repo, forcing in_progress on mixed epics, starting the work here,
      retitling).
- [ ] **Step 4: Verify**
      `grep -nE "user_asked|set_remote_control|use_worktree|using-superpowers|Not now" claude-code/skills/next-up/SKILL.md`
      → hits for each; `make check` passes.
- [ ] **Step 5: Commit**
      `feat(next-up): decide fixes one by one, then hand off` (refs kxa-ugx).

### Task 4: close — next-up offer and detach before archive

**Files:** Modify `claude-code/skills/close/SKILL.md` step 2b; `CHANGELOG.md`.

- [ ] **Step 1:** Top of 2b, before the mode check: AskUserQuestion "Run
      /kix:next-up now?" — "Run it" (Recommended) · "Skip"; yes → run the
      skill, then continue 2b.
- [ ] **Step 2:** In 2b, right before `archive_session`: list linked sessions
      (`list_sessions` `linked: true`), `detach_session` each whose `startedBy`
      is this session; no question; one line naming them. Add one Common
      mistakes line (archiving with side sessions still attached).
- [ ] **Step 3:** CHANGELOG `[Unreleased]`: Changed — next-up walk + hand-off;
      close offers next-up and detaches side sessions before archiving.
- [ ] **Step 4: Verify**
      `grep -nE "kix:next-up|detach_session" claude-code/skills/close/SKILL.md`
      → hits; `make check` passes.
- [ ] **Step 5: Commit**
      `feat(close): offer next-up and detach side sessions before archiving`
      (refs kxa-ugx).
