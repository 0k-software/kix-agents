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
claude-code/                      ← Claude Code plugin (manifest + commands + …)
  .claude-plugin/plugin.json
  commands/
  templates/
docs/
  kix-agents.md                   ← what this repo is and how it fits in Kix
  roadmap.md                      ← MVP + Customization roadmaps
scripts/bump-plugin.js            ← bump plugin.json version
Makefile                          ← setup, autofix, check, bump
```

## Documentation

- [Kix Agents](docs/kix-agents.md) — purpose, what it ships, install,
  fork-don't-edit, how Run and Flow consume it
- [Roadmap](docs/roadmap.md) — MVP Roadmap (MVP 1 → MVP 8) and Customization
  Roadmap (V1 → V5)
