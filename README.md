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

## Documentation

- [Kix Agents](docs/kix-agents.md) — purpose, what it ships, install, and how
  Kix invokes the skills

Roadmap and tasks live in [beads](https://github.com/steveyegge/beads); run
`bd ready` to see what's open.
