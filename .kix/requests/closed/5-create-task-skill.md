---
id: 5
title: `create-task` skill
type: request
linked_to: null
created_by: kelvin.stinghen@me.com
created_at: 2026-05-05T12:52:53Z
updated_at: 2026-05-06T04:00:41Z
---

Add a `create-task` skill.

## Resolution

Implemented on branch `claude/implement-feature-5-iPJjD`. Added the
`kix:create-task` skill, the `kix:task` alias, and a Task template
(`claude-code/templates/task.md`); the skill mirrors `kix:create-pitch` and
adds a `--pitch <id>` flag to attach the new Task to a parent Pitch. PR
pending.
