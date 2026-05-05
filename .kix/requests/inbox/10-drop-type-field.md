---
id: 10
title: Drop the type field from Request front-matter
type: request
linked_to: null
created_by: kelvin.stinghen@me.com
created_at: 2026-05-05T14:00:15Z
updated_at: 2026-05-05T14:00:15Z
---

The `type: request` field in Request front-matter is redundant — files under
`.kix/requests/` are Requests by location. Remove the field from the schema and
from the `/kix:request` skill template.
