---
id: 14
title: ID conflicts when multiple people allocate IDs in parallel
phase: ideas
requests: [11]
created_by: kelvin.stinghen@me.com
created_at: 2026-05-05T15:01:28Z
updated_at: 2026-05-06T01:59:46Z
---

# ID conflicts when multiple people allocate IDs in parallel

## Summary

The current ID allocator reads `.kix/.state/next-id` and increments it. Two
parallel branches each read the same value, both allocate it, both write
`+1` back — and git's 3-way merge sees the same change on both sides and
accepts it silently. Duplicates land on `main` without any conflict ever
being raised.

The chosen direction: drop the counter entirely. Replace integer IDs with
random 6-character hex hashes, prefixed by artifact type — `KR-a1b2c3` for
Requests and `KP-a1b2c3` for Pitches. The scheme extends naturally to
future types (e.g. Tasks → `KT-`), but those are out of scope here.
Allocation is purely local, requires no coordination, and the collision
probability is vanishingly small at any realistic Kix scale.

## The Problem

The allocator is a plain monotonic counter at `.kix/.state/next-id`. Two
parallel branches each read it at, say, `19`, both allocate `19`, and both
write `next-id = 20`. When the second branch merges, git's 3-way merge
sees the same `19 → 20` change on both sides and accepts it silently — no
conflict is raised. Two artifacts with the same ID land on `main`,
breaking every reference to that ID.

This already happened in this repo: `closed/19-port-rebase-skill.md` and
`inbox/19-copy-fix-pr-skill.md` both carry `id: 19`, created on parallel
branches the same day.

## The Appetite

_Pick one: 1 week · 2 weeks · 3 weeks · 4 weeks · 5 weeks_

## The Solution

**ID format:** `<prefix>-<6 hex chars>`, where the prefix marks the
artifact type:

- `KR-a1b2c3` — Request
- `KP-a1b2c3` — Pitch

The scheme extends to future types by adding a new prefix letter (Tasks
would be `KT-`), but introducing those types is the job of a separate
pitch — out of scope here.

The 6 hex chars are random (24 bits = 16,777,216 values). At Kix's
expected scale (hundreds of artifacts per type), the birthday-collision
probability is well under 0.1%. Per-type prefixes mean a Request and a
Pitch can share the same suffix without conflict — each type has its own
16M-value space.

**Allocation:** purely local. Generate 3 random bytes, hex-encode, prepend
the type prefix. No counter, no `.kix/.state/next-id`, no coordination,
fully offline-safe. Parallel branches cannot collide in practice.

**Filenames:** `{prefix}-{hash}-{slug}.md` — e.g.
`KR-a1b2c3-port-rebase-skill.md`. Glob-friendly per type (`KR-*` /
`KP-*`).

**Backstop CI check:** in the unlikely event of a real collision, or a
hand-edit that introduces a duplicate, a tiny CI script walks `.kix/**`
and fails on duplicate IDs. Cheap insurance, not a load-bearing part of
the design.

## The Alternatives

**ID scheme:**

- Option A: Sequential integers + detect-and-repair (CI dup-check +
  dedupe skill, "main wins" tiebreaker).
- Option B: Per-author namespaces (`k19`, `b3`).
- Option C: PR-number-as-ID.
- Option D: GitHub Issue-number-as-ID.
- Option E: Date-slug filenames.
- Option F: Beads as the underlying allocator.
- ✅ Chosen: prefixed 6-hex-char random hashes (`KR-a1b2c3`). Inspired
  by Beads' `bd-XXXX` but kept inside Kix so we don't take a dependency
  on a young, churning external tool. A trades short memorability for
  real machinery cost (CI gate, dedupe skill, branch-protection rules)
  and stays vulnerable to misconfiguration. B doesn't scale beyond a
  handful of authors and creates per-actor allocator state. C excludes
  requests that never become PRs. D depends on GitHub availability,
  which has been unreliable lately. E loses ID-style references
  entirely. F adopts a moving external surface area we don't want to
  track. The hash approach is offline, conflict-free by construction,
  requires zero coordination, and `KR-a1b2c3` is short enough to say in
  conversation.

**Hash length:**

- Option A: Progressive scaling (4 → 5 → 6 chars as the project grows,
  Beads-style).
- Option B: Fixed 6 chars from day one.
- ✅ Chosen: Option B — at Kix's expected scale, fixed 6 is "fine pretty
  much forever." Progressive scaling adds rename complexity (every ID
  changes length when a threshold trips) for no practical payoff.

**Prefix style:**

- Option A: Bare type letter (`R-a1b2c3`, `P-a1b2c3`).
- Option B: `K`-tagged prefix (`KR-a1b2c3`, `KP-a1b2c3`).
- ✅ Chosen: Option B — the `K` clearly marks IDs as Kix-owned, makes
  them grep-friendly across mixed-source contexts, and avoids ambiguity
  if the same repo ever picks up another tool with single-letter IDs.

## The Rabbit Holes

- **Migrating existing integer IDs.** All current artifacts (Requests
  1–19, Pitches 14 and 17) get rewritten to the new format, including
  this pitch itself — every `id` field, every filename, and every
  cross-reference (`linked_to`, pitch `requests: [...]`) is updated in
  one migration commit. The existing `id: 19` collision resolves
  automatically since both colliding files get fresh `KR-XXXXXX` IDs.
- **External references.** Commit messages, PR titles, branch names
  referencing old integer IDs will go stale after a rewrite. Mitigated
  by Kix being a solo repo today — blast radius is small.
- **Slug duplicates in filenames.** Two artifacts with the same slug
  but different hashes is fine — the hash disambiguates. The
  `kix:request` skill should not try to "deduplicate by slug."
- **Random source.** Use a cryptographically-decent RNG (`crypto/rand`
  in Go, `secrets.token_hex(3)` in Python) — not seeded `Math.random`
  or anything time-based that could correlate across parallel runs.

## The No-Gos

- Re-introducing any global allocator state (`next-id`, registry file,
  external service). The whole point is that allocation is stateless
  and local.
- Depending on Beads, GitHub, or any external coordination point for
  ID generation.
- Hashes longer than 6 chars or shorter than 4. Six is the chosen
  sweet spot — long enough to be collision-safe at scale, short enough
  to say out loud.

## The Delivery

Small change in code, larger change in data:

1. Update the ID-allocation helper used by `kix:request` /
   `kix:create-pitch` to emit hex hashes with the right prefix.
2. Execute the migration: rewrite every existing Request and Pitch
   (including this one) to the new format in a single commit.
3. Delete `.kix/.state/next-id` (no longer needed).
4. Add a small CI duplicate-ID check as a backstop.

## The Validation

- Generate 100k IDs in a unit test, confirm zero collisions.
- Create two artifacts on parallel branches with no coordination, merge
  both — confirm no collision and no manual fixup needed.
- After migration, verify every internal reference (`linked_to`,
  `requests: [...]`) still resolves to a real file.

## The To-Dos

- [ ] Update `kix:request` / `kix:create-pitch` skills to mint
      `KR-XXXXXX` / `KP-XXXXXX` IDs.
- [ ] Execute the full migration: rewrite filenames, frontmatter `id`,
      and all cross-references (`linked_to`, `requests: [...]`) for
      every existing Request and Pitch — including this pitch. The
      existing `id: 19` collision resolves automatically — both get
      fresh `KR-XXXXXX` IDs.
- [ ] Delete `.kix/.state/next-id`.
- [ ] Add CI duplicate-ID check.
- [ ] Update Kix docs to describe the new ID format.

## The Questions

-
