# kix-agents

Kix skills for every coding agent.

This repo is the open-source library of agents, skills, and prompts authored
for the Kix workflow. It ships the canonical defaults that Kix App later
compiles and invokes, and it doubles as a **direct interface to Kix from a
coding agent prompt** — slash commands and prompt skills that capture and move
work without going through the App.

See [docs/kix-agents.md](docs/kix-agents.md) for the full picture.

## Install (Claude Code)

This repo declares itself as a Claude Code marketplace via
`.claude-plugin/marketplace.json` at the root; the plugin lives at
`claude-code/`. From any plain Claude Code setup:

```text
/plugin marketplace add 0k-software/kix-agents
/plugin install kix@kix-agents
```

## Configuration

`/kix:commit` and `/kix:rebase` each run in one of two modes:

- `interactive` — stop and ask: `/kix:commit` aborts on a failed commit,
  `/kix:rebase` asks you how to resolve each conflict.
- `auto` — fix it without asking: `/kix:commit` repairs pre-commit hook
  failures and retries, `/kix:rebase` resolves conflicts on its own.

A leading `!` (auto) or `?` (interactive) picks the mode for one run —
`/kix:commit ! reason`, `/kix:rebase ? main`. Without a marker, each skill
resolves its mode like this (first match wins):

1. The session mode — set by `--mode <mode>` earlier in the same session.
2. The `KIX_COMMIT_MODE` / `KIX_REBASE_MODE` environment variable, which Claude
   Code builds from the `env` blocks of its settings files, highest first:
   - `.claude/settings.local.json` — this repo, just you (not committed)
   - `.claude/settings.json` — this repo, the whole team (committed)
   - `~/.claude/settings.json` — you, every project
3. `interactive`.

Each skill shows, sets and saves its own mode, so you don't edit JSON by hand:

```text
/kix:rebase --mode                        ← shows the mode and where it comes from
/kix:rebase --mode auto                   ← auto for the rest of this session
/kix:rebase --mode auto --save local      ← …and saves it to .claude/settings.local.json
/kix:commit --mode auto --save project    ← …to .claude/settings.json (commit it)
/kix:commit --mode interactive --save user ← …to ~/.claude/settings.json
/kix:commit --mode --save user            ← saves the current mode as is
```

A saved value applies from the next session, since Claude Code reads `env` at
session start; the session mode covers the current one.

## Layout

```text
.claude-plugin/marketplace.json   ← marketplace declaration
.claude/settings.json             ← enables the kix@kix-agents plugin locally
.codex/config.toml                ← Codex SessionStart hook pointing at .kix/hooks/
.kix/hooks/session-start.sh       ← shared SessionStart bootstrap entrypoint
claude-code/                      ← Claude Code plugin (manifest + skills + …)
  .claude-plugin/plugin.json
  bin/                            ← on the Bash PATH while enabled (project-code)
  hooks/hooks.json                ← plugin hooks (title prompt, Remote Control off)
  skills/
  templates/
docs/
  kix-agents.md                   ← what this repo is and how it fits in Kix
scripts/bump-plugin.js            ← bump plugin.json version
Makefile                          ← setup, autofix, check, test, bump
```

## Known non-issues

Behaviour that looks like a bug but is working as designed — check here before
filing an issue.

- **`bd prime` output doesn't match the stock bd output.** `/kix:setup`
  installs a `.beads/PRIME.md`, which replaces the whole `bd prime` output. Its
  close protocol parks branch work on its PR and closes the issue only once
  that PR merges.
- **`bd config set no-git-ops true` does nothing.** The `PRIME.md` override
  replaces the config-driven sections along with everything else. Edit
  `.beads/PRIME.md` to change the git posture.
- **Persistent memories are missing after compaction in Codex.** Codex has no
  `PreCompact` hook, so only Claude Code re-injects them mid-session (via
  `.kix/hooks/prime.sh` in `.claude/settings.json`). In Codex they come back at
  the next session start. Run `bd prime` by hand to pull them in sooner.
- **The close-protocol wording in `CLAUDE.md` reverted.** That section sits
  inside a `BEGIN BEADS INTEGRATION` block that `bd setup claude` regenerates
  from its own template. `.beads/PRIME.md` is the durable source of truth; just
  re-apply the wording if you re-run that command.
- **`make check` fails complaining about a bd version stamp.** The bd pin in
  `.kix/hooks/install-bd.sh` moved, so `.beads/PRIME.md` — a hand-edited
  snapshot of one bd version's output — may be stale. This is deliberate and
  the fix is manual: `bd prime --export`, diff it against `PRIME.md`, merge in
  what you want, then bump the stamp. A newer locally-installed bd does **not**
  trip it; only the pin does.

## Documentation

- [Kix Agents](docs/kix-agents.md) — purpose, what it ships, install, and how
  Kix invokes the skills

Roadmap and tasks live in [beads](https://github.com/steveyegge/beads); run
`bd ready` to see what's open.
