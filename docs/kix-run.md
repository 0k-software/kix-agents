# Kix Run

**Purpose:** Execute work via coding agents.

Where [Kix Flow](kix-flow.md) owns _process state_ and
[Kix Checkpoint](kix-checkpoint.md) owns _human decisions_, Kix Run owns _agent
execution_. It is the part of Kix App that makes coding agents (Claude Code,
Codex, etc.) actually do the work.

Kix Run is **BYO agent**: it does not ship its own coding agent or LLM. It
wires up the agents you already use — Claude Code, Codex, or any CLI-driven
agent — by feeding them Kix's skills, invoking them at the right phase, and
capturing their sessions. Kix has opinions about the _workflow_, not about
which agent runs inside it.

Kix Run covers four concerns:

- **Skills** — what agents can do (per-agent assets: slash commands, prompts,
  hooks)
- **Invocation** — how agents are kicked off (per-phase wiring is declared in
  Kix Flow's `flow.yaml`; Kix Run executes it)
- **Orchestration** — coordinating multiple agents, parallel steps, and
  recommendations
- **Sessions** — capturing what each run produced and how

## Skills

Skills are the assets that let coding agents participate in the Kix workflow:
slash commands, prompts, hooks, and the small bits of glue that turn a generic
agent into a Kix-aware one.

Skills are **shipped as templates inside Kix App** and **copied into each
project** when Kix App initializes (or syncs) the repo. They follow the same
principle as specs and plans:

> **Markdown files are canonical memory. Git is history.**

By living in the repo, skills are:

- versioned with the project
- reviewable in PRs
- reproducible from `git clone` alone (no Kix App required to run them)
- already discoverable by agents that read repo paths (`.claude/`, `.codex/`,
  `AGENTS.md`, etc.)

Trade-off accepted: bug fixes and improvements do not propagate automatically.
This is solved by `kix skills.sync` (see "Sync" below).

## Agent-agnostic source, per-agent build output

A "draft spec.md" skill is the same _idea_ regardless of which agent runs it.
Splitting skills under `claude-code/` vs `codex/` would force the same intent
to be authored, fixed, and reviewed N times — and a project that switches
agents would lose its skills.

Kix sidesteps that by treating skills the way a build system treats source:

- `.kix/skills/` is the **canonical, agent-agnostic source**
- each agent's native plugin layout (Claude Code, Codex, …) is **build
  output**, regenerated from source

```text
.kix/
  skills/
    refinement.md       ← canonical Kix skill (agent-agnostic)
    planning.md
    spec-review.md
    hooks/
      pre-checkpoint.md
```

`kix skills.compile` (run automatically on init and after every `skills.sync`)
renders each canonical skill into the plugin shape each agent natively reads:

```text
agents/claude-code/commands/refinement.md   ← generated from .kix/skills/refinement.md (Claude Code)
agents/codex/prompts/refinement.md          ← generated from the same source (Codex)
```

Each per-agent plugin lives under `agents/<agent>/` so the repo root stays the
project root, not a single plugin's root. Inside `agents/claude-code/` the
layout follows Claude Code's spec: `.claude-plugin/plugin.json` (the manifest)
plus top-level dirs (`commands/`, `skills/`, `hooks/`, …) at the plugin root.
Codex's layout differs but the principle is the same.

The compiled plugin files are **never hand-edited** — they are reproducible
artifacts. Switching from Claude Code to Codex (or running both) is
`kix skills.compile --agent codex`, not a manual re-authoring pass.

## Plugin-shaped output: both the Kix App repo and every workspace

Compiling into each agent's native plugin layout is deliberate: it makes the
output **directly installable by the agent's own plugin system**, with no Kix
App required at install time.

This applies in two places:

- **Kix App's own repo** ships its built-in defaults under
  `agents/claude-code/` (and siblings) and declares itself as a Claude Code
  marketplace via `.claude-plugin/marketplace.json` at the repo root. Any plain
  Claude Code setup — local or remote (Codespaces, CI runners, ephemeral
  sandboxes) — can run `/plugin marketplace add 0k-software/kix` followed by
  `/plugin install kix@kix` to get the default skills without installing Kix
  App itself.
- **Each Kix workspace** also produces an `agents/claude-code/` layout from its
  own `.kix/skills/` — defaults plus any project-local forks — and ships a
  marketplace declaration alongside. The workspace is self-installable the same
  way, so a fresh clone or remote checkout of a project picks up exactly the
  skills that project committed.

The Kix App is still the thing that authors and compiles skills. But once
compiled, the artifact is a standard Claude Code (or Codex) plugin, runnable
anywhere that agent runs.

## Skill format and harness divergence

Each canonical skill is a Markdown file with Kix front-matter declaring its
kind, inputs, and which harnesses can host it:

```yaml
---
name: refinement
kind: command # command | prompt | hook
description: Drafts spec.md from a brief
inputs:
  - case_id
agents: [claude-code, codex] # default: all known harnesses
---
```

The compiler maps `kind` to each harness's native concept (a Claude Code slash
command, a Codex prompt, etc.) and writes the front-matter that harness
expects.

Where harnesses genuinely diverge — e.g. a Claude Code hook with a JSON shape
that has no Codex analogue — the skill declares `agents: [claude-code]` and the
compiler skips harnesses that can't host it. **Common case is portable;
divergence is explicit, not silent duplication.**

## Read-only defaults, fork to customize

Default skills shipped by Kix App are **not editable in place**.

Rationale:

> If users edit defaults directly, `kix skills.sync` cannot safely upgrade them
> without losing customization or requiring a 3-way merge for every file.

Instead, customization happens by **forking**:

```text
kix skills.fork <skill-name> [--as <new-name>]
```

This:

- copies the default canonical skill into a sibling user-owned skill under
  `.kix/skills/`
- registers it as a project-local skill
- leaves the default untouched and still managed by sync

The user's fork is theirs to edit freely. The default keeps tracking upstream.
The next compile re-renders both into the agent-native dirs.

## Sync

```text
kix skills.sync
```

Sync operates on the canonical source under `.kix/skills/`, then triggers a
re-compile so the agent-native dirs match:

- default canonical skills are replaced with the latest version from Kix App
- user-forked skills under `.kix/skills/` are never touched
- each agent's plugin layout (Claude Code, Codex, …) is **regenerated** from
  the new source — any manual edits there are overwritten (they shouldn't have
  existed)
- no merge prompts, no drift, no surprises

## Phase automations

Each phase can be wired to a coding agent that runs automatically when a Pitch
or Task enters the phase.

Example (Task flow):

```text
task enters refining     → refinement agent drafts spec.md
task enters planning     → planning agent drafts plan.md
task enters implementing → implementation agent opens edits on the task branch
```

Defaults live in `flow.yaml`. Per-Pitch and per-Task overrides are allowed.

The agent produces work; the human still owns the checkpoint. Automation
removes the "who pushes the button" step, not the decision step.

## Phase chaining, auto-review, and auto-fix

By default Kix Flow stops at every phase and waits for a human to move it.
Three **independent, opt-in** automation layers reduce that friction:

**Phase chaining** — when no checkpoint is configured between phase A and phase
B, chaining lets the Pitch or Task advance from A to B automatically as soon as
A's work completes, instead of sitting idle waiting for a button click.
Chaining alone **never crosses a checkpoint**: if a checkpoint sits between two
phases, the work halts there.

**Auto-review** — at checkpoints the user has marked auto-reviewable, an agent
performs the review and marks the checkpoint pass/fail without a human
reviewer.

**Auto-fix** — at checkpoints the user has marked auto-fixable, an agent
addresses the issues an auto-review surfaced and re-runs the review.

**Crossing a checkpoint requires _both_ auto-review and auto-fix to be on for
that checkpoint.** Without auto-fix there is no automated path forward the
moment a review fails, so the chain has to halt. Requiring both toggles makes
"let this run unattended" a deliberate, paired decision rather than something
that quietly happens with a single switch.

How the toggles combine:

- chaining alone → halts at every checkpoint
- chaining + auto-review (no auto-fix) → still halts at every checkpoint;
  crossing requires both
- chaining + auto-review + auto-fix → review either passes, or auto-fix
  resolves the issues and re-reviews; the work continues either way
- auto-review or auto-fix without chaining → checkpoints get decided (and
  optionally fixed) autonomously, but the human still clicks "advance" between
  phases
- auto-fix without auto-review → agent applies fixes to issues a _human_
  reviewer flagged; useful, but does not enable chaining through

All three default per-project in `flow.yaml` and can be overridden per Pitch,
per Task, or per checkpoint.

**Hard structural rule:** the **final checkpoint before `done`** is never
auto-reviewable or auto-fixable, regardless of project configuration. Skipping
it would mean Kix declared something done that no human ever saw. The three
automations apply to intermediate checkpoints only.

Rationale:

> Kix does not know the specifics of every project's process — phases and
> checkpoints can be added, renamed, or reordered in `flow.yaml`. The one
> structural truth is that the phase right before `done` is the human's "is
> this good?" gate. That gate is always hard. Every other checkpoint is the
> user's call to automate or not.

## Orchestration

Beyond running a single agent per phase, Kix Run can use AI to orchestrate the
work itself — both **within a Pitch or Task** and **across them**:

_Within a Pitch or Task:_

- identify which steps within a phase can run in parallel
- surface blockers (missing inputs, failing checks, dependencies on other Tasks
  or Pitches)
- suggest what the human should look at next on this work

_Across Pitches and Tasks:_

- suggest which Tasks can be worked in parallel without stepping on each other
  (different files, different boundaries, no shared state)
- flag Pitches and Tasks that are sitting at a checkpoint and ready to be moved
  forward
- propose which Pitch or Task to pick up given current context (what the human
  was just looking at, what's nearly done, what's blocking others)
- **prioritize by impact** — pull signals like which items are tied to
  customer-reported issues, which affect the most users, which unblock other
  work, and which carry deadlines, and surface that ranking to the human

Orchestration is advisory. It schedules, recommends, and ranks. It does not
approve — checkpoints remain the human decision layer.

## Sessions

Every agent invocation is captured as a session under the Pitch or Task folder:

```text
sessions/
  refinement.summary.md
  refinement.raw.md
  planning.summary.md
  planning.raw.md
  implementation.summary.md
  implementation.raw.md
```

- `*.raw.md` — full transcript of the agent run
- `*.summary.md` — condensed, reviewable summary fed to checkpoints

Sessions are part of the canonical Markdown record. Like specs and plans, they
are versioned in Git and survive without the cache.

## Roadmap alignment

Kix Run customization mirrors the [Customization Roadmap](roadmap.md):

- **V1** — default skills only, copied on init, sync overwrites; no fork
- **V2** — fork command available; project-local skills supported; per-phase
  agent overrides
- **V3+** — UI for managing forks, sharing forked skills across projects,
  custom orchestration rules
