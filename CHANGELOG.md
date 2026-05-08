# Changelog

All notable changes to this project will be documented in this file.

The format is based on
[Keep a Changelog](https://keepachangelog.com/en/1.1.0/).

## [Unreleased]

### Added

- `.claude/hooks/install-bd.sh` — invoked from the `SessionStart` hook to
  install the `bd` (beads) CLI into `~/.local/bin` on bootstrap when it is not
  already on `PATH`. Lets remote/cloud Claude Code sessions run beads commands
  without manual setup. Idempotent (no-op locally), pinned to a known-good
  version (`KIX_BD_VERSION`, default `1.0.3`), silent on success, and non-fatal
  so a failed install does not abort session start. Closes kxa-tts.2.
- `kix:triage` skill (`claude-code/skills/triage/SKILL.md`) — walks every open
  `bd todo` (untyped `task` issue) and routes each to a real type+priority, an
  `epic` promotion, a new grouped epic, slotting under an existing epic, or
  closure. The flow: gather, fill in any missing descriptions one-by-one with
  the user (since description quality drives every later decision), reason
  through every item end-to-end (priority → category → epic linkage — including
  for closures, when relevant — → dependencies), present a per-item
  before/after overview, confirm the plan (accept all / review step-by-step /
  push back / reject specific items), then apply via `bd update` / `bd create`
  / `bd close` / `bd dep add` with `--parent=<epic-id>` for epic membership,
  and verify with `bd list --all` filtered to the touched ids. Closes kxa-8xe.
- `kix:cancel` skill (`claude-code/commands/cancel.md`) — polymorphic
  `/cancel <id> [reason]` that marks work as discarded. Requests move to
  `closed/` with the cancellation reason in the body; Pitches and Tasks get a
  `cancelled_at` timestamp added to their front-matter while their `phase:` is
  preserved (so you can see where in the process the work was cancelled).
  Cancellation is orthogonal to phase progression — for work that landed, this
  is not the right tool.
- `kix:create-task` skill (`claude-code/commands/create-task.md`) — creates a
  new Kix Task under `.kix/tasks/<id>-<slug>/task.md`, mirroring
  `kix:create-pitch`'s argument grammar (Solo, Grouped framed/unframed,
  Standalone) and adding a `--pitch <id>` flag to attach the Task to a parent
  Pitch. Infers a `kind` (`feature`, `chore`, `bug`, or `enhancement`) from the
  user's framing text, parent Pitch context, or seed Requests, falling back to
  `chore`, and stamps out the matching per-kind template; echoes the inferred
  kind in the confirmation so it can be corrected.
- `kix:task` alias (`claude-code/commands/task.md`) — short verb-form alias for
  `kix:create-task`.
- Per-kind Task body templates at `claude-code/templates/task-feature.md`,
  `task-chore.md`, `task-bug.md`, and `task-enhancement.md`, ported from the
  GitHub issue templates in `0k-software/.github`. Each rendered Task body
  matches what the corresponding GitHub issue form produces when submitted; the
  YAML form's intro markdown block is replaced by the seeded `summary` so the
  user's framing slots in at the top of the Task.
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

- `kix:create-request`, `kix:create-pitch`, and `kix:create-task` skills, plus
  their aliases (`kix:capture`, `kix:request`, `kix:pitch`, `kix:task`) — the
  workflows are now handled directly by beads (`bd create`, `bd ready`, etc.).
- `kix:cancel` skill — superseded by `bd close <id> --reason="..."`.
- `kix:implement` skill — its `.kix/requests/`-driven flow no longer matches
  the beads-based workflow; a beads-aware replacement will land separately.
- `TodoWrite`-based progress tracking in `kix:rebase` and `kix:fix-pr`.
  Per-step progress is reported in the agent's text output instead.
- All `.kix/` references from active docs (`CLAUDE.md`, `docs/kix-agents.md`,
  `docs/roadmap.md`). Issue tracking goes through beads; the skills-compiler
  architecture (canonical `.kix/skills/` source compiled into per-harness
  output) and per-project prompt customization paths
  (`.kix/config/prompts/...`) were dropped — skill placement is left to each
  agent harness rather than dictated by Kix.
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
