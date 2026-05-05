---
id: 18
title: Skill to implement requests via branch and PR
type: request
linked_to: null
created_by: noreply@anthropic.com
created_at: 2026-05-05T17:52:14Z
updated_at: 2026-05-05T17:52:14Z
---

Add a new skill (`kix:implement` or similar) that automates the implementation
workflow for a plain request. The skill should:

1. Open a git branch scoped to the request.
2. Implement what's requested, splitting work across multiple commits to make
   review easier.
3. Mark the request as closed (move it to `closed/`) within that branch.
4. Open a pull request when the work is done.

Initially, the skill should be able to operate directly on top of a plain
Request (no pitch or plan required), so the team can move quickly before the
full Kix process is in place.
