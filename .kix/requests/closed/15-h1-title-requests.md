---
id: 15
type: request
linked_to: null
created_by: kelvin.stinghen@me.com
created_at: 2026-05-05T15:03:54Z
updated_at: 2026-05-06T03:47:31Z
---

# Use H1 as the title, drop the `title:` frontmatter

Having both an H1 and a `title:` frontmatter is redundant. Drop the `title:`
field across Requests, Pitches, and any other Kix artifact, and treat the H1
immediately after the frontmatter as the title. Update the templates and the
create/triage skills accordingly.

## Resolution

Implemented on branch `claude/implement-feature-15-XFSqe`. Dropped the `title:`
field from the pitch template, the `kix:create-request`, `kix:create-pitch`,
and `kix:implement` skills, and migrated all existing Requests and Pitches to
carry the title as an H1 instead. PR pending.
