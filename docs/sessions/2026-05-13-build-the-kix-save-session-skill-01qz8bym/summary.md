---
saved_at: 2026-05-13T10:38:41Z
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

## Open follow-ups

- Gzipped `.jsonl` isn't directly rendered/searchable in the GitHub UI — clone
  + `zcat | grep`. Acceptable trade.
- At scale (~few thousand sessions ≈ 1 GB), prune older archives to just
  `summary.md` or move raw transcripts to a separate backup repo. No Git LFS
  needed at any realistic volume.
- PR #43 (standalone-save demo) still uses the old `docs/conversations/` path
  and predates the latest changes — close or refresh it.
- `kxa-bpt` stays in progress until PR #34 merges.
