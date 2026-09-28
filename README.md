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
`/kix:commit ! reason`, `/kix:rebase ? main`. Without a marker, each skill uses
its configured default, resolved like this (first match wins):

1. Environment variable — `KIX_COMMIT_MODE` / `KIX_REBASE_MODE`.
2. User config file — `$XDG_CONFIG_HOME/kix/config.json`, falling back to
   `~/.config/kix/config.json` (`%APPDATA%\kix\config.json` on Windows):

   ```json
   {
     "commit": { "defaultMode": "auto" },
     "rebase": { "defaultMode": "interactive" }
   }
   ```

3. `interactive`.

For a per-project default, set the environment variable in the repo's
`.claude/settings.json` (shared with the team) or `.claude/settings.local.json`
(just you) — Claude Code exports its `env` block into the session, so it
outranks the user config file:

```json
{
  "env": { "KIX_REBASE_MODE": "auto" }
}
```

The same `env` block in `~/.claude/settings.json` sets a user-wide default.

You don't have to edit these files by hand — each skill sets its own default:

```text
/kix:rebase --mode auto             ← writes rebase.defaultMode to the config file
/kix:commit --mode interactive      ← writes commit.defaultMode
/kix:rebase --mode auto --project   ← writes KIX_REBASE_MODE to .claude/settings.local.json
/kix:commit --mode                  ← shows the current default and where it comes from
```

A `--project` setting takes effect in the next session, since Claude Code reads
`env` at session start.

## Layout

```text
.claude-plugin/marketplace.json   ← marketplace declaration
.claude/settings.json             ← enables the kix@kix-agents plugin locally
.codex/config.toml                ← Codex SessionStart hook pointing at .kix/hooks/
.kix/hooks/session-start.sh       ← shared SessionStart bootstrap entrypoint
claude-code/                      ← Claude Code plugin (manifest + skills + …)
  .claude-plugin/plugin.json
  skills/
  templates/
docs/
  kix-agents.md                   ← what this repo is and how it fits in Kix
scripts/bump-plugin.js            ← bump plugin.json version
Makefile                          ← setup, autofix, check, bump
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
