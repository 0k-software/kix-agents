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
- **git `pre-commit` hook** — `.git-hooks/pre-commit` (rejects a dirty tree,
  runs `make autofix`, re-stages, runs `make check`), installed into the repo's
  hooks dir.
- **Claude Code SessionStart / PreCompact hooks** — `.claude/settings.json`
  entries plus
  `.claude/hooks/{session-start,install-dolt,install-bd,bootstrap-bd}.sh`,
  which on session start install the `dolt` and `bd` CLIs into `~/.local/bin`
  and bootstrap the beads database, and run `bd prime` on session start /
  pre-compact — so cloud Claude Code sessions can run `bd`.
- **Optionally** — `bd init` to give the repo a beads issue tracker, and a
  Beads / session-completion / non-interactive-shell section in `CLAUDE.md` (or
  `AGENTS.md`).

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
   `.prettierignore`, `.github/workflows/check.yml`, `.git-hooks/pre-commit`,
   `.claude/settings.json`, `.claude/hooks/`, `.beads/`, `CLAUDE.md` /
   `AGENTS.md`.
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
bash "$SKILL_DIR/setup.sh"
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
- **Existing `pre-commit` hook** (`.git-hooks/pre-commit` or the repo's real
  hooks dir) that does something else — don't clobber it. Explain the conflict
  and ask the user whether to (a) chain the Prettier steps into the existing
  hook, (b) replace it, or (c) skip the hook part of this install.
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

## Step 6 — CLAUDE.md / AGENTS.md (optional)

Offer to add a Beads / session-completion / non-interactive-shell section to
the repo's agent-instructions file (create `CLAUDE.md` if neither it nor
`AGENTS.md` exists). Use `$SKILL_DIR/assets/CLAUDE.kix-section.md` as the
starting text; drop the leading HTML comment, and adapt the project-specific
parts — in particular the **Build & Test** block: keep the Prettier targets,
and either fill in the repo's real build/test commands or leave the "replace
this section" note for the maintainers. Don't copy kix-agents-only content (its
release pipeline, its architecture overview). In interactive mode, show the
proposed insertion and wait for an OK before writing.

If the file already has a Beads section, leave it alone.

## Step 7 — Verify

1. The script already copied `.git-hooks/*` into the repo's real hooks dir —
   confirm the `pre-commit` hook is there and executable
   (`test -x "$(git rev-parse --git-path hooks)/pre-commit"`).
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
   - **git `pre-commit` hook** — rejects a dirty tree, runs `make autofix`, re-stages, runs `make check`.
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
