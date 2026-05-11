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

- `/caveman [lite|full|ultra|wenyan]` — sticky verbosity levels. **Default mode
  after install is `full`** (set by the SessionStart hook
  `src/hooks/caveman-activate.js`, which writes `~/.claude/.caveman-active`
  with `mode=full` on first run). `lite` keeps articles and full sentences,
  `full` allows fragments and short words, `ultra` uses abbreviations and
  arrows for causality, `wenyan` is a classical-Chinese variant.
- `/caveman-commit` — terse Conventional Commit messages (slash-only — outputs
  a code block; never runs `git commit`/`git add`)
- `/caveman-review` — one-line PR comments with severity prefixes (🔴 bug, 🟡
  risk, 🔵 nit, ❓ q)
- `/caveman-stats` — token savings + USD tracking, with `--share` flag
- `/caveman-compress <file>` — rewrite memory files (e.g. CLAUDE.md) into
  caveman-speak; single mode (no lite/full/ultra variant for compress);
  preserves code blocks, inline code, URLs, file paths, commands, technical
  terms, proper nouns, dates, versions exactly; backs up the original to
  `FILE.original.md`
- `caveman-shrink` — separate npm package: MCP middleware that wraps any MCP
  server and compresses tool descriptions
- `cavecrew-*` subagents (investigator/builder/reviewer) — ~60% fewer tokens
  than vanilla
- Claude Code statusline badge: `[CAVEMAN] ⛏ 12.4k`
- Auto-activates via SessionStart hook in Claude Code; per-session `/caveman`
  for other agents
- Code blocks, commits, and PR descriptions are **always written normally**
  regardless of active mode

Important: `caveman-commit` and `caveman-review` are user-facing slash commands
only. They have no documented library/programmatic API — our own skills cannot
invoke them as a function. To get caveman-style output from inside
`/kix:commit` or `/kix:fix-pr`, the right shape is repo-level instructions
(CLAUDE.md / skill bodies) telling Claude to write in caveman style, **not** a
sub-call into the caveman plugin.

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

## License & activity

MIT. README is marketing-polished — but the plugin manifests, installer, and
directory layout are real. Treat dynamic star/fork badges cautiously; the
project itself is active and shippable.

## How we want to use it (this repo)

Reframe: **don't borrow patterns, use the plugin directly in this repo.** Don't
enforce on downstream `kix-agents` consumers (unlike a workflow plugin such as
superpowers). Specifically:

1. **CLAUDE.md compression.** Single-shot: run `/caveman-compress CLAUDE.md` in
   this repo. The skill leaves a `CLAUDE.md.original.md` backup. Re-run when
   the file drifts. Saves per-session input tokens in every session
   bootstrapping context here. Tracked: see follow-up issue.
2. **Commit-message style.** Our `/kix:commit` skill currently produces
   conventional but verbose messages. Add a CLAUDE.md (or skill-level) note
   telling Claude to emit caveman-style commit messages in this repo
   specifically. We cannot call `/caveman-commit` from inside `/kix:commit` (no
   library API), so this is an instruction adjustment, not a wire-up. Tracked:
   see follow-up issue.
3. **PR-reply compression.** Our `/kix:fix-pr` skill posts replies on review
   comments that often run to multiple paragraphs. Same approach as commits:
   add an instruction to the skill body to write replies in caveman-review
   style (one-line per finding, severity prefix when applicable). Tracked: see
   follow-up issue.
4. **Default conversation verbosity.** Install caveman locally for contributors
   who want it; the SessionStart hook makes `full` mode sticky. Don't enforce —
   this is per-developer preference. Documented in `docs/kix-agents.md` or
   contributor notes.

## Recommendation

**ADOPT LOCALLY for this repo. Don't enforce on consumers.** Concrete
follow-ups (filed in beads):

- **kxa-1bx** — Run `/caveman-compress CLAUDE.md` and commit the result
- **kxa-3xx** — Update `/kix:commit` and `/kix:fix-pr` skill bodies to prefer
  caveman-style output
- **kxa-e68** — Document optional caveman install for contributors in
  `docs/kix-agents.md`

A sister project, **Cave Kit** (`JuliusBrussee/cavekit`), is being evaluated
separately as a candidate workflow foundation alongside obra/superpowers — see
kxa-eal. That decision is independent of caveman adoption here.
