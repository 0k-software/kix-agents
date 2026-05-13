---
saved_at: 2026-05-13T00:39:00Z
session_id: cse_01Qz8ByMxYiCeBo6KQz2Ez5L
source: "transcript: ec1fec55-ca74-4fc1-a14d-6bd4963167fe.jsonl"
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
  in place; `summary.md` always; and the conversation stored as **`raw.md`** —
  a markdown render of the largest Claude Code project transcript (`.jsonl`),
  keeping every user/assistant turn, tool call, and tool result but shedding the
  JSON envelope, per-entry metadata, and repeated `<system-reminder>` / hook
  boilerplate. (Tried the raw `.jsonl`, then a gzipped `.jsonl.gz`, first; the
  rendered `.md` is ~6× smaller than the raw `.jsonl` and is readable/greppable
  in the GitHub UI, so no gzip blobs and no Git LFS at any realistic volume —
  ~2,500 of these sessions to a 1 GB repo.)
- Sorted out the hosted-sandbox case: each web turn is a fresh `claude --resume`
  that copies the prior transcript forward and appends, so the project dir holds
  many `.jsonl` files — the largest is the complete cumulative transcript
  (append-only across context compactions). `CLAUDE_CODE_REMOTE` identifies the
  sandbox; `CLAUDE_CODE_REMOTE_SESSION_ID` is the only id stable across turns,
  so it's the re-save key.
- Walked the user through testing the skill in Claude Code and claude.ai chat.
- Dry-ran the skill (PR #41, since closed) and rebased PR #34's branch onto
  `main` more than once, resolving `.beads/issues.jsonl` and `CHANGELOG.md`
  conflicts.
- This PR: ran the skill against this conversation; `raw.md` here is the
  rendered transcript.

## Open follow-ups

- No public Anthropic API exists to fetch an arbitrary past session, so when
  there's no transcript file (a plain chat session) `raw.md` is only as complete
  as the in-context view — partial if older turns were compacted out.
- Older archives can later be pruned to just `summary.md` (spec/plan files cover
  them too), or raw transcripts moved to a separate backup repo / GitHub Release
  assets if volume ever warrants it.
- `kxa-bpt` stays in progress until PR #34 merges.
