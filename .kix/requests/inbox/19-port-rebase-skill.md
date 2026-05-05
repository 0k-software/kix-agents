---
id: 19
title: Port rebase skill from kata
type: request
linked_to: null
created_by: noreply@anthropic.com
created_at: 2026-05-05T19:36:01Z
updated_at: 2026-05-05T19:36:01Z
---

Copy the `/kata:rebase` skill from `0k-software/kata`
(`skills/rebase/SKILL.md`) into kix-agents as a `/kix:rebase` command. The
skill rebases the current branch onto a target branch, handling conflicts
(interactive by default, auto-resolved with the `!` variant) and pre-commit
hook failures.
