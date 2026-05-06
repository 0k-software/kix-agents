---
id: 14
title: ID conflicts when multiple people allocate IDs in parallel
phase: ideas
requests: [11]
created_by: kelvin.stinghen@me.com
created_at: 2026-05-05T15:01:28Z
updated_at: 2026-05-06T02:08:14Z
---

# ID conflicts when multiple people allocate IDs in parallel

## Summary

The current ID allocator reads `.kix/.state/next-id` and increments it. Two
parallel branches each read the same value, both allocate it, both write
`+1` back — and git's 3-way merge sees the same change on both sides and
accepts it silently. Duplicates land on `main` without any conflict ever
being raised.

The chosen direction: drop the counter entirely. Replace integer IDs with
6-character base36 hashes, prefixed by artifact type — `kr-a1b2c3` for
Requests and `kp-a1b2c3` for Pitches. The scheme extends naturally to
future types (e.g. Tasks → `kt-`), but those are out of scope here.
Allocation is purely local, requires no coordination, and the collision
probability is vanishingly small at any realistic Kix scale. The
generation algorithm mirrors what Beads does in its `internal/idgen`
package — we adopt the approach (deterministic SHA-256 hash of the
artifact's metadata, base36-encoded, nonce-bumped on collision) without
taking a dependency on Beads itself.

## The Problem

The allocator is a plain monotonic counter at `.kix/.state/next-id`. Two
parallel branches each read it at, say, `19`, both allocate `19`, and both
write `next-id = 20`. When the second branch merges, git's 3-way merge
sees the same `19 → 20` change on both sides and accepts it silently — no
conflict is raised. Two artifacts with the same ID land on `main`,
breaking every reference to that ID.

This already happened in this repo: `closed/19-port-rebase-skill.md` and
the (since-renumbered) `inbox/20-copy-fix-pr-skill.md` were both created
on parallel branches the same day, both with `id: 19`. The collision
was resolved by hand as a tactical fix; this pitch is the systemic
fix.

## The Appetite

**1 week.** The algorithm port is ~30 lines, the skill updates are
small edits, and the migration is a one-shot script over ~20 files.
The week's budget covers edge-case handling for the migration's
reference rewriting and getting the CI check right.

## The Solution

**ID format:** `<prefix>-<6 base36 chars>`, where the prefix marks the
artifact type:

- `kr-a1b2c3` — Request
- `kp-a1b2c3` — Pitch

The scheme extends to future types by adding a new prefix letter (Tasks
would be `kt-`), but introducing those types is the job of a separate
pitch — out of scope here.

Six base36 chars give `36⁶ = 2,176,782,336` values per type. The
birthday-collision threshold (~1% probability) sits around 6,500
artifacts of the same type — well past anything Kix is likely to see.
Per-type prefixes mean a Request and a Pitch can share the same suffix
without conflict; each type has its own 2.1B-value space.

**Allocation algorithm** (mirrors Beads' `internal/idgen/hash.go`):

1. Compute `SHA-256(prefix | title | creator | timestamp | nonce)` where
   `nonce` starts at 0.
2. Take enough leading bytes to base36-encode into 6 chars, encode them.
3. If the resulting ID already exists in `.kix/**`, increment the nonce
   and retry. In practice this loop almost never trips at Kix's scale,
   but it's a clean way to handle the edge case without ever asking the
   user.

The hash is **deterministic**: rerunning creation with identical inputs
yields the same ID, which is useful for tests and for recomputing IDs
during migration. No counter, no `.kix/.state/next-id`, no shared state,
no coordination — fully offline-safe. Parallel branches cannot collide
in practice.

**Filenames:** `{prefix}-{hash}-{slug}.md` — e.g.
`kr-a1b2c3-port-rebase-skill.md`. Glob-friendly per type (`kr-*` /
`kp-*`).

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
- ✅ Chosen: prefixed 6-base36-char hashes (`kr-a1b2c3`). Algorithm
  adopted from Beads' `internal/idgen/hash.go` (deterministic SHA-256 +
  nonce), but kept inside Kix so we don't take a dependency on a young,
  churning external tool. A trades short memorability for real machinery
  cost (CI gate, dedupe skill, branch-protection rules) and stays
  vulnerable to misconfiguration. B doesn't scale beyond a handful of
  authors and creates per-actor allocator state. C excludes requests
  that never become PRs. D depends on GitHub availability, which has
  been unreliable lately. E loses ID-style references entirely. F
  adopts a moving external surface area we don't want to track. The
  hash approach is offline, conflict-free by construction, requires
  zero coordination, and `kr-a1b2c3` is short enough to say in
  conversation.

**Hash length:**

- Option A: Progressive scaling (4 → 5 → 6 chars as the project grows,
  Beads-style).
- Option B: Fixed 6 chars from day one.
- ✅ Chosen: Option B — at Kix's expected scale, fixed 6 base36 chars
  (~2.1B values per type) is "fine pretty much forever." Progressive
  scaling adds rename complexity (every ID changes length when a
  threshold trips) for no practical payoff.

**Encoding:**

- Option A: Hex (`0-9a-f`, 16 values per char).
- Option B: Base36 (`0-9a-z`, 36 values per char).
- ✅ Chosen: Option B — same algorithm as Beads, and at 6 chars base36
  gives ~130× the address space of hex (2.1B vs 16.8M), which is what
  makes "6 chars forever" actually true rather than borderline.

**Prefix style:**

- Option A: Bare type letter (`r-a1b2c3`, `p-a1b2c3`).
- Option B: `k`-tagged prefix (`kr-a1b2c3`, `kp-a1b2c3`).
- ✅ Chosen: Option B — the leading `k` clearly marks IDs as Kix-owned,
  makes them grep-friendly across mixed-source contexts, and avoids
  ambiguity if the same repo ever picks up another tool with
  single-letter IDs.

## The Rabbit Holes

- **Migrating existing integer IDs.** All current artifacts (Requests
  1–20, Pitches 14 and 17) get rewritten to the new format, including
  this pitch itself — every `id` field, every filename, and every
  cross-reference (`linked_to`, pitch `requests: [...]`) is updated in
  one migration commit.
- **External references.** Commit messages, PR titles, branch names
  referencing old integer IDs will go stale after a rewrite. Mitigated
  by Kix being a solo repo today — blast radius is small.
- **Slug duplicates in filenames.** Two artifacts with the same slug
  but different hashes is fine — the hash disambiguates. The
  `kix:request` skill should not try to "deduplicate by slug."
- **Hash inputs and timestamp granularity.** The deterministic hash
  needs enough variability that two artifacts created back-to-back by
  the same author with similar titles don't collide. Including a
  millisecond-or-finer timestamp plus the nonce-bump-on-collision loop
  handles this; using only second-granularity timestamps may cause more
  nonce retries than necessary.
- **Migrating IDs is a re-hash, not a re-roll.** Because the hash is
  deterministic, the migration script can compute each artifact's new
  ID directly from its existing frontmatter (`title`, `created_by`,
  `created_at`) without any randomness — useful for review and for
  reproducing the migration if it has to be re-run.

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

1. Port the ID-generation algorithm from Beads' `internal/idgen/hash.go`
   into Kix as a small helper (deterministic SHA-256 + base36 + nonce
   retry). Wire it into the `kix:request` / `kix:create-pitch` skills.
2. Execute the migration: rewrite every existing Request and Pitch
   (including this one) to the new format in a single commit, with each
   new ID computed deterministically from the artifact's existing
   frontmatter.
3. Delete `.kix/.state/next-id` (no longer needed).
4. Add a small CI duplicate-ID check as a backstop.

## The Validation

- Generate 100k IDs in a unit test, confirm zero collisions.
- Create two artifacts on parallel branches with no coordination, merge
  both — confirm no collision and no manual fixup needed.
- After migration, verify every internal reference (`linked_to`,
  `requests: [...]`) still resolves to a real file.

## The To-Dos

- [ ] Port Beads' `internal/idgen/hash.go` algorithm (SHA-256 + base36
      + nonce retry) into a Kix helper.
- [ ] Update `kix:request` / `kix:create-pitch` skills to mint
      `kr-XXXXXX` / `kp-XXXXXX` IDs via the helper.
- [ ] Execute the full migration: rewrite filenames, frontmatter `id`,
      and all cross-references (`linked_to`, `requests: [...]`) for
      every existing Request and Pitch — including this pitch.
- [ ] Delete `.kix/.state/next-id`.
- [ ] Add CI duplicate-ID check.
- [ ] Update Kix docs to describe the new ID format.

## The Questions

_Resolved questions are kept here as a record. Open questions sit
above resolved ones._

- **Migration strategy: full rewrite of every existing artifact, or
  grandfather integer IDs and only mint new format going forward?**
  ✅ Full rewrite. Mixed state is too ugly to live with long-term;
  one cohesive migration commit is cleaner.
- **Does pitch 14 itself migrate (becoming `kp-XXXXXX`), or is the
  migration commit the cutover point that leaves this pitch as the
  last integer-ID artifact?** ✅ It migrates too — the cutover should
  be total.
- **Do we want to scaffold the `kt-` Task prefix in this pitch, or
  defer it entirely to a future pitch that introduces the Task type?**
  ✅ Defer. Tasks are out of scope here; only the prefix scheme is
  noted as extensible.
