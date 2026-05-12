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
- `bd prime` currently reports:
  `No git remote configured. Issues are saved locally only.`

## Constraint discovered while scoping

The literal framing of the issue — "point the beads remote at _this same git
repo_" — is **not directly supported by `bd 1.0.3`**. `bd config validate`
accepts only these remote URL schemes for `federation.remote` / `sync.remote`:

```
dolthub://org/repo      # DoltHub-hosted Dolt repo
gs:// | s3:// | az://    # cloud object storage
file:///path             # local path (testing)
```

There is no `git://` / `https://github.com/...git` Dolt-remote type, and
`bd federation` peers are full Dolt sql-servers, not git remotes.

`bd bootstrap --help` _does_ mention a `refs/dolt/data` ref on `git origin`
("If git origin has Dolt data (refs/dolt/data): clones from git"), which would
be the closest thing to "same repo, dedicated ref" — but the command that
**writes/seeds** that ref isn't exposed (or isn't obvious) in `bd 1.0.3`. So
either it's a newer feature, or it's an implementation detail of some sync path
we haven't found. The plan treats this as "verify, then choose".

## Target outcome

Issue state is **branch-independent**. Concretely, after migration:

1. A shared Dolt remote is configured (`federation.remote` / `sync.remote` in
   `.beads/config.yaml`), so `bd dolt push` / `bd dolt pull` (or
   `bd federation sync`) move issue state to/from one canonical place that is
   **not** a git branch.
2. `bd prime` no longer says "No git remote configured" — it reports the remote
   and the sync state.
3. `.beads/issues.jsonl` is **no longer tracked in git**, and `export.git-add`
   is `false`. (The local export may still be generated for the `bv` viewer /
   off-machine backup — that's a local convenience, not a committed artifact.)
4. A fresh clone runs `bd bootstrap` and pulls issue state **from the remote**,
   not from a branch-committed JSONL. The `SessionStart` hook (cloud sessions)
   does the same.
5. Session-close protocol is `bd dolt push` (publish issue state to the remote)
   then `git push` (publish code) — and the issue half is the same regardless
   of which branch you're on.

### Acceptance test

From a clean clone on a fresh feature branch:

```
bd update <some-id> --claim
bd dolt push           # or bd federation sync
```

…and from `main` (or any other branch / a second clone):

```
bd dolt pull           # or bd federation sync
bd show <some-id>      # shows the claim — WITHOUT merging the feature branch
```

## Realization options (decide in the plan, Phase 0)

| Option                                                            | Mechanism                                                                                                                                                            | Pros                                                                                          | Cons                                                                  |
| ----------------------------------------------------------------- | -------------------------------------------------------------------------------------------------------------------------------------------------------------------- | --------------------------------------------------------------------------------------------- | --------------------------------------------------------------------- |
| **A. DoltHub** _(recommended path that works today)_              | Create a DoltHub repo (e.g. `0k-software/kix-agents-beads`); `federation.remote: dolthub://0k-software/kix-agents-beads`; push with `bd dolt push` / `bd federation` | Built-in to beads; free for public data; real branch-independent store; nothing custom        | Separate repo from the code; needs a DoltHub account/org              |
| **B. Cloud bucket**                                               | `federation.remote: gs://… \| s3://…`                                                                                                                                | No DoltHub account; uses infra org may already have                                           | Need a bucket + credentials; more moving parts                        |
| **C. git-native `refs/dolt/data`**                                | Whatever command seeds the `refs/dolt/data` ref on `origin` (verify it exists in your `bd` version first)                                                            | Closest to the original ask — issue state lives in _this_ repo, off-branch; one repo to clone | Unconfirmed in `bd 1.0.3`; if it doesn't exist, don't force it        |
| **D. Disciplined single-branch JSONL** _(fallback, no new infra)_ | Keep `issues.jsonl` tracked, but make a rule: all `bd` mutations get committed on `main` (or a dedicated `beads-state` branch) only, never on feature branches       | Zero new dependencies                                                                         | Not truly branch-independent; relies on human discipline; merge churn |

The plan walks Option A end-to-end (with the Phase-0 escape hatch to switch to
C if your `bd` confirms git-native support, or D if you want zero new infra).

## Migration is two-phase by necessity

You **cannot** safely flip (3) — untrack `issues.jsonl`,
`export.git-add: false` — until the shared remote exists _and_ is seeded. If
you untrack it first, a fresh clone has no JSONL **and** no remote ref → zero
issue history. So:

- **Phase 1–3 (this issue, kxa-8g7):** stand up + seed the remote; keep
  `issues.jsonl` tracked as the working source of truth and backup.
- **Phase 4 (follow-up issue, filed separately):** once the remote is verified,
  `git rm --cached .beads/issues.jsonl`, set `export.git-add: false`,
  `.gitignore` the export, and update the CLAUDE.md "migration status" note.

## Out of scope

- Migrating the _history_ of `issues.jsonl` out of past commits — it stays in
  git history; we just stop adding to it.
- Multi-repo / `repos.*` hydration (separate experimental beads feature).
- Changing how the `SessionStart` install hooks fetch `bd` / Dolt — only the
  bootstrap _source_ changes (remote vs. branch JSONL), which `bd bootstrap`
  already prioritizes correctly once `sync.remote` is set.

## Related docs / config touchpoints

- `CLAUDE.md` — "Session Completion" checklist (inside the managed
  `<!-- BEGIN/END BEADS INTEGRATION -->` block — don't hand-edit that block;
  any new prose goes _after_ it) and the migration-status note.
- `.beads/config.yaml` — `export.git-add`, and the `federation.remote` /
  `sync.remote` key once chosen.
- `.beads/.gitignore` — add `issues.jsonl` in Phase 4.
- `.claude/hooks/bootstrap-bd.sh` (and friends) — should already do the right
  thing via `bd bootstrap`; verify after the remote exists.
