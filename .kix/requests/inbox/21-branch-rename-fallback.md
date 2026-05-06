---
id: 21
title: Fallback to git branch -M when on claude/* branch
type: request
linked_to: null
created_by: noreply@anthropic.com
created_at: 2026-05-06T10:39:09Z
updated_at: 2026-05-06T10:39:09Z
---

Whenever creating a branch for a request/pitch/task, we have to fallback to
`git branch -M` in case the current branch is a `claude/*` branch.
