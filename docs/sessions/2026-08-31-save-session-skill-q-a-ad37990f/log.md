---
saved_at: 2026-08-31T17:48:32Z
session_id: ad37990f-4afc-4dac-a383-d90d374ea195
transcript: transcript.jsonl.gz
---

# Q&A: what /kix:save-session is and does

> **Source:**
> `~/.claude/projects/-Users-kelvinstinghen-Developer-worktrees-kix-agents-kicks-commit-message-skill-3b78aa/ad37990f-4afc-4dac-a383-d90d374ea195.jsonl`
> (local; not a public link).

## Goal

Answer what the save-session skill is called, what it does, and why it needs
GitHub write tools — then archive the session with the skill itself. No code
changed.

## 2026-08-31 — update

_(Section body compressed with the `caveman:caveman` skill — mode was active
for the whole session.)_

- **Q: skill name?** Answer: `anthropic-skills:save-session`. Located by
  `find ~/.claude -name SKILL.md -path "*save-session*"` — three hits: kix
  plugin cache `0.2.4`, kix marketplace checkout, and a session-plugin copy
  under `~/Library/Application Support/Claude/local-agent-mode-sessions/`.
- **Q: "isn't there a skill here?"** (asked mid-turn). Yes — this repo owns the
  canonical one at
  [`claude-code/skills/save-session/SKILL.md`](../../../claude-code/skills/save-session/SKILL.md),
  surfacing as `/kix:save-session`. The `anthropic-skills:save-session` entry
  in the skill list is the same content served from the session-plugin copy.
  Confirmed: the session-plugin body itself says "Invoked as
  `/kix:save-session`".
- **What it does** (summarized from SKILL.md): archives session as
  `docs/sessions/<stem>/{log.md, transcript.jsonl.gz}`; feature branch →
  commits onto that branch and rides its PR; default branch → standalone
  `claude/save-session-<stem>` branch + PR; `--no-commit` = stage-only for
  `kix:commit`; re-save overwrites in place keyed on session id; chat session →
  handoff mode, nothing pushed.
- **Q: why GitHub writes?** Answer: only the standalone path needs them. Three
  reasons git alone can't cover — (1) opening/updating a PR has no git
  equivalent (`create_pull_request` / `update_pull_request`, SKILL.md:366);
  (2) re-save lookup reads `docs/sessions/<stem>/` and the branch on the remote
  without a fetch (`get_file_contents` / `list_pull_requests`, SKILL.md:245);
  (3) writing with no checkout at all (hosted sandbox) via
  `push_files` / `create_or_update_file` (SKILL.md:284). Work-branch save is
  plain `git add`/`commit`/`push` (SKILL.md:266).
- **`/kix:save-session` invocation failed** — host reported
  `Unknown command: /kix:save-session`; it resolved to
  `/anthropic-skills:save-session` instead. Same skill body, different
  namespace. Worth noting as a naming/registration wrinkle, not a bug in the
  skill.
- **This save.** Work-branch save: branch `save-session-skill-name-5c6a21`
  (≠ `main`), clean tree, zero commits vs `origin/main`, no upstream. Transcript
  picked by session-id filename (183 KB, today) — **not** the largest file in
  the project dir (774 KB, Aug 29), which belongs to a different session; the
  "largest file" rule in Step 2 targets hosted sandboxes where `claude --resume`
  copies the transcript forward, which does not apply here.
  `docs/sessions/` is already in `.prettierignore`, so no Prettier change
  needed.

## Open Questions

- [ ] Why does `/kix:save-session` not resolve while
      `/anthropic-skills:save-session` does? Plugin namespace/registration
      mismatch between the marketplace checkout and the session-plugin copy.
- [ ] Should Step 2's "pick the largest `.jsonl`" rule be scoped to hosted
      sandboxes only? Locally it selects the wrong session's transcript when the
      project dir holds several.

## Action Items

- [ ] File a beads issue for the `/kix:save-session` command-name resolution
      failure if it reproduces.
- [ ] Consider tightening SKILL.md Step 2 transcript selection: prefer the file
      named after the session id, fall back to largest only when
      `CLAUDE_CODE_REMOTE` is truthy.
