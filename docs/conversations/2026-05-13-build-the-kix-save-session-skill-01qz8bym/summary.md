---
saved_at: 2026-05-13T01:02:52Z
session_id: cse_01Qz8ByMxYiCeBo6KQz2Ez5L
raw_transcript: raw.jsonl.gz
---

# Build the kix:save-session skill

## Goal

Create `/kix:save-session [owner/repo]` — archive a Claude session into a GitHub
repo and open (or update) a PR for it — plus the beads issue tracking it.

## What happened

- Filed beads issue `kxa-bpt` after clarifying four choices: Anthropic API
  conversation fetch, a `kix:`-namespaced skill, a `docs/conversations/`
  date-slug layout, infer-and-confirm repo resolution.
- Implemented `claude-code/skills/save-session/SKILL.md` plus a `CHANGELOG`
  entry; opened **PR #34**.
- Worked through review (@kelvinst, several rounds): resolve a bare repo arg by
  searching repo names (don't guess the owner); runtime-agnostic (chat sessions
  too); artifacts under `docs/conversations/`; drop Claude-Code-only
  assumptions; render the session verbatim — never collapse tool calls; name
  the `caveman:caveman` skill explicitly in the summary step.
- Iterated heavily on the artifact design — landing on:
  - one folder per session, `docs/conversations/<stem>/`, keyed by the session
    id so a re-save overwrites in place;
  - `summary.md` every time (via `caveman` if available, else summarized
    directly);
  - the conversation stored as `raw.jsonl.gz` — the largest Claude Code project
    transcript, gzipped (considered a rendered `raw.md` — ~6× smaller — but a
    render costs LLM tokens and a gzipped raw `.jsonl` stays searchable via
    `zcat | grep` and is the true raw record; repo-size handled by moving old
    transcripts to a backup repo if it ever matters); `raw.md` kept only as the
    no-transcript chat-session fallback;
  - hosted-sandbox handling: each web turn is a fresh `claude --resume` that
    copies the prior transcript forward and appends, so the project dir holds
    many `.jsonl` files — the largest is the complete cumulative transcript
    (append-only across compactions, so more complete than the live context);
    `CLAUDE_CODE_REMOTE` flags the sandbox and `CLAUDE_CODE_REMOTE_SESSION_ID`
    is the only id stable across turns, so it's the re-save key.
- Added the **work-branch behavior**: when run from Claude Code on a feature
  branch (the branch holding this session's work), the archive is committed
  straight onto that branch so it rides along with that branch's PR — leaving
  that PR's title/body alone — rather than getting its own; a standalone
  `claude/save-session-<stem>` branch + PR is created only on the default branch
  or when there's no checkout (a chat session).
- Walked the user through testing the skill in Claude Code and claude.ai chat;
  dry-ran it (PR #41, since closed; PR #43 as a standalone-save demo) and
  rebased PR #34's branch onto `main` more than once.
- This commit: a work-branch save of this conversation onto PR #34's branch —
  `raw.jsonl.gz` is the gzipped cumulative transcript (`gunzip` to read).

## Open follow-ups

- A gzipped `.jsonl` isn't directly searchable/rendered in the GitHub UI —
  clone + `zcat | grep` (acceptable trade vs. a multi-MB raw `.jsonl`).
- When there's no transcript file (a plain chat session) `raw.md` is only as
  complete as the in-context view — partial if older turns were compacted out.
- Plan for scale: prune old archives to just `summary.md` (spec/plan files cover
  them too) or move raw transcripts to a separate backup repo before the repo
  nears GitHub's 1 GB nudge.
- PR #43 duplicates this session's archive (under a `2026-05-12-…` stem) — close
  it once this lands.
- `kxa-bpt` stays in progress until PR #34 merges.
