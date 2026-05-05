---
id: 9
title: Outcome subfolders instead of front-matter field
type: request
linked_to: null
created_by: kelvin.stinghen@me.com
created_at: 2026-05-05T13:58:42Z
updated_at: 2026-05-05T15:58:48Z
---

Instead of an `outcome` field in the Request front-matter, store the outcome by
location: a subfolder per outcome. New Requests land in `inbox/`. Triage moves
the file into the matching outcome folder.

Folders:

- `.kix/requests/inbox/` — outcome not yet decided (current Inbox view)
- `.kix/requests/postponed/`
- `.kix/requests/linked/`
- `.kix/requests/closed/`

This makes the on-disk layout match the Inbox/triage mental model and lets
users see counts at a glance with `ls`. Open question: whether `linked_to` also
moves to a folder convention or stays as front-matter.

## Resolution

Shipped in:

- [813c732](https://github.com/0k-software/kix/commit/813c732) — feat: encode
  Request outcome by subfolder (Request 9)

`linked_to` stayed in front-matter — encoding the target Pitch/Task as a nested
folder would have broken the `ls`-count goal and the symmetry with the other
outcomes.
