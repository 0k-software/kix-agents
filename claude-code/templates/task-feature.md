---
id: ${id}
title: ${title}
phase: backlog
kind: feature
pitch: ${pitch_id}
requests: ${request_ids}
dependencies: []
created_by: ${email}
created_at: ${now}
updated_at: ${now}
---

# ✨ ${title}

${summary}

## Motivation

_Why do we need this feature? What problem does it solve?_

## Proposal

_What's the proposed solution? Describe how it should work._

## Boundary & context

_Where does this feature belong in the codebase? Does it fit an existing
context/module/boundary, or does it require a new one?_

## Data model _(optional)_

_Does this feature change persisted data — new tables, columns, relationships,
or migrations? Skip if there are no data changes._

## Authentication

_Does this feature need authentication? If so, who can access it (logged-in
users, specific roles, public)?_

## Authorisation

_Does this feature affect existing actions or introduce new ones? Who can
perform them?_

## Admin surface _(optional)_

_Does this feature need an admin / back-office surface — listing, editing, or
managing the new resources? Skip if there is nothing for admins to manage._

## Release strategy

_How will this ship? Behind a feature flag with gradual rollout, dark launch,
big bang, off by default? If no special rollout is needed, say so._

## Background jobs _(optional)_

_Does any work run in the background — queued, deferred, retried? If so, which
queue and what backoff/retry behaviour? Skip if everything runs inline._

## Tests

_How will this be tested? Aim for a layered approach: unit tests covering the
core logic in isolation, plus integration tests exercising the feature
end-to-end._

## Dev helpers _(optional)_

_Are there development / debugging helpers worth adding — REPL helpers,
fixtures, seed data, debug commands? Skip if nothing extra is needed._

## AGENTS.md updates _(optional)_

_Does this introduce a pattern, convention, or constraint future agents should
know about? If so, update `AGENTS.md` to capture it. Skip if nothing new for
agents to learn._

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
