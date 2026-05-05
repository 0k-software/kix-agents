---
id: 13
title: `/close` skill for Requests, Pitches, and Tasks
type: request
linked_to: null
created_by: kelvin.stinghen@me.com
created_at: 2026-05-05T14:51:47Z
updated_at: 2026-05-05T14:51:47Z
---

Add a `/close` skill that closes Requests, Pitches, and Tasks. Counterpart to
the create/link skills — handles the third triage outcome (closed) for
Requests, and the terminal state (`shipped` for Pitches, `done` for Tasks) for
the other entity types.

Open questions: input shape (id alone, or id + reason?); whether the rules
differ enough between entity types to warrant separate `/close-request`,
`/close-pitch`, `/close-task` skills, or one polymorphic `/close` that infers
the type from the id.
