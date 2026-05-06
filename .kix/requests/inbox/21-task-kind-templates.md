---
id: 21
title: Per-kind Task body templates from .github issue templates
type: request
linked_to: null
created_by: noreply@anthropic.com
created_at: 2026-05-06T10:29:06Z
updated_at: 2026-05-06T10:29:06Z
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

Add a `--kind <feature|chore|bug|enhancement>` flag to `kix:create-task` that
selects which template to stamp out. Default kind to be decided (probably
`chore`).
