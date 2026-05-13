---
saved_at: 2026-05-13T00:05:28Z
session_id: cse_01Qz8ByMxYiCeBo6KQz2Ez5L
raw_transcript: raw.jsonl
---

# Build the kix:save-session skill

## Goal

Create `/kix:save-session [owner/repo]` — archive a Claude session into a
GitHub repo and open a PR for it — plus the beads issue tracking it.

## What happened

- Filed beads issue `kxa-bpt` after clarifying four choices: Anthropic API
  conversation fetch, a `kix:`-namespaced skill, a `docs/conversations/`
  date-slug layout, infer-and-confirm repo resolution.
- Implemented `claude-code/skills/save-session/SKILL.md` plus a `CHANGELOG`
  `[Unreleased]` entry; opened **PR #34**.
- Worked through review (@kelvinst, several rounds): resolve a bare repo arg by
  searching repo names (don't guess the owner); runtime-agnostic (chat sessions
  too); artifacts under `docs/conversations/`; drop Claude-Code-only
  assumptions; render the session verbatim — never collapse tool calls; name
  the `caveman:caveman` skill explicitly in the summary step.
- Iterated on the artifact design:
  - one folder per session, `docs/conversations/<stem>/`, with fixed inner
    names;
  - the raw transcript file committed byte-for-byte as `raw.jsonl`; a chat
    session with no transcript renders the conversation to `raw.md` instead;
  - a `summary.md` written every time (via `caveman` if available, else
    directly);
  - archives keyed by session id so re-saving updates the same folder, branch,
    and PR in place;
  - PR-body links: `Conversation Summary: …/summary.md` +
    `Raw transcript: …/raw.jsonl` (or `…/raw.md`).
- Sorted out the hosted-sandbox case: each web turn is a fresh
  `claude --resume` that copies the prior transcript forward and appends, so
  the Claude Code project dir holds many `.jsonl` files for one conversation —
  the **largest** one is the complete cumulative transcript.
  `CLAUDE_CODE_REMOTE` identifies the sandbox; `CLAUDE_CODE_REMOTE_SESSION_ID`
  is the only id stable across turns, so it's the re-save key.
- Walked the user through testing the skill in Claude Code and claude.ai chat.
- Dry-ran the skill (PR #41, since closed) and rebased PR #34's branch onto
  `main` more than once, resolving `.beads/issues.jsonl` and `CHANGELOG.md`
  conflicts.
- This PR: ran the skill against this conversation, then replaced an earlier
  per-turn fragment / hand-rendered `raw.md` with `raw.jsonl` = the largest
  project transcript (the full verbatim record — every turn, tool call, tool
  result, system block).

## Open follow-ups

- No public Anthropic API exists to fetch an arbitrary past session, so the
  `raw.md` rendered fallback is only as complete as the host's conversation
  tool or the in-context (post-compaction) view; the project `.jsonl` is the
  real verbatim source.
- `kxa-bpt` stays in progress until PR #34 merges.
