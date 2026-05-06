# Changelog

All notable changes to this project will be documented in this file.

The format is based on
[Keep a Changelog](https://keepachangelog.com/en/1.1.0/).

## [Unreleased]

### Added

- `kix:close` skill (`claude-code/commands/close.md`) — polymorphic
  `/close <id> [reason]` that infers the entity type from the id and applies
  its terminal state: moves Requests to `closed/`, sets Pitches to
  `phase: shipped`, sets Tasks to `phase: done`. Optional reason text is
  captured into a `## Resolution` section.
- `kix:fix-pr` skill (`claude-code/commands/fix-pr.md`) — ported from kata;
  addresses unresolved review comments on a PR, verifying suggestions before
  implementing and routing commits through `kix:commit`.
- `kix:fix`, `kix:address`, and `kix:address-pr` aliases
  (`claude-code/commands/fix.md`, `address.md`, `address-pr.md`) — short
  verb-form aliases for `kix:fix-pr`.

### Changed

- `kix:create-request` (`claude-code/commands/create-request.md`) — when the
  derived body is too thin to infer the area, outcome, or motivation, the skill
  now prints a soft warning alongside the confirmation. Request creation stays
  friction-free; the nudge just helps future triagers.
- Drop the `title:` field from Request and Pitch front-matter; the H1 at the
  top of the body is now the canonical title. Updated the pitch template
  (`claude-code/templates/pitch.md`), the `kix:create-request`,
  `kix:create-pitch`, and `kix:implement` skills, and migrated all existing
  Requests and Pitches to the new shape.

### Removed

- Redundant `type: request` field from Request front-matter — Requests are
  identified by their location under `.kix/requests/`, so the field carried no
  signal. Dropped from the `kix:create-request` skill template and stripped
  from existing Request files.

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
