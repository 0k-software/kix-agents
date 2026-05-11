# Evaluation: phxagents.dev

Tracked in beads: **kxa-9oh** — _Evaluate phxagents.dev_

Sources:

- https://phxagents.dev/
- https://github.com/oliver-kriska/claude-elixir-phoenix

## Identity / GitHub mapping

phxagents.dev is the marketing site for `oliver-kriska/claude-elixir-phoenix`
(MIT, ~300 stars / 24 forks). The site itself returned 403/ECONNREFUSED to
WebFetch (likely Cloudflare bot block), but search snippets and the upstream
README/marketplace.json confirm it is the same project. Author: Oliver Kriska
(oliver@kriska.dev).

## Positioning

Domain-specific Claude Code plugin for Elixir/Phoenix/LiveView developers.
Pitch: "Claude Code is great. But it doesn't know that `assign_new` silently
skips on reconnect..." — i.e. baseline Claude lacks Phoenix-ecosystem
expertise, this plugin adds it via 20 specialist agents + enforceable "Iron
Laws" + auto-loading skills.

## Feature surface

- 20 specialist agents (4 orchestrators, 12 reviewers/architects, 4
  investigators), running in parallel
- 22 Iron Laws — enforceable rules catching N+1 queries, LiveView reconnect
  bugs, Ecto misuse, Oban pitfalls, security gaps
- 41-43 skills that auto-load by file pattern (LiveView skills on `*_live.ex`,
  Ecto skills on schemas, etc.) — no `/load` commands
- Commands: `/phx:plan`, `/phx:work` (with `--continue`), `/phx:review`,
  `/phx:full` (autonomous end-to-end), `/phx:quick`, `/phx:audit`,
  `/phx:investigate`
- Tidewave MCP integration for runtime introspection
- Filesystem-as-state-machine plan namespacing
- Context supervisor pattern: Haiku-based compression of multi-agent output to
  limit context bloat
- Verification hooks (auto-format, auto-compile, Iron Law checks between tasks)
- Self-eval framework in `lab/eval/` (8 dimensions, skills must score ≥0.95 to
  ship) + 52 pytest tests
- ccrider MCP for session analysis / continuous improvement

## Distribution

Pure Claude Code plugin via marketplace. Install:

```
/plugin marketplace add oliver-kriska/claude-elixir-phoenix
/plugin install elixir-phoenix
```

`.claude-plugin/marketplace.json` declares owner `oliver-kriska` with one
plugin `elixir-phoenix` under `./plugins/elixir-phoenix`, category
`development`, tags `[elixir, phoenix, liveview, oban, ecto]`. v2.8.8 for
Claude Code; v3.0.0 promised to add Codex / OpenCode / Pi support. Marketing
site at phxagents.dev. Free / open source — no paid tier visible.

## License

MIT.

## Comparison to kix-agents

Same shape as us at the distribution layer: `marketplace.json` at root + plugin
under a subdir + skill folders. Differences:

- They target a vertical (Elixir/Phoenix); we are language-agnostic workflow
  skills.
- They lean heavily on multi-agent orchestration (20 agents, parallel review
  fan-out, context supervisor); we are single-thread skill invocations.
- They have a real eval harness with a quality gate (≥0.95); we have none.
- They use auto-loading by file glob; our skills require explicit `/kix:*`
  invocation.
- They publish a marketing site; we have only `docs/kix-agents.md`.

## Recommendation

**MONITOR + BORROW PATTERNS.** Not relevant to the superpowers (kxa-tts)
migration — different problem domain (vertical Phoenix vs. general workflow).
Worth filing follow-ups for:

- Adopt their skill-eval pattern (`lab/eval/`, 8-dimension scoring, CI quality
  gate) as a kix-agents quality bar — pairs well with a superpowers-based
  foundation.
- Steal their auto-loading-by-file-context idea for skills that should suggest
  themselves (e.g. on `.bd` files, on `.kix/requests/*.md`).
- Their "Iron Laws" pattern (small, enforceable, named rules) is a tidy
  alternative/complement to long skill prose. Could become "Kix Laws" if
  useful.
- No collaboration angle (different audience), but worth keeping an eye on
  v3.0.0 for cross-agent distribution lessons.
