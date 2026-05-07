---
id: 13
linked_to: null
created_by: kelvin.stinghen@me.com
created_at: 2026-05-05T14:51:47Z
updated_at: 2026-05-06T03:49:59Z
---

# `/close` skill for Requests, Pitches, and Tasks

Add a `/close` skill that closes Requests, Pitches, and Tasks. Counterpart to
the create/link skills — handles the third triage outcome (closed) for
Requests, and the terminal state (`shipped` for Pitches, `done` for Tasks) for
the other entity types.

Open questions: input shape (id alone, or id + reason?); whether the rules
differ enough between entity types to warrant separate `/close-request`,
`/close-pitch`, `/close-task` skills, or one polymorphic `/close` that infers
the type from the id.

## Resolution

Implemented on branch `claude/implement-feature-13-Noa1M`. The skill landed as
`kix:cancel` rather than `kix:close` after PR review — it turned out the
operation is fundamentally about cancellation (discarding work), not about
moving to a finished terminal state. `/cancel <id> [reason]`
(`claude-code/commands/cancel.md`) identifies the entity by globbing
`.kix/{requests,pitches/<id>-*/,pitches/*/tasks/<id>-*/}` and applies the
type-specific cancellation: Requests move to `.kix/requests/closed/` with the
reason in the `## Resolution` body; Pitches and Tasks get a `cancelled_at`
timestamp added to front-matter while `phase:` is preserved (so the phase the
work was in at cancellation is part of the record). Cancellation is orthogonal
to phase progression. No cascade on linked Requests when a Pitch is cancelled —
they are reported in the confirmation so the user can decide. PR:
https://github.com/0k-software/kix-agents/pull/17
