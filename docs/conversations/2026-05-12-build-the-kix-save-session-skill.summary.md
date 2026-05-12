---
saved_at: 2026-05-12T17:02:32Z
session_id: 5ebb5f57-e7a3-4cfa-b1dc-c691d23ce8a2
raw_transcript: 2026-05-12-build-the-kix-save-session-skill.jsonl
---

# Build the kix:save-session skill

## Goal

Create a `/kix:save-session [owner/repo]` skill that archives a Claude session
into a GitHub repo and opens a PR for it, plus the beads issue tracking the
work.

## What happened

- Filed beads issue `kxa-bpt` capturing the skill's design and acceptance
  criteria, after clarifying four choices with the user: Anthropic API
  conversation fetch, a `kix:`-namespaced skill, a `docs/conversations/`
  date-slug layout, and infer-and-confirm repo resolution.
- Implemented `claude-code/skills/save-session/SKILL.md` plus a `CHANGELOG`
  `[Unreleased]` entry; opened PR #34.
- Addressed five review comments from @kelvinst:
  - resolve a bare repo arg by searching repo names instead of guessing the
    owner from the local git remote;
  - make the skill runtime-agnostic so it works from Claude chat sessions as
    well as Claude Code;
  - store artifacts under `docs/conversations/`;
  - drop Claude-Code-only assumptions (shell, checked-out repo, transcript
    files);
  - render the session verbatim — never collapse tool calls.
- Redesigned the artifact handling per the user: when a local transcript
  `.jsonl` exists, commit it verbatim and add a separate `.summary.md` (via the
  `caveman` summarizer if available, otherwise summarized directly); otherwise
  fall back to a verbatim `.raw.md` render.
- Walked the user through how to test the skill in both Claude Code and
  claude.ai chat.
- Rebased the branch onto `main` (which had picked up the caveman-plugin work),
  resolving `.beads/issues.jsonl` and `CHANGELOG.md` conflicts; the branch
  force-pushed cleanly.
- Ran the skill against this conversation to produce this archive.

## Open follow-ups

- No public Anthropic API exists to fetch an arbitrary past session, so the
  rendered-fallback path depends on the host exposing a conversation tool; the
  Claude Code transcript file is the only concrete source today.
- Large transcripts (this one is ~1.2 MB) can't be round-tripped through the
  GitHub Contents API plus the agent context, so this archive was committed via
  a local git checkout branched from `main`. The skill should prefer git
  plumbing / a local checkout when one is available.
- `kxa-bpt` stays in progress until PR #34 merges.
