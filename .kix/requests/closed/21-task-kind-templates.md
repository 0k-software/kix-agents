---
id: 21
title: Per-kind Task body templates from .github issue templates
type: request
linked_to: null
created_by: noreply@anthropic.com
created_at: 2026-05-06T10:29:06Z
updated_at: 2026-05-06T10:48:50Z
---

Replace the single `claude-code/templates/task.md` with four per-kind Task body
templates, copied verbatim in shape from the GitHub issue templates in
`0k-software/.github`:

- `task-feature.md` — from `.github/ISSUE_TEMPLATE/2-feature.yml` (✨ Feature,
  including the Pre-flight checklist)
- `task-chore.md` — from `.github/ISSUE_TEMPLATE/3-task.yml` (🛠️ Task in
  `.github`; renamed Chore here so it doesn't collide with the Kix Task entity)
- `task-bug.md` — from `.github/ISSUE_TEMPLATE/4-bug.yml` (🐛 Bug, including
  Severity)
- `task-enhancement.md` — from `.github/ISSUE_TEMPLATE/5-enhancement.yml` (🧱
  Enhancement)

Each rendered Task body should match what the corresponding GitHub issue
template produces when submitted — same section labels, same default values.

`kix:create-task` should pick which of the four templates to stamp out by
**inferring the kind from the user's context** rather than from an explicit
flag. Two signals to consider, in order:

1. The framing/free-text the user wrote after the command invocation (e.g. "fix
   the flaky login test" → `bug`; "make the dashboard load faster" →
   `enhancement`).
2. The parent Pitch's title and Summary, when `--pitch <id>` is given (e.g. a
   Pitch titled "Auth modernization" with feature-shaped Summary → `feature`).

If both signals are absent or ambiguous, fall back to a sensible default
(probably `chore`) and state the inferred kind in the confirmation output so
the user can correct it.

## Resolution

Implemented on branch `kix/21-task-kind-templates`. Added the four per-kind
Task body templates (`task-feature.md`, `task-chore.md`, `task-bug.md`,
`task-enhancement.md`) ported from `0k-software/.github`'s issue templates,
removed the generic `task.md`, and extended `kix:create-task` with a new "Infer
the Task kind" step that picks the template from framing text / parent Pitch /
seed Requests with `chore` as the fallback and echoes the inferred kind in the
confirmation. PR pending.
