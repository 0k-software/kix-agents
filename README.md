# kix-agents

Kix skills for every coding agent.

This repo holds Kix's BYO-agent layer: the canonical skills, the per-agent
plugin builds, and the marketplace declaration that makes them installable
without the Kix App.

## Purpose

Where [Kix Flow](docs/kix-run.md) owns _process state_ and Kix Checkpoint owns
_human decisions_, **Kix Run** owns _agent execution_. It is the part of Kix
that makes coding agents (Claude Code, Codex, etc.) actually do the work.

Kix Run is **BYO agent**: it does not ship its own coding agent or LLM. It
wires up the agents you already use by feeding them Kix's skills, invoking them
at the right phase, and capturing their sessions. Kix has opinions about the
_workflow_, not about which agent runs inside it.

Kix Run covers four concerns:

- **Skills** — what agents can do (per-agent assets: slash commands, prompts,
  hooks)
- **Invocation** — how agents are kicked off
- **Orchestration** — coordinating multiple agents, parallel steps, and
  recommendations
- **Sessions** — capturing what each run produced and how

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
  kix-run.md                      ← full Kix Run details
  roadmap.md                      ← MVP + Customization roadmaps
scripts/bump-plugin.js            ← bump plugin.json version
Makefile                          ← setup, autofix, check, bump_plugin
```

## Documentation

- [Kix Run](docs/kix-run.md) — skills, invocation, orchestration, sessions
- [Roadmap](docs/roadmap.md) — MVP Roadmap (MVP 1 → MVP 8) and Customization
  Roadmap (V1 → V5)
