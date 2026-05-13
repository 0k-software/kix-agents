---
saved_at: 2026-05-13T00:45:00Z
session_id: cse_01Qz8ByMxYiCeBo6KQz2Ez5L
raw_transcript: raw.jsonl.gz
---

# Build the kix:save-session skill

## Goal

Create `/kix:save-session [owner/repo]` — archive a Claude session into a GitHub
repo and open a PR for it — plus the beads issue tracking it.

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
- Iterated heavily on the artifact design — landing on: one folder per session
  (`docs/conversations/<stem>/`) keyed by the session id so re-saves overwrite
  in place; a `summary.md` every time; and the conversation stored as
  **`raw.jsonl.gz`** — the largest Claude Code project transcript, gzipped
  (`raw.md` is kept only as the no-transcript chat-session fallback). Considered
  committing a rendered `raw.md` instead — ~6× smaller — but a render costs LLM
  tokens to produce and a gzipped raw `.jsonl` stays fully searchable (`zcat |
  grep`) and is the true raw record; the repo-size concern (~1 GB after a few
  thousand saves) is handled by moving old transcripts to a backup repo if it
  ever matters.
- Sorted out the hosted-sandbox case: each web turn is a fresh `claude --resume`
  that copies the prior transcript forward and appends, so the project dir holds
  many `.jsonl` files — the largest is the complete cumulative transcript
  (append-only across context compactions, so more complete than the live
  context). `CLAUDE_CODE_REMOTE` identifies the sandbox;
  `CLAUDE_CODE_REMOTE_SESSION_ID` is the only id stable across turns, so it's
  the re-save key.
- Walked the user through testing the skill in Claude Code and claude.ai chat.
- Dry-ran the skill (PR #41, since closed) and rebased PR #34's branch onto
  `main` more than once, resolving `.beads/issues.jsonl` and `CHANGELOG.md`
  conflicts.
- This PR: ran the skill against this conversation; `raw.jsonl.gz` here is the
  gzipped cumulative transcript (`gunzip` to read).

## Open follow-ups

- A gzipped `.jsonl` isn't directly searchable/rendered in the GitHub UI —
  clone + `zcat | grep` (acceptable trade vs. a multi-MB raw `.jsonl`).
- When there's no transcript file (a plain chat session) `raw.md` is only as
  complete as the in-context view — partial if older turns were compacted out.
- Plan for scale: prune old archives to just `summary.md` (spec/plan files cover
  them too), or move raw transcripts to a separate backup repo, before the main
  repo gets close to GitHub's 1 GB nudge.
- `kxa-bpt` stays in progress until PR #34 merges.
