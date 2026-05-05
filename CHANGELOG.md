# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/).

## [Unreleased]

### Added

- `kix:implement` skill (`claude-code/commands/implement.md`) — automates the
  full implementation workflow for a plain Request: creates a scoped
  `kix/<id>-<slug>` branch, implements the request across logical commits,
  updates the changelog if present, closes the Request by moving it to
  `closed/`, and opens a PR linked back to the Request file.
- `kix:create-request` skill (`claude-code/commands/create-request.md`) —
  canonical name for capturing a new Request, consistent with the
  `kix:create-pitch` naming pattern.
- `kix:capture` alias (`claude-code/commands/capture.md`) — short verb-form
  alias for `kix:create-request` ("capture a request").
- `kix:request` alias (`claude-code/commands/request.md`) — short verb-form
  alias for `kix:create-request` ("request something").
- `kix:pitch` alias (`claude-code/commands/pitch.md`) — short verb-form alias
  for `kix:create-pitch` ("pitch an idea").

## [0.1.0] — 2026-05-05

### Added

- `kix:request` skill (`claude-code/commands/request.md`) — captures a new
  Kix Request friction-free into `.kix/requests/inbox/`.
- `kix:commit` skill (`claude-code/commands/commit.md`) — generates and
  creates a commit from staged or all changes, with auto-fix mode for
  pre-commit hook failures and resume support across sessions.
- `kix:create-pitch` skill (`claude-code/commands/create-pitch.md`) — promotes
  one or more Requests (or a standalone idea) into a Kix Pitch and moves source
  Requests to `linked/`.
- Pitch template at `claude-code/templates/pitch.md`.
- Claude Code marketplace declaration (`.claude-plugin/marketplace.json`) so
  the plugin can be installed with `/plugin marketplace add 0k-software/kix-agents`.
- `docs/kix-agents.md` — full reference for the Kix Agents layer: skills,
  invocation, orchestration, sessions, repo layout, and versioning roadmap.
- `docs/roadmap.md` — project roadmap.
