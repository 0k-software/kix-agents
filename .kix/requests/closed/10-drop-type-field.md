---
id: 10
linked_to: null
created_by: kelvin.stinghen@me.com
created_at: 2026-05-05T14:00:15Z
updated_at: 2026-05-06T03:48:48Z
---

# Drop the type field from Request front-matter

The `type: request` field in Request front-matter is redundant — files under
`.kix/requests/` are Requests by location. Remove the field from the schema and
from the `/kix:request` skill template.

## Resolution

Implemented on branch `claude/implement-feature-10-LhGDH`. Removed
`type: request` from the `kix:create-request` skill template and stripped the
field from existing Request files. PR pending.
