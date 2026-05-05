# Roadmap

This document covers two roadmaps that shape how Kix evolves:

- **MVP Roadmap** — the order in which Kix's modules are built.
- **Customization Roadmap** — the gradual opening of Kix's omakase defaults
  toward project-level customization.

## MVP Roadmap

The order is shaped by the fact that **this repo dogfoods Kix on itself**. Each
module is built only as far as needed to unblock the next, so the project
starts using its own SDLC tooling as early as possible. Concretely that means
an interleaved sequence: a basic skills plugin so AI-assisted capture works on
day one, a minimal `kix_elixir` to scaffold the repo, just enough Flow and
Checkpoint to record and gate work, _then_ circle back to complete each module
properly. Performance (Cache) and collaboration (Teams) come last.

### MVP 1 — Basic skills plugin

The minimum needed to capture work via a coding agent before any Elixir or
Phoenix code exists. Ships as a Claude Code plugin (see [Kix Run](kix-run.md))
so a plain Claude Code setup can `/plugin marketplace add 0k-software/kix` and
`/plugin install kix@kix` to start using Kix on this repo.

- the repo declares itself as a Claude Code marketplace via
  `.claude-plugin/marketplace.json` at the root; the actual plugin lives at
  `agents/claude-code/` (manifest + commands + …), installable in any Claude
  Code setup (local or remote)
- a small set of canonical skills under `.kix/skills/` covering the core SDLC
  moves:
  - create a Request in `.kix/requests/`
  - promote a Request to a Pitch
  - create a Task (standalone or under a Pitch)
  - move a Pitch or Task to the next phase
- skills operate on the file layout that MVP 3 (Kix Flow basic) will formalize;
  no compiler, no fork story yet — defaults only
- no `kix_elixir`, no Phoenix UI, no checkpoint enforcement — those land in
  later MVPs and replace the bare-skill flow with a gated one

> At the end of MVP 1, the repo can record Requests, Pitches, and Tasks as
> Markdown via Claude Code, with no Kix App installed. Everything after this
> hardens that loop with deterministic tooling and human gates.

See [Kix Run](kix-run.md).

### MVP 2 — `kix_elixir` (bootstrap)

The minimum needed to start this repo and keep it healthy from day one.

- Elixir library skeleton
- project generator (enough to scaffold the Kix App Phoenix project)
- pre-commit hook support
- a small set of Mix tasks for the project lifecycle
- the deterministic checks strictly required to avoid regressions in this repo
  (formatter, basic linter); fuller check surface lives in MVP 5

See [Kix Libs](kix-libs.md).

### MVP 3 — Kix Flow (basic)

The minimum needed to start tracking work on this repo as Pitches and Tasks.
File-system first, no UI yet.

- `.kix/{requests,pitches,tasks}/` directory layout
- phase recorded in front-matter / folder convention
- Mix/CLI tasks to create items and move them across phases
- no Triage view, no Roadmap/Project views, no Phoenix UI

See [Kix Flow](kix-flow.md).

### MVP 4 — Kix Checkpoint (basic)

The minimum needed to gate phase transitions on a human decision.

- checkpoint Markdown files generated at each phase transition
  (`checkpoints/NNN-<phase>.md`)
- Mix/CLI command to approve / reject and capture rationale
- no guided UI yet — just files plus a prompt

> At the end of MVP 4, the repo can fully dogfood itself: every change lands as
> a Task, gated by checkpoints, recorded in Markdown, versioned in Git.
> Everything after this point is layered on top of a working system.

### MVP 5 — `kix_elixir` (complete)

Round out the first Kix Lib now that the bootstrap subset has earned its keep.

- AI-friendly coverage output
- architectural / boundary checks
- the full deterministic-check surface (custom rules beyond MVP 2)
- polished project generator
- complete Mix/CLI task surface

See [Kix Libs](kix-libs.md).

### MVP 6 — Kix Flow & Checkpoint (complete)

Promote Flow and Checkpoint from CLI-and-files to a full local Phoenix-based
experience, and bring [Kix Run](kix-run.md) online so agents can be invoked at
the right phase.

- Phoenix-based local UI (Kix App)
- Triage, Roadmap, and Project views
- full Request inbox and triage workflow
- guided checkpoint UI (replacing the bare prompt from MVP 4)
- hygiene rules and consistency guarantees enforced in the UI
- slug renaming and branch ↔ Task binding
- Kix Run: full skills compilation pipeline (canonical source → per-agent
  plugin output), fork story, agent invocation, session capture — promoting the
  MVP 1 skill set from "hand-authored Claude Code plugin" to "compiled output
  from `.kix/skills/`"
- opt-in chaining / auto-review / auto-fix automations

Once-folded MVP. By this point both modules are mature enough that splitting
them again into separate MVPs would be artificial — the remaining work crosses
both (e.g. auto-review needs checkpoint UX + Run + Flow phase transitions in
lockstep).

See [Kix Flow](kix-flow.md), [Kix Checkpoint](kix-checkpoint.md), and
[Kix Run](kix-run.md).

### MVP 7 — Cache layer

- faster board/list rendering
- disposable cache (SQLite-backed in v1; backend is an implementation detail)
- files-only fallback
- stale/indexing states

See [Cache layer](cache.md).

### MVP 8 — Kix Teams

- presence
- awareness
- warning signals
- activity indications
- optional team collaboration

See [Kix Teams](kix-teams.md).

## Customization Roadmap

### V1 — Omakase only

- fixed default Kix flow
- no user-facing customization
- process exists internally as data/config

### V2 — Toggle phases/checkpoints

Allow users to enable/disable:

- spec/refining
- planning
- staging (a long-soak pre-release phase teams with a dedicated staging
  environment can opt into; not in V1 omakase)
- checkpoints after each phase

### V3 — Prompt customization

Allow project-level prompts, one per phase per flow level:

```text
.kix/config/prompts/task/backlog.md
.kix/config/prompts/task/refining.md
.kix/config/prompts/task/planning.md
.kix/config/prompts/pitch/shaping.md
.kix/config/prompts/pitch/betting.md
.kix/config/prompts/triage.md
.kix/config/prompts/checkpoint.md
```

### V4 — Custom phases

Allow users to define custom phases and artifacts.

### V5 — Flow builder

Full visual editor for:

- phases
- transitions
- artifacts
- skills
- prompts
- checkpoints
