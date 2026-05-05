---
id: 3
title: Import `commit` skill from Kata
type: request
linked_to: null
created_by: kelvin.stinghen@me.com
created_at: 2026-05-05T12:50:36Z
updated_at: 2026-05-05T13:43:57Z
---

Import the `commit` skill from Kata into Kix.

## Outcome

Closed — implemented as `agents/claude-code/commands/commit.md`. The body was
preserved from the Kata skill and the frontmatter adapted to Kix's
slash-command format. Several refinements were layered on during the same
session (index-aware staging, retry-with-progress, fenced-code rendering,
ask-user failure flow, resume-from-state).

Commits:

- [`f87a1d7`](https://github.com/0k-software/kix/commit/f87a1d7) — feat: ship
  `/commit` skill imported from Kata
- [`4537db3`](https://github.com/0k-software/kix/commit/4537db3) — feat: harden
  `/commit` skill failure path and refine Request 4
- [`79e8f9b`](https://github.com/0k-software/kix/commit/79e8f9b) — feat: add
  resume + ask-user state to `/commit` failure path
