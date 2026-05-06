---
id: 14
title: ID conflicts when multiple people allocate IDs in parallel
phase: ideas
requests: [11]
created_by: kelvin.stinghen@me.com
created_at: 2026-05-05T15:01:28Z
updated_at: 2026-05-06T00:29:06Z
---

# ID conflicts when multiple people allocate IDs in parallel

## Summary

The current ID allocator reads `.kix/.state/next-id` and increments it. In a
team setting — or even solo with parallel branches — this collides: two
branches each read `next-id` at the same value, both allocate it, and both
write the same `next-id + 1` back. Git's 3-way merge sees identical changes
on both sides and accepts them silently, so duplicates land on `main`
without a conflict ever being raised.

The chosen direction: keep simple integer IDs and the existing allocator,
treat `main` as the source of truth (its IDs are immutable), and add a CI
dup-check plus a `kix dedupe` skill that renumbers colliding IDs on the
branch when conflicts are detected.

## The Problem

The allocator is a plain monotonic counter at `.kix/.state/next-id`. Two
parallel branches each read it at, say, `19`, both allocate `19`, and both
write `next-id = 20`. When the second branch merges, git's 3-way merge sees
the same `19 → 20` change on both sides and accepts it silently — no
conflict is raised. Two artifacts with the same ID land on `main`, breaking
every reference to that ID.

This already happened in this repo: `closed/19-port-rebase-skill.md` and
`inbox/19-copy-fix-pr-skill.md` both carry `id: 19`, created on parallel
branches the same day.

## The Appetite

_Pick one: 1 week · 2 weeks · 3 weeks · 4 weeks · 5 weeks_

## The Solution

Keep the current allocator. Defend correctness with two cheap layers:

1. **CI dup-check.** A script walks `.kix/requests/**` and `.kix/pitches/**`,
   groups by the `id` field in frontmatter, and fails if any group has more
   than one entry (or if any missing/draft `id` reaches main). Required as a
   merge gate, with branch protection's "branches must be up to date before
   merge" enabled — without that flag, two PRs that each allocate the same
   ID can both pass CI in isolation and silently collide on `main`.
2. **`kix dedupe` skill.** When CI fails (or run preemptively before push),
   the skill detects duplicate IDs between the current branch and `main`,
   reallocates a fresh ID for the **branch's** artifact (never `main`'s),
   and rewrites every internal reference: filename, frontmatter `id`,
   `linked_to`, pitch `requests: [...]`, and any other cross-link. It also
   bumps `.kix/.state/next-id` to `max(id) + 1`.

The invariant is "**`main` is immutable; branches always lose**." Because CI
blocks duplicates from landing, by induction `main` is always conflict-free,
so renumbering only ever has to touch the branch's in-flight artifacts —
never anything someone else might have already referenced externally.

## The Alternatives

**ID scheme:**

- Option A: Random IDs / SHA of contents — offline-safe, never collide.
- Option B: Per-author namespaces (`k19`, `b3`) — offline-safe, never collide.
- Option C: PR-number-as-ID — uses GitHub's atomic counter.
- Option D: GitHub Issue-number-as-ID — uses GitHub's atomic counter, works
  even for requests that never become PRs.
- Option E: Date-slug filenames (`2026-05-05-port-rebase-skill.md`) — no
  allocator, no collisions.
- ✅ Chosen: keep simple integer IDs + detect-and-repair — A/B/E sacrifice
  memorability ("implement request 19" is the whole point); C excludes
  requests that never get a PR; D introduces a hard dependency on GitHub
  availability, which has been unreliable lately. Detect-and-repair keeps
  the UX we want and makes collisions self-healing.

**Allocation timing:**

- Option A: Allocate at creation (today's behaviour).
- Option B: Defer allocation until merge time.
- ✅ Chosen: Option A — deferring shrinks the collision window but doesn't
  close it (two branches deferring then both rebasing still hit the silent
  3-way merge), and it removes the ability to reference an ID before merge,
  which is the main reason we want short integers in the first place.

**Tiebreaker when renumbering:**

- Option A: Older `created_at` keeps the ID.
- Option B: The artifact already on `main` keeps the ID; the branch loses.
- ✅ Chosen: Option B — `main` is the only place external references
  (commit messages, PR titles, chat) might already point to. Renumbering on
  `main` would orphan those; renumbering a branch's in-flight artifact
  doesn't.

## The Rabbit Holes

- **Reference rewriting.** `kix dedupe` has to update every internal
  cross-reference, not just the file it renumbered. At minimum: filename,
  frontmatter `id`, `linked_to` (in requests), and `requests: [...]` (in
  pitches). Missing one silently breaks links.
- **External references can't be rewritten.** Commit messages, PR titles,
  chat, branch names referencing a since-renumbered ID will go stale. The
  "main always wins" rule is what minimises this — branch IDs in flight
  haven't escaped to the world yet.
- **Branch-protection misconfiguration.** Without "branches must be up to
  date before merge", two PRs can each pass CI individually and merge with
  duplicate IDs. The rule has to actually be on for the gate to hold.

## The No-Gos

- Changing IDs on `main` for any reason. Once an ID is on `main` it is
  permanent.
- Replacing integer IDs with hashes, dates, or other long strings —
  memorability is the whole point.
- Allocation paths that require network at creation time.

## The Delivery

Small change: a CI script, a skill, and a one-time fix for the existing
`19` collision. No data migration beyond renumbering one of the two `19`s.
Branch-protection rule needs to be turned on at the GitHub side.

## The Validation

- CI catches deliberate collisions injected via test branches.
- Solo parallel-branch test: create two branches that both allocate the
  same ID, merge one, attempt to merge the other → CI fails, `kix dedupe`
  renumbers, second merge succeeds with the new ID and all references
  intact.

## The To-Dos

- [ ] Resolve the existing `id: 19` collision (renumber one of the two).
- [ ] Write the CI dup-check script + workflow.
- [ ] Build the `kix dedupe` skill (renumber + rewrite all references +
      bump `next-id`).
- [ ] Enable "branches must be up to date before merge" on `main`.
- [ ] Document the renumbering flow in the Kix docs.

## The Questions

- Should `kix dedupe` run automatically on `kix:commit` / pre-push, or
  stay an explicit skill the user invokes after CI fails?
- What is the canonical list of "internal references to an ID" that the
  dedupe skill must rewrite? (Today: filename, `id`, `linked_to`,
  `requests: [...]`. Anything else as the schema grows?)
