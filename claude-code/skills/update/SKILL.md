---
description: Use when the user types /kix:update, or asks to upgrade, refresh or bring an existing Kix repo up to the current Kix tooling (hooks, pre-commit gate, settings.json entries). First installs go through kix:setup.
argument-hint: [!]
---

# Update Kix repo tooling

Bring a repository that **already has Kix** up to the tooling the current
kix-agents ships: the Prettier gate, the merged `pre-commit` hook, the
`.kix/hooks/` scripts, the Codex block and the `.claude/settings.json` hook
entries. It reruns the idempotent steps of `kix:setup`'s `setup.sh`, in its
`--update` mode, and commits the result on a branch for `/kix:ship`.

Not here — first install only, `kix:setup`'s job: `bd init`, the `CLAUDE.md`
Beads section, the `AGENTS.md` → `CLAUDE.md` layout, enabling the plugin, the
push and the PR. A repo without Kix gets refused; point the user at
`/kix:setup`.

## Invocation modes

- `/kix:update` — interactive: confirm before editing a file the script left
  for a human (a `Makefile` merge, a conflicting hook).
- `/kix:update!` — autonomous: take the obvious path at each step. Still never
  silently overwrite a non-kix file — call it out.

A leading `!` in `$ARGUMENTS` sets force mode.

## Step 1 — Preflight

1. The working tree must be clean (`git status --porcelain`); if dirty, stop
   and ask the user to commit first.
2. Kix must be installed: `.kix/hooks/session-start.sh` exists. If not, stop
   with: "Kix is not installed here. If you want to use Kix to manage tasks and
   the software development lifecycle in this repo, run /kix:setup."
3. Default branch:
   `git symbolic-ref refs/remotes/origin/HEAD | sed 's@^refs/remotes/origin/@@'`,
   falling back to `main`; `git fetch origin` so it is current.
4. `SETUP_DIR` is `${CLAUDE_PLUGIN_ROOT}/skills/setup`. Verify
   `$SETUP_DIR/setup.sh` and `$SETUP_DIR/assets/` exist; if not, stop and say
   so.

## Step 2 — Branch

```bash
git switch -c kix/update "origin/{default-branch}"
```

If `kix/update` already exists, `git switch kix/update` and continue — the
script is idempotent.

## Step 3 — Run the script

```bash
KIX_SETUP_QUIET=1 bash "$SETUP_DIR/setup.sh" --update
```

It reports each file written or kept, the Codex and `.claude/settings.json`
merges, and a `needs manual attention` list at the end.

## Step 4 — Finish what the script left

Work through `needs manual attention` the way `kix:setup`'s Step 4 does: a
`Makefile` missing the kix targets, a `pre-commit` hook or `core.hooksPath` the
script would not touch, a near-duplicate entry in `.claude/settings.json` or
`.codex/config.toml`. Ask before each in interactive mode.

## Step 5 — Verify

1. `make autofix`, then `make check`.
2. `git status` and `git diff` — every change should come from the update. An
   unexpected rewrite of a repo-owned file gets resolved now.
3. Nothing changed → say the repo is already current, switch back to the branch
   you started on, delete `kix/update`, and stop.

## Step 6 — Commit

Stage everything and commit in one call (the installed `pre-commit` hook
rejects a dirty tree):

```bash
git add -A && git commit -m "chore: update Kix repo tooling"
```

The message body lists what changed (the scripts refreshed, the settings
entries added or dropped). No push, no PR.

## Step 7 — Report

One short list: what changed, what still needs a human, the branch. Then offer
`/kix:ship` to land `kix/update` on the default branch.
