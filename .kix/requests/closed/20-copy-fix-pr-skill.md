---
id: 20
linked_to: null
created_by: noreply@anthropic.com
created_at: 2026-05-05T23:45:56Z
updated_at: 2026-05-06T02:25:55Z
---

# Copy /fix-pr skill from kata repo with /fix and /address aliases

Copy the `/fix-pr` skill from the kata repository under the same organization.
The `/fix-issue` skill is not needed. Set up `/fix`, `/address`, and
`/address-pr` as aliases for `/fix-pr`.

## Resolution

Implemented on branch `claude/implement-feature-20-2lcU9`. Ported
`skills/fix-pr/SKILL.md` from `0k-software/kata` into
`claude-code/commands/fix-pr.md`, with frontmatter adapted from kata's
`name`/`description` shape to the `description`/`argument-hint` shape used by
the kix plugin and `/kata:` references renamed to `/kix:`. Added three alias
commands (`fix.md`, `address.md`, `address-pr.md`) delegating to `kix:fix-pr`,
mirroring the alias pattern used for `kix:create-request`.

Shipped in:

- f957c2e — feat(kix): add /kix:fix-pr command, ported from kata
- 7a0ba72 — feat(kix): add /kix:fix, /kix:address, /kix:address-pr aliases for
  fix-pr
- ce62906 — docs: changelog entry for fix-pr and aliases

PR: https://github.com/0k-software/kix-agents/pull/13
