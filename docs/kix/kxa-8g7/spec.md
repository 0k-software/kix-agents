# Spec: Stop carrying beads issue state on feature branches

Tracked in beads: **kxa-8g7** — _Configure beads remote pointing at this same
repo (use bd push instead of branch-committed JSONL)_

Companion document: [`plan.md`](./plan.md) — the step-by-step a human runs
locally to execute this. **This spec is the target outcome; the plan is how to
get there.**

## Current state (the problem)

Beads stores issue state two ways in this repo:

1. The **embedded Dolt database** under `.beads/` — the real, queryable store,
   per-checkout, not in git.
2. `.beads/issues.jsonl` — a JSONL export of (1), **committed to git**, with
   `export.git-add: true` so every `bd` write auto-stages it.

Because (2) lives on whatever branch you're on, issue state is **per-branch**:

- `bd update <id> --claim` on a feature branch writes the claim into that
  branch's `issues.jsonl`. `main` and any sibling branch cut from `main` never
  see it.
- Two parallel branches can both believe an issue is unclaimed.
- There is no shared source of truth for issue status until branches merge —
  and if a branch is abandoned, the issue-state delta it carried is lost.
- Every rebase that touches issues on a branch fights a JSONL merge conflict.
- `bd prime` currently reports:
  `No git remote configured. Issues are saved locally only.`

## Chosen approach: git-native `refs/dolt/data` on `origin`

Push the Dolt issue database into a dedicated git ref on the **existing**
GitHub origin (`github.com/0k-software/kix-agents`). Issue state lives in the
same repo as the code, off-branch — branch history is untouched, and any clone
can pull issue state without merging a feature branch.

This matches the original framing of the issue ("point the beads remote at
_this same git repo_"). `bd bootstrap --help` already documents the read side:
"If git origin has Dolt data (refs/dolt/data): clones from git". The plan's
Phase 0 verifies that the installed `bd` exposes a command that **writes** to
that ref — see `plan.md` for the verification gate.

`.beads/issues.jsonl` stays **tracked**, but `export.git-add: false` stops it
from being auto-staged on every `bd` write. It becomes a periodic on-`main`
snapshot of the authoritative store (`refs/dolt/data`) — useful for the `bv`
viewer, off-machine readability, and disaster recovery — refreshed by a
deliberate `bd export && git commit` on `main` at whatever cadence makes sense.

### Alternatives (only if the chosen approach can't be made to work)

If Phase 0 of the plan can't find a `refs/dolt/data` seeding command in the
installed `bd`, the migration needs to switch backends rather than improvise.
Brief sketches of the alternatives `bd 1.0.3` does support:

- **DoltHub** — a separate `dolthub://org/repo` Dolt remote.
  `federation.remote: dolthub://0k-software/kix-agents-beads`. Free for public
  data; needs a DoltHub account and a second repo to maintain alongside the
  code repo.
- **Cloud bucket** — `federation.remote: gs://…` / `s3://…` / `az://…`. Needs a
  bucket + credentials.
- **Disciplined single-branch JSONL** (no new infra) — keep `issues.jsonl`
  tracked but make a rule that `bd` mutations are only committed on `main` (set
  `export.git-add: false`, stage manually on `main` only). Relies on
  discipline; doesn't add a shared remote.

Any switch to one of these is a spec change, not a plan tweak — file a
follow-up issue and revisit this document.

## Target outcome

Issue state is **branch-independent**. Concretely, after migration:

1. A `refs/dolt/data` ref exists on `origin`. `federation.remote` in
   `.beads/config.yaml` points at the GitHub repo URL.
2. `bd dolt push` / `bd dolt pull` (or whatever `bd` calls the writer/reader in
   your version) move issue state to/from that ref — branch-independent.
3. `bd prime` no longer says "No git remote configured" — it reports the remote
   and the sync state.
4. `export.git-add` is `false`. Feature branches don't dirty
   `.beads/issues.jsonl` during normal `bd` use; rebases stop conflicting on
   it.
5. `.beads/issues.jsonl` is still tracked, but as a **periodic on-`main`
   snapshot**, refreshed deliberately — not as an auto-updated per-branch
   shadow. Authoritative store is the ref on `origin`.
6. A fresh clone runs `bd bootstrap` and pulls issue state **from the ref**,
   not from a branch-committed JSONL. The `SessionStart` hook (cloud sessions)
   does the same.
7. Session-close protocol is `bd dolt push` (publish issue state to the ref)
   then `git push` (publish code) — the issue half is the same regardless of
   which branch you're on.

### Acceptance test

From a clean clone on a fresh feature branch:

```
bd update <some-id> --claim
bd dolt push
```

…and from `main` (or any other branch / a second clone):

```
bd dolt pull
bd show <some-id>      # shows the claim — WITHOUT merging the feature branch
```

Plus:

```
git ls-remote origin 'refs/dolt/*'    # lists refs/dolt/data
```

## Migration shape

The migration is two PRs to `main`, executed sequentially (see `plan.md`):

- **PR 1 — configure remote.** Adds `federation.remote: …` to
  `.beads/config.yaml`. Run `bd dolt remote add` locally + seed
  `refs/dolt/data` on `origin` after merge.
- **PR 2 — cut over.** Sets `export.git-add: false` in `.beads/config.yaml`.
  Updates `CLAUDE.md` Session Completion / migration-status notes.
  `.beads/issues.jsonl` stays tracked as the snapshot.

You **cannot** do PR 2 safely before `refs/dolt/data` is seeded and verified —
otherwise a fresh clone would have a stale `issues.jsonl` snapshot and no ref
to pull from. The plan's Phase 3 acceptance check gates PR 2.

## Out of scope

- Migrating the _history_ of `issues.jsonl` out of past commits — it stays in
  git history; we just stop auto-adding to it.
- Multi-repo / `repos.*` hydration (separate experimental beads feature).
- Changing how the `SessionStart` install hooks fetch `bd` / Dolt — only the
  bootstrap _source_ changes (ref vs. branch JSONL), which `bd bootstrap`
  already prioritizes correctly once `federation.remote` is set.

## Related docs / config touchpoints

- `CLAUDE.md` — "Session Completion" checklist (any new prose goes _outside_
  the managed `<!-- BEGIN/END BEADS INTEGRATION -->` block — `bd` regenerates
  that block) and the migration-status note (which gets replaced by the
  steady-state note in PR 2).
- `.beads/config.yaml` — gains `federation.remote` in PR 1, flips
  `export.git-add: false` in PR 2.
- `.beads/issues.jsonl` — stays tracked; usage changes from
  auto-staged-per-write to periodic on-`main` snapshot.
- Optional follow-up: a `make refresh-beads-snapshot` target (or scheduled CI
  job) that rebuilds and commits the snapshot from `main` on a cadence. Not
  required for `kxa-8g7` to close.
