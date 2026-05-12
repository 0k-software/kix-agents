# Plan: migrate beads off branch-committed JSONL — local execution

Tracked in beads: **kxa-8g7**. Target outcome: [`spec.md`](./spec.md).

**Run this from a normal local checkout — not a cloud/sandbox session.** Two
reasons: (1) the canonical remote URL gets written into `.beads/config.yaml`,
so it must be the real value, not a sandbox artifact; (2) the embedded-Dolt
write path has been flaky in sandboxes (observed: a multi-minute hang + a stray
`dolt sql-server`), and an interrupted Dolt write can leave the DB
inconsistent.

You can drive this yourself, or hand this file to a local Claude session — it's
written to be executable either way.

Throughout: `bd` may print `journal writer has already been closed` warnings
and a `.beads permissions 0755` notice — those are noise, ignore them. Real
errors say `level=error` or exit non-zero.

---

## Phase 0 — Decide the remote backend (5 min, do this first)

Run these to confirm what _your_ installed `bd` supports:

```bash
bd version
bd config validate --help        # lists accepted federation.remote URL schemes
bd bootstrap --help              # does it mention refs/dolt/data on git origin?
bd dolt remote --help
bd federation --help
```

Pick one (see the table in `spec.md` for trade-offs):

- **A. DoltHub** — recommended; the rest of this plan assumes A. You'll need a
  DoltHub account/org and a (public) repo, e.g. `0k-software/kix-agents-beads`.
- **C. git-native `refs/dolt/data`** — only if `bd bootstrap --help` /
  `bd doctor` / release notes confirm your `bd` actually seeds that ref. If so,
  substitute the documented "push dolt data to git origin" command wherever
  Phase 3 says `bd dolt push`, and set `federation.remote` to the repo's git
  URL if that's what it expects. Don't improvise this — verify or skip.
- **D. Disciplined single-branch JSONL** — no new infra: skip Phases 2–3, jump
  to "Phase 4 (variant D)" below.

> If you choose C or D, the commands below differ — read the whole plan first,
> then adapt. The rest assumes **A (DoltHub)**.

---

## Phase 1 — Reconcile in-flight issue state (don't skip)

Issue state today lives in per-branch `issues.jsonl`. Whatever branch you seed
the remote _from_ becomes the canonical baseline — any claim/close that exists
only on another branch and isn't merged in will be **dropped**. So first,
collect the union.

```bash
git fetch --all --prune
git branch -r                    # list remote branches
```

For **each** open branch/PR that has touched `.beads/issues.jsonl` (at minimum
`claude/beads-config-remote-issue-vXPki`, which carries the `kxa-8g7` claim —
check `git log --oneline -- .beads/issues.jsonl` on each):

Option 1 (cleanest): **merge those PRs first**, then do everything below on
`main`.

Option 2 (if PRs aren't ready to merge): import each branch's JSONL into your
local DB so the deltas land in Dolt:

```bash
git checkout main && git pull
bd bootstrap                                   # ensure local DB matches main
git show origin/<branch>:.beads/issues.jsonl > /tmp/<branch>.jsonl
bd import /tmp/<branch>.jsonl                   # merges; newer updated_at wins
# repeat for each branch
bd export                                       # re-write .beads/issues.jsonl
bd status                                       # sanity-check counts
```

End state of Phase 1: you're on `main`, local Dolt DB reflects the union of all
branches' issue state.

---

## Phase 2 — Stand up the shared Dolt remote (DoltHub path)

```bash
# one-time, on dolthub.com: create repo  0k-software/kix-agents-beads  (public)
# install dolt CLI if needed:  https://docs.dolthub.com/introduction/installation
dolt login                                      # browser auth for DoltHub

# from the repo root, on main:
bd dolt remote add origin dolthub://0k-software/kix-agents-beads
bd dolt remote list                             # confirm it's registered
```

Then record it in beads config so fresh clones know where to bootstrap from:

```bash
bd config set federation.remote dolthub://0k-software/kix-agents-beads
# (if your bd uses sync.remote instead — bootstrap --help will say — set that too)
bd config validate                              # should now pass
```

`bd config set` writes the `export.*`/sync keys into `.beads/config.yaml` — it
should now show the `federation.remote`. **Pass a URL, never a bare name like
`origin`** to `bd config set …remote` (a bare name sends `bd` into a retry
loop).

---

## Phase 3 — Seed the remote

```bash
bd dolt commit -m "seed: initial beads state" || true   # flush pending changes
bd dolt push                                            # push to DoltHub
bd dolt status                                          # should show clean / pushed
```

Verify from a throwaway clone:

```bash
cd /tmp && git clone <repo-url> kix-verify && cd kix-verify
bd bootstrap                                             # should clone from the remote
bd list --status=open | head                             # issue state present?
cd - && rm -rf /tmp/kix-verify
```

If `bd bootstrap` in the throwaway clone pulls issue state **without** relying
on the branch's `issues.jsonl`, Phase 3 is done.

---

## Phase 4 — Cut over (this can be a separate commit/PR; file the follow-up bd issue)

Only after Phase 3 verifies:

```bash
bd config set export.git-add false              # stop auto-staging the export
git rm --cached .beads/issues.jsonl             # stop tracking it
echo "issues.jsonl" >> .beads/.gitignore        # (confirm it isn't already there)
```

Update `CLAUDE.md`:

- In the "Session Completion" checklist, keep `bd dolt push` then `git push`
  (already there) — add a one-liner that issue state now syncs via the
  `federation.remote`, branch-independent.
- Replace/remove the "migration status: JSONL stays tracked" note (added under
  the managed beads block) — migration is done.

Commit (`make autofix` first — Prettier gate), push, PR, merge.

After merge, future sessions: `bd prime` should no longer say "No git remote
configured"; `bd dolt push` at session close publishes issue changes regardless
of branch.

### Phase 4 (variant D — disciplined single-branch JSONL, no remote)

If you picked Option D in Phase 0: don't untrack `issues.jsonl`. Instead, add a
rule to `CLAUDE.md` (and the `kix:implement` / `kix:commit` skill bodies): all
`bd` mutations are committed on `main` only (or a dedicated `beads-state`
branch); feature branches never commit `.beads/issues.jsonl` changes (use
`git restore --staged .beads/issues.jsonl` if `bd` auto-staged it on a feature
branch, or set `export.git-add false` and stage it manually only on `main`).
This is weaker than A/C — document it as the interim state and keep kxa-8g7
open / re-scoped.

---

## Rollback

- Phase 2–3 are additive — to back out, `bd dolt remote remove origin`,
  `bd config set federation.remote ""` (or delete the key), drop the DoltHub
  repo. Nothing in git changed yet.
- Phase 4 is reversible by `git revert` of the cut-over commit (`issues.jsonl`
  comes back tracked, `export.git-add` back to `true`).

## Done when

- `bd config validate` passes with a real `federation.remote`.
- The acceptance test in `spec.md` passes (claim on a branch → visible from
  `main` after `bd dolt pull`, no merge).
- `.beads/issues.jsonl` is untracked + gitignored; `export.git-add` is `false`.
- `bd prime` no longer reports "No git remote configured".
- `CLAUDE.md` migration-status note removed; session-close protocol mentions
  the remote.
- kxa-8g7 closed; the Phase-4 follow-up issue closed (or it was folded into one
  PR — your call).
