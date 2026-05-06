---
id: 8
title: Warn on vague Request bodies during creation
type: request
linked_to: null
created_by: kelvin.stinghen@me.com
created_at: 2026-05-05T13:02:20Z
updated_at: 2026-05-06T03:46:58Z
---

Request creation should stay rough and friction-free, but very terse briefs can
be hard to grasp later — see `.kix/requests/4-create-pitch-skill.md`, which
gives no hint of what the skill is for. When the brief is too thin to infer
meaning, the `/kix:request` skill should still create the Request, but warn the
user that the body is vague and more context would help future triagers.

## Resolution

Implemented on branch `claude/implement-feature-8-6vLVd`. Extended the
`kix:create-request` skill's confirm step with a soft vagueness check: when the
body is empty or too thin to convey area/outcome/motivation, the skill now
prints a warning alongside the file path. Creation itself stays friction-free —
the warning is a nudge, not a rejection. Added a matching `### Changed` entry
to the Unreleased section of CHANGELOG.md.

PR: PR pending
