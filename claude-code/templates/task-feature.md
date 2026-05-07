---
id: ${id}
title: ${title}
phase: backlog
kind: feature
pitch: ${pitch_id}
requests: ${requests}
dependencies: []
created_by: ${email}
created_at: ${now}
updated_at: ${now}
---

# ✨ ${title}

${summary}

## Motivation

_Why do we need this feature? What problem does it solve?_

## Architecture

_How does this fit together at the system level? Boundaries, data ownership,
integration points, request/response flow. The shape of the solution, not the
line-by-line implementation._

## Components

_The concrete pieces — modules, services, schemas, endpoints, jobs, UI
surfaces. What gets added, what gets touched, what stays out of scope._

## Error handling

_What can go wrong, and how the system responds. Failure modes, retries,
fallbacks, user-visible error messages, partial-failure semantics._

## Boundary & context

_Where does this feature belong in the codebase? Does it fit an existing
context/module/boundary, or does it require a new one?_

## Data model _(optional)_

_Does this feature change persisted data — new tables, columns, or
relationships? If not applicable to this feature, mark this section `N/A` and
explain why; don't remove it._

## Data flow _(optional)_

_How does data move through the system for this feature — entry points,
transformations, persistence, where it ends up? Sequence-of-events view, not
just storage shape. If not applicable, mark `N/A` and explain why._

## Data migrations / Backfills _(optional)_

_Are there one-off migrations or backfill jobs needed to ship this — schema
changes, populating new columns from old data, reshaping existing rows? Note
rollout order and whether the migration must run before code deploys. If not
applicable, mark `N/A` and explain why._

## Authentication

_Does the user need to be authenticated to use this feature at all, or is some
part of it accessible to anonymous traffic? "Who they are" lives in
Authorisation; this section is about whether identity is required._

## Authorisation

_Once a user is identified, who is allowed to do what? Roles, scopes, ownership
rules, the actions this feature introduces or affects, and the access boundary
between them. Anonymous-allowed flows still spell out their authorisation rules
here (e.g. "anyone can read, only owners can edit")._

## Admin surface _(optional)_

_Does this feature need an admin / back-office surface — listing, editing, or
managing the new resources? If not applicable, mark `N/A` and explain why;
don't remove the section._

## Release strategy

_How will this ship? Behind a feature flag with gradual rollout, dark launch,
big bang, off by default? If no special rollout is needed, say so._

## Background jobs _(optional)_

_Does any work run in the background — queued, deferred, retried? If so, which
queue and what backoff/retry behaviour? If not applicable, mark `N/A` and
explain why; don't remove the section._

## Tests

_How will this be tested? Aim for a layered approach: unit tests covering the
core logic in isolation, plus integration tests exercising the feature
end-to-end._

_Testing principles:_

- _Test **observable behaviour**, not implementation details. If the test
  breaks every time the internals are refactored without a real behaviour
  change, it's coupled too tightly._
- _Unit tests should pin down the contract of a single piece in isolation.
  Integration tests should exercise the feature the way a real user (or
  upstream system) does — through the public surface._
- _Avoid mocks of code under your own control beyond what's needed to isolate;
  prefer fakes or real wiring for collaborators that have meaningful logic of
  their own._

## Dev helpers _(optional)_

_Are there development / debugging helpers worth adding — REPL helpers,
fixtures, seed data, debug commands? If not applicable, mark `N/A` and explain
why; don't remove the section._

## AI instructions updates _(optional)_

_Does this introduce a pattern, convention, or constraint future coding agents
should know about? If so, update the project's AI-instruction files to capture
it. The canonical entry point is `AGENTS.md`, but a project may also keep
finer-grained guidance under a `rules/` directory (e.g. `rules/database.md`,
`rules/auth.md`); update the right ones for the area this feature touches. If
not applicable, mark `N/A` and explain why; don't remove the section._

## Observability

_How will this feature be observable in production — logs, metrics, traces,
alerts? What's the debugging story when something goes wrong?_

## Validation

_How will we know this feature is being used and is actually solving the
problem? Beyond "does it work as built", how do we verify end-user adoption —
funnel metrics, conversion rates, feedback channels, A/B comparisons?_

## Impact

_Who will benefit from this? How does it make things better?_

## Alternatives

_Alternative approaches considered during design, with tradeoffs._

**{Decision point}:**

- Option A: ...
- Option B: ...
- ✅ Chosen: Option A — because ...
