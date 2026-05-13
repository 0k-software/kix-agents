---
saved_at: 2026-05-13T10:45:00Z
session_id: cse_01Qz8ByMxYiCeBo6KQz2Ez5L
raw_transcript: raw.jsonl.gz
---

# Build the kix:save-session skill

## Goal

Ship `/kix:save-session [owner/repo] [--no-commit]` — archive a Claude session
(chat or Claude Code) into `docs/sessions/<stem>/` in a target repo as
`raw.jsonl.gz` (the gzipped Claude Code transcript) + an append-only
`summary.md`, opening a PR for it or riding along on the current branch's PR.
Plus wire `kix:commit` to bundle the archive into every commit via the
`--no-commit` mode.

## 2026-05-13T10:38Z — update

- Filed beads issue `kxa-bpt` after clarifying four design choices.
- Built the skill at `claude-code/skills/save-session/SKILL.md`; worked through
  several rounds of review (search-by-repo-name, runtime-agnostic, drop
  Claude-Code-only assumptions, render the session verbatim, name
  `caveman:caveman` explicitly).
- Settled the artifact design:
  - one folder per session, `docs/sessions/<stem>/`, keyed by the session id
    (`CLAUDE_CODE_REMOTE_SESSION_ID` in a hosted sandbox — only id stable across
    turns) so re-saves overwrite in place;
  - `raw.jsonl.gz` = the **largest** `.jsonl` in the Claude Code project dir,
    gzipped (~4–5×); each `claude --resume` copies the prior transcript forward
    and appends, so the biggest file is the complete cumulative transcript —
    more complete than the live in-context view after compactions; raw
    `.jsonl.gz` stays searchable via `zcat | grep`;
  - `summary.md` is **append-only** — first save creates a Goal paragraph + a
    `## <timestamp> — update` section; each re-save appends a new update section
    rather than rewriting, preserving step-by-step history and avoiding LLM
    drift in old content;
  - `raw.md` only as the no-transcript fallback (a plain chat session).
- **Destination logic** in Claude Code: on a feature branch (≠ default), commit
  the archive straight onto that branch — rides along with its PR; on the
  default branch (protected) or no checkout (chat session) → standalone
  `claude/save-session-<stem>` branch + new PR.
- **`--no-commit`** mode: stage-only (write archive + `git add`, no
  commit/push/PR — caller commits).
- **`kix:commit`** Step 1 collapsed to one bullet: invoke `/kix:save-session
  --no-commit`. Placement is *after* staging so in the mixed-index case the
  archive isn't swept into the auto-stash. Session-scoped ≠ commit-scoped — a
  session split across multiple commits carries an updated archive on each,
  with the last commit holding the complete view.
- **`.gitattributes`** marks `docs/sessions/**/raw.jsonl.gz binary` so diffs
  stay clean. **`.prettierignore`** ignores `docs/sessions/`.
- Renamed `docs/conversations/` → `docs/sessions/` repo-wide (the skill stays
  `kix:save-session`).
- This archive itself was regenerated from scratch to demonstrate the
  first-save output shape — replaces the prior hand-written `summary.md`.

## 2026-05-13T10:43Z — update

- Refined the `summary.md` re-save protocol: new `## <timestamp> — update`
  sections are inserted **before** the `## Open Questions` section (updates in
  time order, Open Questions stays the tail).
- Renamed the trailing section from `## Open follow-ups` → **`## Open
  Questions`**, formatted as a GitHub-style checklist (`- [ ]` / `- [x]`).
  When a question gets answered, flip it to `- [x]` and add the resolution as
  a sub-item underneath — keep the question line for the trail; never delete
  it. New questions surfaced this turn go in as fresh `- [ ]` items, with the
  discussion captured in the update section above.
- Updated `claude-code/skills/save-session/SKILL.md` `### Summary` to spec all
  of the above.

## 2026-05-13T10:45Z — update

- Added a trailing **`## Action Items`** checklist section to the summary
  template — `- [ ]` / `- [x]` items for things to remember to do (close a PR,
  follow up on a beads issue, ship a follow-up, …). When done, flip to `[x]`
  and add a sub-item with the reference (beads id, PR #N, commit SHA); if a
  beads issue is filed, mark `[x]` with the beads id and let the tracker carry
  it from there. Section order: Goal → updates (time order) → Open Questions
  → Action Items (new tail).
- Updated `claude-code/skills/save-session/SKILL.md` `### Summary` to spec it.
- Migrated the two action-style items out of `## Open Questions` into the new
  `## Action Items` section (closing PR #43; closing `kxa-bpt` on merge).

## Open Questions

- [x] Is a gzipped `.jsonl` (not directly rendered/searchable in the GitHub
      UI) acceptable as the archive format?
  - **Resolved:** yes — clone + `zcat | grep` is the accepted trade-off; the
    gz blob keeps the repo small and is the true raw record.
- [ ] At scale (~few thousand sessions ≈ 1 GB), prune older archives to just
      `summary.md` or move raw transcripts to a separate backup repo?

## Action Items

- [ ] Close or refresh PR #43 (standalone-save demo on the old
      `docs/conversations/` path).
- [ ] Close `kxa-bpt` once PR #34 merges.
