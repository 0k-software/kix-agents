---
saved_at: 2026-05-12T17:48:10Z
session_id: 0ea9dd49-37dd-40d2-b58f-f2f4f460de74
raw_transcript: raw.jsonl
---

# Build the kix:save-session skill

## Goal

Create `/kix:save-session [owner/repo]` — archive a Claude session into a
GitHub repo and open a PR for it — plus the beads issue tracking it.

## What happened

- Filed beads issue `kxa-bpt` after clarifying four choices: Anthropic API
  conversation fetch, a `kix:`-namespaced skill, a `docs/conversations/`
  date-slug layout, and infer-and-confirm repo resolution.
- Implemented `claude-code/skills/save-session/SKILL.md` plus a `CHANGELOG`
  `[Unreleased]` entry; opened PR #34.
- Addressed several rounds of review (@kelvinst):
  - resolve a bare repo arg by searching repo names, not guessing the owner
    from the local git remote;
  - make the skill runtime-agnostic (Claude chat sessions as well as Claude
    Code);
  - store artifacts under `docs/conversations/`;
  - drop Claude-Code-only assumptions (shell, checked-out repo, transcript
    files);
  - render the session verbatim — never collapse tool calls;
  - name the `caveman:caveman` skill explicitly in the summary step.
- Redesigned artifact handling: transcript present → commit it verbatim as
  `raw.jsonl` plus a `summary.md` (via the `caveman` summarizer if available,
  else summarized directly); no transcript → a verbatim `raw.md` render fetched
  via the host's conversation tool / Anthropic API.
- Keyed archives by session id so re-saving the same session updates the same
  folder, branch, and PR instead of duplicating; one folder per session
  (`docs/conversations/<stem>/`) with fixed inner names.
- PR-body links: `Conversation Summary: …/summary.md` +
  `Raw transcript: …/raw.jsonl` (or `…/raw.md` on the fallback path).
- Documented the git-checkout-preferred path for multi-MB transcripts the
  GitHub Contents API can't take via a tool call.
- Walked the user through testing the skill in both Claude Code and claude.ai
  chat.
- Dry-ran the skill against this conversation (PR #41, since closed) and
  rebased PR #34's branch onto `main` more than once, resolving
  `.beads/issues.jsonl` and `CHANGELOG.md` conflicts.
- Ran the skill again to produce this archive as a fresh PR.

## Open follow-ups

- No public Anthropic API exists to fetch an arbitrary past session, so the
  rendered-fallback path depends on the host exposing a conversation tool; the
  Claude Code transcript file is the only concrete source today.
- Claude Code splits resumed sessions into separate `.jsonl` files, so this
  archive captures only the active segment, not the whole multi-resume thread.
- Large transcripts (~1.7 MB here) are committed via a local git checkout
  branched from `main`, not the Contents API.
- `kxa-bpt` stays in progress until PR #34 merges.
