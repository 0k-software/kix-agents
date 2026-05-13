# Changelog

All notable changes to this project will be documented in this file.

The format is based on
[Keep a Changelog](https://keepachangelog.com/en/1.1.0/).

## [Unreleased]

### Added

- `kix:save-session` skill (`claude-code/skills/save-session/SKILL.md`) —
  invoked as `/kix:save-session [owner/repo]`; archives the current session
  into a per-session folder `docs/conversations/<stem>/` in a target repo. When
  run from Claude Code on a feature branch (the branch that holds this
  session's work) the archive is committed straight onto that branch so it
  rides along with that branch's PR; only when there's no work branch — you
  started on the default branch, or there's no checkout (a chat session) — does
  it get its own `claude/save-session-<stem>` branch + PR. The folder holds a
  `summary.md` (via the `caveman` summarizer if available, else summarized
  directly) plus the verbatim conversation: the Claude Code transcript
  `.jsonl`, gzipped and committed as `raw.jsonl.gz` (~4–5× smaller, keeps the
  repo from ballooning — no Git LFS needed) — in a hosted/cloud sandbox
  (`CLAUDE_CODE_REMOTE`) where each turn is a fresh `claude --resume`, the
  largest file in the project dir (the complete cumulative transcript,
  append-only across compactions); or, when there's no transcript at all (a
  chat session), a verbatim `raw.md` render from the host's conversation tool /
  Anthropic API (`ANTHROPIC_API_KEY`) / the in-context view. Archives are keyed
  by the session id (`CLAUDE_CODE_REMOTE_SESSION_ID` in a hosted sandbox — the
  only id stable across turns), so re-saving the same session updates that
  folder in place instead of duplicating. Repo writes go through the available
  GitHub tools; when the repo arg is omitted or a bare name is given the target
  is resolved by searching accessible repos and confirmed with the user before
  any write. Tracked in `kxa-bpt`.
- Caveman plugin wired into the repo dev setup — `.claude/settings.json` now
  registers the `caveman` marketplace (`JuliusBrussee/caveman`) via
  `extraKnownMarketplaces` and enables `caveman@caveman`, so cloud and local
  Claude Code sessions pick up caveman's `full` mode (agent-output token
  compression) automatically. Code blocks, commits, and PR descriptions are
  still written normally.

### Changed

- `kix:commit` now bundles the current Claude Code session's archive into every
  commit it makes — `gzip`s the largest project transcript to
  `docs/conversations/<stem>/raw.jsonl.gz` and writes `summary.md` (from
  context), `git add`s them, and commits the lot together with the rest of the
  staged changes (the session is the work behind the commit). No-op for plain
  chat sessions (no transcript). Skip behaviour and the stem / session-id rules
  follow `kix:save-session`.

## [0.2.2] — 2026-05-11

### Added

- `kix:fix-pr` skill (`claude-code/skills/fix-pr/SKILL.md`) — ported from kata;
  addresses unresolved review comments on a PR, verifying each suggestion
  before implementing and routing commits through `kix:commit`.
- `kix:fix`, `kix:address`, and `kix:address-pr` aliases — short verb-form
  aliases for `kix:fix-pr`.
- `kix:triage` skill (`claude-code/skills/triage/SKILL.md`) — walks every open
  `bd todo` (untyped `task` issue) and routes each to a real type+priority, an
  `epic` promotion, a new grouped epic, slotting under an existing epic, or
  closure, then applies the plan via `bd update` / `bd create` / `bd close` /
  `bd dep add`.
- Beads (`bd`) issue tracker integration — `.beads/` directory with config,
  hooks, and seed issues, plus `.claude/hooks/install-bd.sh`,
  `install-dolt.sh`, and `bootstrap-bd.sh` invoked from the `SessionStart` hook
  so remote/cloud Claude Code sessions can run beads commands without manual
  setup.

### Changed

- Skill layout: capabilities now live as folders under
  `claude-code/skills/<name>/SKILL.md` (frontmatter + body) instead of single
  `claude-code/commands/<name>.md` files. `commit` and `rebase` were ported to
  the new format.
- `AGENTS.md` is now a symlink to `CLAUDE.md` so agent instructions don't drift
  between the two files.
- Documented the full release process (CHANGELOG update → `make bump` → commit
  → push → `make release`) in `CLAUDE.md`.

### Removed

- `kix:create-request`, `kix:create-pitch`, and their `kix:capture`,
  `kix:request`, `kix:pitch` aliases — Request and Pitch capture is now handled
  directly by beads (`bd create`, `bd ready`, etc.).
- `kix:implement` skill — its `.kix/requests/`-driven flow no longer matches
  the beads-based workflow; a beads-aware replacement will land separately.
- `.kix/` directory and all references to it from active docs (`CLAUDE.md`,
  `docs/kix-agents.md`). The `docs/roadmap.md` file was removed entirely — the
  roadmap now lives in beads (`bd ready` / `bd list`).

## [0.2.0] — 2026-05-06

### Added

- `kix:implement` skill (`claude-code/commands/implement.md`) — automates the
  full implementation workflow for a plain Request: creates a scoped
  `kix/<id>-<slug>` branch, implements the request across logical commits,
  updates the changelog if present, closes the Request by moving it to
  `closed/`, and opens a PR linked back to the Request file.
- `kix:rebase` skill (`claude-code/commands/rebase.md`) — ported from kata;
  rebases the current branch onto its base, resolving conflicts.
- `kix:create-request` skill (`claude-code/commands/create-request.md`) —
  canonical name for capturing a new Request, consistent with the
  `kix:create-pitch` naming pattern.
- `kix:capture` alias (`claude-code/commands/capture.md`) — short verb-form
  alias for `kix:create-request` ("capture a request").
- `kix:request` alias (`claude-code/commands/request.md`) — short verb-form
  alias for `kix:create-request` ("request something").
- `kix:pitch` alias (`claude-code/commands/pitch.md`) — short verb-form alias
  for `kix:create-pitch` ("pitch an idea").
- Prettier check GitHub workflow (`.github/workflows/check.yml`) and
  session-start hook setup (`make setup`) so format checks run in CI and hooks
  install on session start.

## [0.1.0] — 2026-05-05

### Added

- `kix:request` skill (`claude-code/commands/request.md`) — captures a new Kix
  Request friction-free into `.kix/requests/inbox/`.
- `kix:commit` skill (`claude-code/commands/commit.md`) — generates and creates
  a commit from staged or all changes, with auto-fix mode for pre-commit hook
  failures and resume support across sessions.
- `kix:create-pitch` skill (`claude-code/commands/create-pitch.md`) — promotes
  one or more Requests (or a standalone idea) into a Kix Pitch and moves source
  Requests to `linked/`.
- Pitch template at `claude-code/templates/pitch.md`.
- Claude Code marketplace declaration (`.claude-plugin/marketplace.json`) so
  the plugin can be installed with
  `/plugin marketplace add 0k-software/kix-agents`.
- `docs/kix-agents.md` — full reference for the Kix Agents layer: skills,
  invocation, orchestration, sessions, repo layout, and versioning roadmap.
- `docs/roadmap.md` — project roadmap.
