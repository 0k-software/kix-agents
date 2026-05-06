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

Implemented on branch `claude/implement-feature-13-Noa1M` as a single
polymorphic `kix:close` skill (`claude-code/commands/close.md`). `/close <id>`
identifies the entity by globbing `.kix/{requests,pitches,tasks}/` and applies
the type-specific terminal state: moves Requests to `closed/`, sets Pitches to
`phase: shipped`, sets Tasks to `phase: done`. Optional `[reason]` text is
captured into a `## Resolution` section. No cascade on linked Requests when a
Pitch ships — they are reported in the confirmation so the user can decide. PR:
PR pending.
