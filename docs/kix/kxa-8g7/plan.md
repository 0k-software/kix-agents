# Plan: migrate beads off branch-committed JSONL — local execution

Tracked in beads: **kxa-8g7**. Target outcome: [`spec.md`](./spec.md).

**Run from a normal local checkout on `main` — not a cloud/sandbox session.**
The canonical remote URL gets written into `.beads/config.yaml`, so it must be
the real value. Also: the embedded-Dolt write path has been flaky in sandboxes
(observed: a multi-minute hang + a stray `dolt sql-server`); prefer a stable
local environment for these one-shot `bd config` writes.

**Backend choice: git-native `refs/dolt/data` on `origin`** — issue state lives
in this same git repo, in a dedicated ref, separate from branch history.
`.beads/issues.jsonl` stays **tracked as a periodic snapshot/backup**, with
`export.git-add: false` so it stops accumulating per-branch churn during normal
work.

Throughout: `bd` may print `journal writer has already been closed` warnings
and a `.beads permissions 0755` notice — those are noise, ignore them. Real
errors say `level=error` or exit non-zero.

**Prerequisite:** PR #44 (this branch's docs) is merged into `main`, and any
other branches that touched `.beads/issues.jsonl` are merged too. The plan
assumes you're starting from `main` with no in-flight beads deltas.

---

## Phase 0 — Verify your `bd` version actually supports git-native Dolt sync

This is **a hard prerequisite**. `bd bootstrap --help` documents _reading_
issue state from `refs/dolt/data` on git origin, but the command that **seeds**
that ref isn't obviously documented in `bd 1.0.3` — it may be undocumented, in
a newer release, or absent. Find a confirmed seeding recipe before going
further:

```bash
bd version
bd help                       # scan for any git/ref/refs subcommand
bd bootstrap --help           # confirm the refs/dolt/data mention
bd dolt remote --help
bd dolt push --help           # check accepted remote/URL schemes
bd doctor                     # may report on remote state
```

Plausible commands to investigate (substitute the one that exists):

- `bd dolt remote add origin <github-url>` — some `bd` builds may accept a git
  URL directly, and `bd dolt push` then writes `refs/dolt/data` on that remote.
- `bd dolt remote add origin file://$(git rev-parse --absolute-git-dir)` paired
  with an explicit `git push origin refs/dolt/data` step.
- A `bd backup --git-push`-style flow — the stock `.beads/config.yaml` comments
  reference a `backup.git-push` key that may pack and push Dolt data to a git
  remote.

**Stop condition.** If none of these resolves into a working "seed
`refs/dolt/data` on `github.com/0k-software/kix-agents`" recipe, **do not
improvise**. The migration needs a different backend — that's a spec change,
not a plan tweak. Don't proceed to Phase 1 until Phase 0 has yielded a
confirmed command (call it `<seed-command>` for the rest of this plan).

---

## Phase 1 — Sync local state to `main`

```bash
git checkout main && git pull
bd bootstrap                  # rebuilds local Dolt DB from main's issues.jsonl
bd status                     # sanity-check open/closed counts
```

If any open branch still has unmerged `bd` updates in its
`.beads/issues.jsonl`, import them so those deltas land in your local Dolt DB
before you seed the ref — otherwise their claims/closes get dropped:

```bash
git fetch --all --prune
git branch -r
git show origin/<branch>:.beads/issues.jsonl > /tmp/<branch>.jsonl
bd import /tmp/<branch>.jsonl     # merges; newer updated_at wins
# repeat per branch
bd export
bd status
```

End state: on `main`, local Dolt DB reflects the union of all branches' issue
state.

---

## Phase 2 — Configure the git-native Dolt remote (PR 1 to `main`)

Use the `<seed-command>` (and any associated remote-config commands) from
Phase 0. Sketch — substitute the syntax that actually exists in your `bd`:

```bash
bd dolt remote add origin <url-per-phase-0>
bd dolt remote list                  # confirm registered

bd config set federation.remote https://github.com/0k-software/kix-agents.git
bd config validate                   # should pass
```

Notes:

- **Pass a real URL** to `bd config set …remote`. A bare name like `origin`
  sends `bd` into a retry loop.
- The only git-tracked change in this phase is `.beads/config.yaml` (gains the
  `federation.remote` line). The `bd dolt remote add` write goes into the
  embedded Dolt DB under `.beads/embeddeddolt/`, which is `.gitignore`d.

Branch off `main`, commit the `.beads/config.yaml` diff
(`chore(beads): configure federation.remote`), push, open the PR, get it
reviewed, merge. Branch protection is handled via normal review — nothing
special needed.

---

## Phase 3 — Seed `refs/dolt/data` on `origin`, and verify

After PR 1 merges, back on `main`:

```bash
git pull
bd dolt commit -m "seed: initial beads state" || true   # flush pending changes
<seed-command>                                          # writes refs/dolt/data
```

If Phase 0's mechanism splits "pack Dolt data" from "git push the ref", also:

```bash
git push origin refs/dolt/data
```

Confirm the ref exists on GitHub:

```bash
git ls-remote origin 'refs/dolt/*'   # should list refs/dolt/data
```

Acceptance check — verify a fresh clone bootstraps from the ref, not from
`.beads/issues.jsonl`:

```bash
cd /tmp && git clone <repo-url> kix-verify && cd kix-verify
bd bootstrap                         # should report cloning from refs/dolt/data
bd list --status=open | head         # issue state present?
cd - && rm -rf /tmp/kix-verify
```

**Do not proceed to Phase 4 until this passes.** If `bd bootstrap` in the
throwaway clone falls back to `issues.jsonl` (or fails to find the ref), Phase
3 is incomplete — debug or roll back.

---

## Phase 4 — Stop carrying per-branch JSONL churn (PR 2 to `main`)

Make `.beads/issues.jsonl` an explicit periodic snapshot instead of a per-write
artifact. The file stays **tracked** — it's a deliberate, on-`main` backup of
the authoritative store (`refs/dolt/data`) for off-machine readability, the
`bv` viewer, and disaster recovery.

```bash
bd config set export.git-add false     # stop auto-staging on every bd write
```

Update `CLAUDE.md` (outside the managed `<!-- BEGIN/END BEADS INTEGRATION -->`
block — `bd` regenerates that block, so any hand edits inside get clobbered):

- Session Completion checklist: add a one-liner saying issue state now syncs
  via `federation.remote` (`refs/dolt/data` on `origin`), branch-independent —
  `bd dolt push` at session close publishes regardless of branch.
- Replace any "migration status: JSONL stays tracked as working source of
  truth" note with: `.beads/issues.jsonl` is a **periodic on-`main` snapshot**;
  refresh with `bd export && git commit` on `main` when drift matters.
  Authoritative store is `refs/dolt/data` on `origin`.

Run `make autofix` (Prettier gate), commit `.beads/config.yaml` + `CLAUDE.md`,
push, open PR (`bd: stop carrying issue state on feature branches`), review,
merge.

### Steady state after PR 2 merges

- `bd update` / `bd close` on a feature branch no longer modifies the
  working-tree `.beads/issues.jsonl` (because `export.git-add: false`) — no
  per-branch JSONL churn, no more rebase conflicts from beads writes.
- `bd dolt push` at session close publishes issue state to `refs/dolt/data`,
  branch-independent.
- Periodically (release cadence, or whenever someone notices the on-disk
  snapshot is stale), refresh the backup from `main`:

  ```bash
  git checkout main && git pull
  bd bootstrap                                        # pull latest from refs/dolt/data
  bd export                                           # rewrite .beads/issues.jsonl
  git add .beads/issues.jsonl
  git commit -m "chore(beads): refresh issues.jsonl snapshot"
  # push, PR, merge per branch protection
  ```

  Worth wrapping into a `make refresh-beads-snapshot` target later (or a
  scheduled CI job), but neither is required to declare `kxa-8g7` done.

---

## Rollback

- **Phase 2:** revert the config PR — `federation.remote` removed,
  `.beads/config.yaml` back to status quo.
- **Phase 3:** drop the seeded ref — `git push origin :refs/dolt/data` deletes
  it on the remote; `bd dolt remote remove origin` clears the local Dolt-remote
  config.
- **Phase 4:** revert the cut-over PR — `export.git-add` back to `true`, beads
  resumes auto-staging the JSONL.

## Done when

- `bd config validate` passes with `federation.remote` set to the GitHub repo
  URL (or whatever Phase 0 confirmed).
- `git ls-remote origin 'refs/dolt/*'` lists `refs/dolt/data`.
- A fresh clone of `main`: `bd bootstrap` pulls issue state **from the ref**,
  not from `.beads/issues.jsonl`.
- Acceptance test from `spec.md` passes: claim an issue on a feature branch,
  `bd dolt push`; from another clone, `bd dolt pull` + `bd show <id>` shows the
  claim — **without** merging the branch.
- `export.git-add` is `false`; feature branches don't dirty
  `.beads/issues.jsonl`.
- `bd prime` no longer reports "No git remote configured".
- `CLAUDE.md` migration note replaced with the steady-state note.
- `.beads/issues.jsonl` is understood (and documented) as a periodic snapshot,
  not the source of truth.
- `kxa-8g7` closed.
