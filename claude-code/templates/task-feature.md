---
id: ${id}
title: ${title}
phase: backlog
kind: feature
pitch: ${pitch_id}
requests: ${request_ids}
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

## Alternatives

_Alternative approaches considered during design, with tradeoffs._

**{Decision point}:**

- Option A: ...
- Option B: ...
- ✅ Chosen: Option A — because ...

## Impact

_Who will benefit from this? How does it make things better?_

## Pre-flight checklist

_Work through each of these items before implementation. Skip with intent — if
an item doesn't apply, note why in here._

- [ ] **Boundary & context** — belongs in an existing context, or a new one
      created following the _How to add a new Phoenix context_ steps in
      `CLAUDE.md`
- [ ] **Database migration** — new tables/columns generated with
      `mix ecto.gen.migration` using `binary_id` keys
- [ ] **Authentication** — correct router scope chosen
      (`:require_authenticated_user`, `:require_kingdom`, or public)
- [ ] **Authorisation** — does this affect existing actions or introduce new
      ones? Who can perform them?
- [ ] **Admin pages** — Backpex config updated in `/admin` with any new
      resources or fields added to existing resources
- [ ] **Feature flag** — rolls out gradually behind a
      `KingdoneCore.FeatureFlags` flag enabled via `/dev/flags`; or noted in
      the PR description why a flag is not needed
- [ ] **Background jobs** — deferred/retried work uses an Oban worker
- [ ] **Tests** — LiveView integration tests with `PhoenixTest`; context unit
      tests; both flag states covered if feature-flagged
- [ ] **IEx helpers** — `.iex.exs` updated for any new schemas
- [ ] **CLAUDE.md** — new patterns or conventions documented
