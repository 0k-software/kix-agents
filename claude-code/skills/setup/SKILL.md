---
description: Install the Kix repo tooling (Prettier gate, git pre-commit hook, Claude SessionStart hooks that install dolt + bd and bootstrap beads, optional bd init) into the current repository, then open a PR.
argument-hint: [!]
---

# Install Kix repo tooling

Set up, in the **current repository**, the same baseline tooling kix-agents
runs on SessionStart, then open a PR with the changes:

- **Prettier formatting gate** — `.prettierrc.json`, `.prettierignore`, `setup`
  / `autofix` / `check` targets in the `Makefile`, and a
  `.github/workflows/check.yml` CI workflow that runs `make check`.
- **`pre-commit` hook** — one merged hook: beads' DB→JSONL sync section (a
  no-op when `bd` isn't installed) followed by the Prettier gate (reject a
  dirty tree → `make autofix` → re-stage → `make check`). Lives in
  `.beads/hooks/` with `core.hooksPath` pointed at it when the repo has a beads
  tracker (so beads' other hooks run too), otherwise in `.git-hooks/` and
  copied into the repo's real hooks dir.
- **Claude Code SessionStart / PreCompact hooks** — `.claude/settings.json`
  entries plus
  `.claude/hooks/{session-start,install-dolt,install-bd,bootstrap-bd}.sh`,
  which on session start install the `dolt` and `bd` CLIs into `~/.local/bin`
  and bootstrap the beads database, and run `bd prime` on session start /
  pre-compact — so cloud Claude Code sessions can run `bd`.
- **`AGENTS.md` → `CLAUDE.md` symlink** — enforces one canonical
  agent-instructions file so the two don't drift (creates an empty `CLAUDE.md`
  if neither file exists; if the repo has only `AGENTS.md`, promotes it).
- **Optionally** — `bd init` to give the repo a beads issue tracker, and a
  Beads / session-completion / non-interactive-shell section in `CLAUDE.md`.

The mechanical file changes are done by the bundled script `setup.sh` (next to
this `SKILL.md`); this skill runs it, then handles the merges the script can't
do safely, the optional `bd init` + `CLAUDE.md` edits, and the commit / push /
PR.

## Invocation modes

- `/kix:setup` — interactive: confirm before `bd init`, before editing files
  that already exist, and before pushing.
- `/kix:setup!` — autonomous: take the obvious path at each step. Still never
  silently overwrite a pre-existing, non-kix file — call it out.

Parse `$ARGUMENTS`: a leading `!` (it may be the whole of `$ARGUMENTS`) sets
**force mode**; strip it and any surrounding whitespace before continuing.

## Step 1 — Preflight

1. Confirm the working tree is clean (`git status --porcelain`). If dirty,
   abort and tell the user to commit or stash first — this skill creates a
   branch and commits.
2. Identify the repo: `git remote get-url origin` → `{owner}/{repo}`; default
   branch via
   `git symbolic-ref refs/remotes/origin/HEAD | sed 's@^refs/remotes/origin/@@'`,
   falling back to `main` (and `git fetch origin` so it's current).
3. Note what's already present (so the report is accurate, and so Step 4 knows
   what the script will have skipped): `Makefile`, `.prettierrc.json`,
   `.prettierignore`, `.github/workflows/check.yml`, an existing `pre-commit`
   hook (`.git-hooks/pre-commit`, `.beads/hooks/pre-commit`, or whatever
   `core.hooksPath` points at), `.claude/settings.json`, `.claude/hooks/`,
   `.beads/`, `CLAUDE.md` / `AGENTS.md`.
4. Locate the bundled assets. This skill ships with a sibling `setup.sh` and an
   `assets/` directory. Resolve `SKILL_DIR` to the directory containing this
   `SKILL.md` — for a plugin install that is
   `${CLAUDE_PLUGIN_ROOT}/skills/setup`. Verify `$SKILL_DIR/setup.sh` and
   `$SKILL_DIR/assets/` exist; if not, stop and say so.

## Step 2 — Branch

Create and switch to `kix/setup`, based on the up-to-date default branch:

```bash
git switch -c kix/setup "origin/{default-branch}"
```

If that branch already exists (a re-run), `git switch kix/setup` and continue —
the script is idempotent.

## Step 3 — Run the installer script

```bash
KIX_SETUP_QUIET=1 bash "$SKILL_DIR/setup.sh"
```

Read its output carefully. It reports each file it created, each it left
untouched, the `.claude/settings.json` merge result, and — at the end — a
`needs manual attention` list. The most common entry there is **an existing
`Makefile`**: the script will not edit it, it just prints the `setup` /
`autofix` / `check` targets that need merging in.

## Step 4 — Finish what the script left for you

Work through the script's `needs manual attention` list, plus:

- **Existing `Makefile` missing the kix targets** — merge in `setup`,
  `autofix`, `check` (and `all: autofix check` if there's no `all:` target).
  Preserve the repo's own targets and `.PHONY` line; if a target name collides
  with one the repo already defines, stop and ask the user how to reconcile
  rather than guessing.
- **Existing `pre-commit` hook that does something else** (in `.git-hooks/`,
  the repo's real hooks dir, or wherever `core.hooksPath` points) — don't
  clobber it. Explain the conflict and ask the user whether to (a) chain the
  beads-sync + Prettier steps into the existing hook, (b) replace it, or (c)
  skip the hook part of this install. Same for a `core.hooksPath` already
  pointing somewhere other than `.beads/hooks/` — the script won't repoint it;
  wire the merged hook (`$SKILL_DIR/assets/pre-commit`) into that dir yourself.
- **`.claude/settings.json`** — open it and sanity-check the merge. If it now
  has a near-duplicate `SessionStart` entry (e.g. the repo already had one with
  a slightly different path to `session-start.sh`), de-dupe by hand. Optionally
  add `"kix@kix-agents": true` under `enabledPlugins` so collaborators get the
  `/kix:*` skills — mention it; do it in force mode, ask otherwise.
- **`.gitignore`** — if `bd init` hasn't run yet, nothing to do here; `bd init`
  in Step 5 adds the beads/dolt ignores itself.

## Step 5 — Beads tracker (optional)

If `.beads/` does **not** already exist, the repo has no beads tracker yet.
Offer to create one:

```bash
bd init
```

In **force mode**, run it. In **interactive mode**, ask first and explain the
trade-off: `bd init` creates a Dolt-backed database plus a tracked
`.beads/issues.jsonl` — it's a real commitment, not just a config file. If the
user declines, that's fine: the installed `bootstrap-bd.sh` hook is a no-op
until `.beads/` exists, so nothing breaks.

If you do run `bd init` (or `.beads/` already existed), make sure
`.beads/issues.jsonl` and `.beads/config.yaml` / `.beads/metadata.json` end up
staged in Step 8, and that `.beads/`'s own `.gitignore` (created by `bd init`)
is committed.

If `bd init` ran **just now** in this step, re-run
`KIX_SETUP_QUIET=1 bash "$SKILL_DIR/setup.sh"` — it's idempotent, and now that
`.beads/hooks/` exists it relocates the merged `pre-commit` hook into
`.beads/hooks/pre-commit` and points `core.hooksPath` there (so beads' own
hooks run too). Then `git rm` the now-bypassed `.git-hooks/pre-commit` (and the
empty `.git-hooks/` dir).

## Step 6 — CLAUDE.md / AGENTS.md (optional)

`setup.sh` already enforces the canonical layout: **`CLAUDE.md` is the file,
`AGENTS.md` is a symlink to it.** If neither existed it created an empty
`CLAUDE.md`; if the repo had only an `AGENTS.md` it promoted that file's
content into `CLAUDE.md` and replaced `AGENTS.md` with the symlink. If both
existed as regular files the script left them alone and flagged it — merge them
by hand, then `rm AGENTS.md && ln -s CLAUDE.md AGENTS.md`.

Once `CLAUDE.md` is the canonical file, offer to add a Beads /
session-completion / non-interactive-shell section to it. Use
`$SKILL_DIR/assets/CLAUDE.kix-section.md` as the starting text; drop the
leading HTML comment, and adapt the project-specific parts — in particular the
**Build & Test** block: keep the Prettier targets, and either fill in the
repo's real build/test commands or leave the "replace this section" note for
the maintainers. Don't copy kix-agents-only content (its release pipeline, its
architecture overview). In interactive mode, show the proposed insertion and
wait for an OK before writing.

If the file already has a Beads section, leave it alone.

## Step 7 — Verify

1. Confirm the merged `pre-commit` hook is active and executable:
   `hd="$(git config --get core.hooksPath || git rev-parse --git-path hooks)"; test -x "$hd/pre-commit"`.
   (`core.hooksPath` is `.beads/hooks` when there's a beads tracker, otherwise
   unset and the hook sits in the repo's real hooks dir.)
2. Run the formatting gate: `make autofix` then `make check`. (If you ended up
   not creating/merging a `Makefile`, run `npx prettier --write .` then
   `npx prettier --check .` instead.) Fix any drift `autofix` introduces in the
   files this skill added.
3. `git status` — review the **complete** set of changes. Everything about to
   be staged should be intentional. If the script overwrote an existing file
   you didn't expect, resolve it now.

## Step 8 — Commit & PR

1. Stage everything (`git add -A`) and commit. If `/kix:commit` is available,
   use it (pass a context like
   `install Kix repo tooling: prettier gate, pre-commit hook, SessionStart bd/dolt bootstrap`);
   otherwise `git commit` with that as the message. Note: the `pre-commit` hook
   you just installed rejects a dirty tree — stage everything first.
2. Push: `git push -u origin kix/setup`. Retry on transient network errors with
   backoff.
3. Open a PR against the default branch:

   ```bash
   TOKEN="${GITHUB_TOKEN:-${GH_TOKEN:-$(gh auth token 2>/dev/null || true)}}"
   gh pr create --base "{default-branch}" --head kix/setup \
     --title "Install Kix repo tooling" \
     --body "$(cat <<'EOF'
   ## What

   Adds the baseline Kix tooling (mirrors kix-agents' SessionStart setup):

   - **Prettier formatting gate** — `.prettierrc.json`, `.prettierignore`, `make autofix` / `make check`, and a `.github/workflows/check.yml` CI workflow.
   - **`pre-commit` hook** — beads DB→JSONL sync (no-op without `bd`) + Prettier gate (reject a dirty tree → `make autofix` → re-stage → `make check`); wired via `core.hooksPath` → `.beads/hooks/` if there's a beads tracker, else copied into the repo's hooks dir.
   - **Claude Code SessionStart / PreCompact hooks** — `.claude/hooks/*.sh` that install the `dolt` + `bd` CLIs into `~/.local/bin` and bootstrap the beads DB; `bd prime` on session start / pre-compact.

   ## After merging

   - Run `make setup` once after pulling (the SessionStart hook does this automatically inside Claude Code).
   - Enable the `kix` plugin in your Claude Code to get the `/kix:*` skills.

   Generated by the `/kix:setup` skill.
   EOF
   )"
   ```

   Mention in the PR body whether `bd init` was run and whether `CLAUDE.md` was
   touched, if so. If `gh` isn't available, push the branch and print the
   compare URL
   (`https://github.com/{owner}/{repo}/compare/{default-branch}...kix/setup?expand=1`)
   so the user can open the PR by hand.

## Step 9 — Report

Summarise: which files were created vs. left alone, whether `bd init` ran,
whether `CLAUDE.md`/`AGENTS.md` was edited, the branch name, and the PR URL.
Explicitly call out anything still needing a human decision — Makefile merges
you couldn't do safely, a conflicting pre-commit hook, a near-duplicate
settings.json entry, etc.
