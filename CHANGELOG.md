# Changelog

All notable changes to this project will be documented in this file.

The format is based on
[Keep a Changelog](https://keepachangelog.com/en/1.1.0/).

## [Unreleased]

### Added

- `kix:commit-message` skill (`claude-code/skills/commit-message/SKILL.md`) —
  invoked as `/kix:commit-message [reason for the change]`; generates a commit
  message for the current uncommitted changes and prints it, with nothing else
  in the response. It is read-only: it never stages, commits, or otherwise
  touches the repo. If anything is staged it describes the staged diff only;
  otherwise it describes every uncommitted change, untracked files included.
  Style resolution is unchanged from `kix:commit` — a `Commit message` section
  in `AGENTS.md`/`CLAUDE.md` wins, else the repo's own history, else imperative
  subject ≤ 72 chars plus a 72-wrapped body — and no `Co-Authored-By` footer is
  ever added. The strict output contract makes it usable headlessly
  (`claude -p "/kix:commit-message"`) so shell scripts, git hooks, and editors
  such as Obsidian Git can consume the raw message from stdout.

- `commit-message.sh` wrapper bundled with the skill
  (`${CLAUDE_PLUGIN_ROOT}/skills/commit-message/commit-message.sh`) — runs
  `claude -p` with a read-only tool allowlist, trims stray fencing and blank
  padding, and exits `2` when there is nothing to commit so callers can skip
  cleanly. Takes `-C <repo-dir>` and free-text context, and honours
  `KIX_CLAUDE_BIN` / `KIX_COMMIT_MESSAGE_MODEL`.

### Changed

- `kix:commit` no longer spells out its own message-writing rules — Step 3 now
  delegates to `kix:commit-message`, so message style lives in exactly one
  place. Behaviour is unchanged: the message is still generated from the staged
  diff and displayed for review before committing.

## [0.2.3] — 2026-05-18

### Added

- Codex SessionStart bootstrap parity — repo-local `.codex/config.toml` now
  wires startup/resume/clear into the same `.kix/hooks/session-start.sh` script
  that Claude Code uses, avoiding duplicated bootstrap logic while still
  installing `dolt` + `bd`, wiring git hooks, bootstrapping beads, and running
  `bd prime`. `kix:setup` now installs the Codex config block into target repos
  and reminds users to trust repo-local hooks via `/hooks`.

- `kix:save-session` skill (`claude-code/skills/save-session/SKILL.md`) —
  invoked as `/kix:save-session [--no-commit]`; archives the current session
  into a per-session folder `docs/sessions/<stem>/` in the surrounding repo
  (target = `git remote get-url origin` of the current checkout — no repo
  argument). When run from Claude Code on a feature branch (the branch that
  holds this session's work) the archive is committed straight onto that branch
  so it rides along with that branch's PR; on the default branch (no work
  branch to attach to) it gets its own `claude/save-session-<stem>` branch +
  PR. The folder holds a `log.md` — an append-only running history (first save
  creates it; each re-save appends a `## <timestamp> — update` section rather
  than rewriting it, built from context, via `caveman` if available) — plus the
  verbatim conversation: the Claude Code transcript `.jsonl`, gzipped and
  committed as `transcript.jsonl.gz` (~4–5× smaller, keeps the repo from
  ballooning — no Git LFS needed) — in a hosted/cloud sandbox
  (`CLAUDE_CODE_REMOTE`) where each turn is a fresh `claude --resume`, the
  largest file in the project dir (the complete cumulative transcript,
  append-only across compactions); or, when there's no transcript file (a chat
  session), a verbatim `transcript.md` render from the conversation in context.
  Archives are keyed by the session id (`CLAUDE_CODE_REMOTE_SESSION_ID` in a
  hosted sandbox — the only id stable across turns), so re-saving the same
  session updates that folder in place instead of duplicating. A `--no-commit`
  flag stages the archive into the current checkout without committing (used by
  `kix:commit`). Repo writes go through the available GitHub tools, falling
  back to GitHub REST API + `GITHUB_TOKEN`/`GH_TOKEN` when MCP can't reach the
  repo; if neither is available (e.g. a Claude chat session with no GitHub
  connector), the skill switches to **handoff mode** — emits `transcript.md` +
  `log.md` + a Claude-Code paste prompt in chat instead of pushing. Tracked in
  `kxa-bpt`.
- Caveman plugin wired into the repo dev setup — `.claude/settings.json` now
  registers the `caveman` marketplace (`JuliusBrussee/caveman`) via
  `extraKnownMarketplaces` and enables `caveman@caveman`, so cloud and local
  Claude Code sessions pick up caveman's `full` mode (agent-output token
  compression) automatically. Code blocks, commits, and PR descriptions are
  still written normally.
- `kix:setup` skill (`claude-code/skills/setup/SKILL.md`) — installs the
  baseline Kix repo tooling into the current repository (Prettier formatting
  gate + `make` targets + a `.github/workflows/check.yml` CI workflow, a merged
  beads-sync + Prettier `pre-commit` hook, `.claude` SessionStart/PreCompact
  hooks that install `dolt` + `bd` and bootstrap beads, an `AGENTS.md` →
  `CLAUDE.md` symlink so the two agent-instructions files don't drift, plus
  optional `bd init` and a `CLAUDE.md` Beads section), then opens a PR. Ships a
  bundled `setup.sh` that does the idempotent file changes and an `assets/`
  directory holding the canonical hook scripts, Makefile, CI workflow, and
  Prettier config it deploys.
- `docs/kix/kxa-8g7/spec.md` and `docs/kix/kxa-8g7/plan.md` — spec (target
  outcome) + step-by-step local execution plan for moving beads issue state off
  branch-committed `.beads/issues.jsonl` onto a shared Dolt remote (tracked in
  beads as `kxa-8g7`).

### Changed

- Pre-commit hook consolidated — the beads DB→JSONL sync hook
  (`.beads/hooks/pre-commit`) and the Prettier gate (`.git-hooks/pre-commit`)
  are now one file at `.beads/hooks/pre-commit` (beads' managed section
  followed by the Prettier gate), and `make setup` points `core.hooksPath` at
  `.beads/hooks/` instead of copying into `.git/hooks/`. The `.git-hooks/`
  directory is removed. Fixes the bug where the beads pre-commit hook never ran
  because the Prettier hook owned `.git/hooks/pre-commit`.
- `kix:commit` now bundles the current Claude Code session's archive into every
  commit it makes — it invokes `/kix:save-session --no-commit` (a new
  stage-only mode that writes
  `docs/sessions/<stem>/{transcript.jsonl.gz,log.md}` and `git add`s them
  without committing), then commits the lot together with the rest of the
  staged changes (the session is the work behind the commit). No-op for plain
  chat sessions (no transcript). `docs/sessions/**/transcript.jsonl.gz` is
  marked `binary` in `.gitattributes` so diffs stay clean.

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
  hooks, and seed issues, plus `.kix/hooks/install-bd.sh`, `install-dolt.sh`,
  and `bootstrap-bd.sh` invoked from the `SessionStart` hook so remote/cloud
  Claude Code sessions can run beads commands without manual setup.

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
