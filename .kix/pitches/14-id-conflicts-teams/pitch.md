---
id: 14
title: ID conflicts when multiple people allocate IDs in parallel
phase: ideas
requests: [11]
created_by: kelvin.stinghen@me.com
created_at: 2026-05-05T15:01:28Z
updated_at: 2026-05-05T16:00:00Z
---

# ID conflicts when multiple people allocate IDs in parallel

## Summary

The current ID allocator reads `.kix/.state/next-id` and increments it. In a
team setting this collides: if I create a Request locally and don't push, and
someone else also creates one on their branch, both end up with the same ID. We
need a strategy that survives parallel work across branches and people.

One idea worth exploring: drop the counter and use random IDs — maybe a SHA of
the entity's initial contents — so allocation works offline without
coordination. Not decided yet, just a candidate direction.

## The Problem

_Describe the raw idea or the problem to solve, not the solution. Why is this
important? What pain does it solve?_

## The Appetite

_Define the max amount of time/effort the team should spend to solve it.
Remember: this is not how much you think it's going to take to implement the
best possible solution, but how much time you are willing to invest on it._

_Pick one: 1 week · 2 weeks · 3 weeks · 4 weeks · 5 weeks_

## The Solution

_What's the proposed solution? Describe how it should work._

## The Alternatives

_Alternative approaches considered during design, with tradeoffs._

**{Decision point}:**

- Option A: ...
- Option B: ...
- ✅ Chosen: Option A — because ...

## The Rabbit Holes

_List potential tricky parts that could consume lots of time or introduce
uncertainty. Identify what to avoid going deep into._

-

## The No-Gos

_Clearly state what is explicitly excluded from this pitch, to prevent scope
creep._

-

## The Delivery

_We need to know how we will ship this. How much time we need for it? Is it
complex? Does it require data migrations? Will we do partial rollout?_

## The Validation

_Describe here how we could validate the solution actually solved the problem.
This includes the actual observability, not just a quick "how to test" for the
stakeholders, but which metrics should we keep track of later, after the
project is delivered._

## The To-Dos

_A broken-down list of tasks we need to execute to implement the solution.
Start with an abstract checklist, so later we can convert the checklist item
into sub-issues of this pitch, open a project for it and plan its execution._

- [ ] Kickoff the project
- [ ]

## The Questions

_Open questions still to answer before — or during — building this pitch.
Things we don't know yet, decisions we've parked, places we expect surprises._

-
