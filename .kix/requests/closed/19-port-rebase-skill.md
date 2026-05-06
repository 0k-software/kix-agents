---
id: 19
linked_to: null
created_by: noreply@anthropic.com
created_at: 2026-05-05T19:36:01Z
updated_at: 2026-05-05T19:38:00Z
---

# Port rebase skill from kata

Copy the `/kata:rebase` skill from `0k-software/kata`
(`skills/rebase/SKILL.md`) into kix-agents as a `/kix:rebase` command. The
skill rebases the current branch onto a target branch, handling conflicts
(interactive by default, auto-resolved with the `!` variant) and pre-commit
hook failures.

## Resolution

Shipped in:

- [aa9385e](https://github.com/0k-software/kix-agents/commit/aa9385e) —
  feat(kix): add /kix:rebase command, ported from kata

The body was ported verbatim. Frontmatter was adapted from kata's
`name`/`description` shape to kix-agents' `description`/`argument-hint` shape,
and `/kata:rebase` references were renamed to `/kix:rebase`.
