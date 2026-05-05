---
id: 12
title: link-pitch and link-task skills for existing entities
type: request
linked_to: null
created_by: kelvin.stinghen@me.com
created_at: 2026-05-05T14:50:57Z
updated_at: 2026-05-05T14:50:57Z
---

Add `link-pitch` and `link-task` skills that link an existing Request to an
existing Pitch or Task — counterparts to `create-pitch` / `create-task`, which
create a new entity from a Request. Useful when a Request turns out to be the
same problem as a Pitch/Task already in flight, or when grouping late-arriving
Requests under an existing initiative.

Inputs roughly: a Request id and a target Pitch/Task id. The skill updates the
Request's `outcome: linked` and `linked_to: <target_id>`, and (for Pitches)
appends the Request id to the target's `requests:` front-matter list. Mirror
the validation rules from `create-pitch` (already-linked warning, missing-id
abort).
