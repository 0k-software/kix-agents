# Evaluation: JuliusBrussee/caveman

Tracked in beads: **kxa-x83** — _Evaluate caveman (JuliusBrussee/caveman)_

Source: https://github.com/JuliusBrussee/caveman

## Positioning

"why use many token when few do trick" — a Claude Code skill/plugin that
compresses agent OUTPUT tokens by ~65-75% while preserving technical accuracy.
Audience: any Claude Code (or Codex, Gemini, Cursor, Windsurf, Cline, Copilot)
user who wants cheaper, faster, more readable replies. Not a workflow
framework; a single cross-cutting behavior modifier.

## Feature surface

- `/caveman [lite|full|ultra|wenyan]` — sticky verbosity levels
- `/caveman-commit` — terse Conventional Commit messages
- `/caveman-review` — one-line PR comments
- `/caveman-stats` — token savings + USD tracking, with `--share` flag
- `/caveman-compress <file>` — rewrite memory files (e.g. CLAUDE.md) into
  caveman-speak; ~46% input-token reduction every session
- `caveman-shrink` — separate npm package: MCP middleware that wraps any MCP
  server and compresses tool descriptions
- `cavecrew-*` subagents (investigator/builder/reviewer) — ~60% fewer tokens
  than vanilla
- Claude Code statusline badge: `[CAVEMAN] ⛏ 12.4k`
- Auto-activates via SessionStart hook in Claude Code; per-session `/caveman`
  for other agents

## Distribution

Multi-modal:

1. Cross-agent one-line installer (`install.sh`/`install.ps1`, Node ≥18) that
   drops files into every detected agent's config dir.
2. Native Claude Code plugin — has `.claude-plugin/plugin.json` +
   `marketplace.json`. Marketplace name `caveman`, single plugin `caveman`
   (category: productivity), `source: ./`. SessionStart + UserPromptSubmit
   hooks shell out to `node src/hooks/*.js`.
3. `caveman-shrink` is a published npm package (MCP middleware).
4. OpenClaw integration via `--only openclaw` flag writes to
   `~/.openclaw/workspace/`.

Top-level layout: `.claude-plugin/`, `plugins/caveman/`, `skills/`,
`commands/`, `agents/`, `bin/`, `src/`, `evals/`, `benchmarks/`, plus per-agent
dirs `.codex/`, `.junie/skills/cavecrew/`, `.kiro/skills/cavecrew/`,
`.roo/skills/cavecrew/`.

## License & activity

MIT. As fetched: README badges + repo page show ~57.9k stars / 3.2k forks.
Treat star count cautiously (the WebFetch summary inflated some figures; the
badges are dynamic shields). Self-published benchmarks and an arxiv-style
citation in README. README is clearly marketing-polished — but the plugin
manifests, installer, and directory layout are real.

## Comparison to kix-agents

Orthogonal, not competitive. We ship a workflow plugin (kix-agents:
`marketplace.json` + `plugin.json` + skill folders for `/kix:*` commands).
Caveman ships a behavior-shaping plugin in the same Claude Code marketplace
format. They could be installed side-by-side.

Patterns we already share: top-level `.claude-plugin/marketplace.json`, plugin
under a subdir, skill folders with frontmatter.

Patterns we don't use: SessionStart hooks running Node, `caveman-compress` for
shrinking CLAUDE.md, eval harness (`evals/`), benchmarks dir, statusline
integration.

## Recommendation

**MONITOR + BORROW SELECTIVELY.** Not relevant to the superpowers (kxa-tts)
migration decision — different problem domain. Specific takeaways worth filing
as follow-ups:

- Steal the `caveman-compress` idea: a `/kix:compress` skill that shrinks our
  long CLAUDE.md / skill bodies could materially reduce per-session input
  tokens (we have several verbose skills).
- Their `evals/` harness pattern (three-arm baseline/terse/skill comparison) is
  a model for evaluating skill quality post-superpowers migration.
- No reason to reach out — different scope, healthy upstream.
