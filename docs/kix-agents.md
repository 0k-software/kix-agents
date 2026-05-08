# Kix Agents

**Purpose:** Open-source library of agents, skills, and prompts.

Kix Agents is a separate, public repository
([`kix-agents`](https://github.com/0k-software/kix-agents)) that ships the
canonical agents, skills, and prompts authored for the Kix workflow. It serves
two roles:

- the **source of defaults** that Kix Run compiles and invokes, and that Kix
  Flow wires into phase transitions
- a **direct interface to Kix from a coding agent prompt** — slash commands and
  prompt skills that capture and move work without going through the App, e.g.
  creating Requests, promoting them to Pitches, creating Tasks, and advancing
  Pitches or Tasks across phases

The second role is what makes Kix usable on day one, before any Kix App or
`kix_elixir` exists: a plain Claude Code (or Codex) setup with Kix Agents
installed can already record `.kix/requests/`, `.kix/pitches/`, and
`.kix/tasks/` against the same file layout the App later picks up.

It is deliberately **not** part of Kix App:

- the App is a Phoenix-based local UI; Kix Agents is plain repo content
- decoupling them lets the open-source skill catalog evolve, version, and ship
  on its own cadence
- on day one (MVP 1) Kix Agents is the only practical interface — the App
  doesn't exist yet, so skills do all the work themselves

> **Defaults are open-sourced. Customization is local.**

## BYO agent

Kix Agents is **BYO agent**: it does not ship its own coding agent or LLM. It
wires up the agents you already use — Claude Code, Codex, or any CLI-driven
agent — by feeding them Kix's skills, invoking them at the right phase, and
capturing their sessions. Kix has opinions about the _workflow_, not about
which agent runs inside it.

The agent layer covers four concerns:

- **Skills** — what agents can do (per-agent assets: slash commands, prompts,
  hooks)
- **Invocation** — how agents are kicked off (per-phase wiring is declared in
  Kix Flow's `flow.yaml`; Kix Run executes it)
- **Orchestration** — coordinating multiple agents, parallel steps, and
  recommendations
- **Sessions** — capturing what each run produced and how

## Skills are stochastic; Kix App is deterministic

Today, the [Kix-invocation skills](#what-it-ships) below do the work
themselves: a slash command for "create a Pitch" reads templates, allocates an
ID, writes the folder, and updates state — all driven by an LLM following the
skill's prompt. That is **stochastic**: it works, but it can drift, miscount
IDs, or skip a hygiene rule when the model has a bad day.

The long-term direction is that as Kix App matures it provides **deterministic
tooling** — typed CLI commands and library calls that own ID allocation, file
layout, hygiene checks, and state transitions. The same skills then shrink to
thin wrappers that **invoke those App commands** instead of reproducing the
logic themselves. The stochastic surface stays at the "what did the human
mean?" boundary; the structural moves become deterministic.

Implication: standalone Kix Agents (no App installed) is best understood as the
**day-one entry point**, not a permanent steady state. Once the App is
available, the same skills lean on it. A workspace running an old Kix Agents
build against a new App still works; running a new Kix Agents build that
expects the App without it installed will become a degraded path over time.

## What it ships

- **Agents configuration** — definitions for each coding agent harness Kix
  supports (Claude Code, Codex, …) including the manifest each harness expects
- **Skills** — the canonical, agent-agnostic source for slash commands,
  prompts, and hooks (the same source Kix Run compiles into per-agent native
  layouts — see
  [Agent-agnostic source, per-agent build output](#agent-agnostic-source-per-agent-build-output)),
  split across two purposes:
  - **Kix-invocation skills** — directly drive Kix from a prompt: create a
    Request, promote it to a Pitch, create a Task under a Pitch, move a Pitch
    or Task to the next phase. These are what make MVP 1 useful before the App
    exists. They start by doing the work themselves and shrink to App
    delegations as Kix App matures (see
    [Skills are stochastic; Kix App is deterministic](#skills-are-stochastic-kix-app-is-deterministic)).
  - **Phase-execution skills** — the per-phase work agents run inside the flow:
    refinement, planning, implementation, review, …
- **Prompts** — the per-phase prompts referenced by `flow.yaml` defaults

By living in the repo, skills are versioned with the project, reviewable in
PRs, reproducible from `git clone` alone (no Kix App required to run them), and
already discoverable by agents that read repo paths (`.claude/`, `.codex/`,
`AGENTS.md`, etc.).

## Install without Kix App

The repo declares itself as a Claude Code marketplace via
`.claude-plugin/marketplace.json`. From any plain Claude Code setup:

```text
/plugin marketplace add 0k-software/kix-agents
/plugin install kix@kix-agents
```

Codex and other harnesses each have their own equivalent, served from the same
repo. A user can adopt the Kix workflow on a project without ever installing
Kix App — the App layers Flow, Checkpoint, and a UI on top of the same skills.

The same plugin-shaped output also gets produced **per workspace**: each Kix
workspace compiles its own `.kix/skills/` (defaults plus project-local forks)
into a Claude Code (or Codex) layout and ships a marketplace declaration
alongside, so a fresh clone or remote checkout of a project picks up exactly
the skills that project committed — no Kix App needed at install time.

This works fully today because Kix Agents skills implement the moves
themselves. As the App matures and skills delegate the deterministic work to
it, "no App installed" becomes a progressively more limited path — see
[Skills are stochastic; Kix App is deterministic](#skills-are-stochastic-kix-app-is-deterministic).

## How Run and Flow consume it

- **Kix Run** treats Kix Agents as the upstream for default skills. On init,
  Kix App pulls the canonical sources from Kix Agents into the workspace's
  `.kix/skills/`, then compiles them into each agent's native layout.
  `kix skills.sync` re-pulls upstream defaults; user-forked skills under
  `.kix/skills/` are never touched. (See [Sync](#sync).)
- **Kix Flow** references agents from Kix Agents in its default `flow.yaml`
  per-phase wirings. Each Pitch or Task phase that runs an agent picks one out
  of this catalog by name. Projects can override the wiring per Pitch or Task,
  or fork a skill and point the wiring at the fork.

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
claude-code/skills/refinement/SKILL.md   ← generated for Claude Code
codex/prompts/refinement.md              ← generated from the same source for Codex
```

The compiled plugin files are **never hand-edited** — they are reproducible
artifacts. Switching from Claude Code to Codex (or running both) is
`kix skills.compile --agent codex`, not a manual re-authoring pass.

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

## Customization: fork, don't edit

Default skills shipped from Kix Agents are **not editable in place** inside a
workspace.

Rationale:

> If users edit defaults directly, `kix skills.sync` cannot safely upgrade them
> without losing customization or requiring a 3-way merge for every file.

Users customize by **forking**:

```text
kix skills.fork <skill-name> [--as <new-name>]
```

This copies the default canonical skill into a sibling user-owned skill under
`.kix/skills/`, registers it as a project-local skill, and leaves the default
untouched and still managed by sync. The default keeps tracking upstream Kix
Agents, so future syncs upgrade it without losing the user's customization. The
next compile re-renders both into the agent-native dirs.

## Sync

```text
kix skills.sync
```

Sync operates on the canonical source under `.kix/skills/`, then triggers a
re-compile so the agent-native dirs match:

- default canonical skills are replaced with the latest version from Kix Agents
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

## Repo layout

```text
.claude-plugin/marketplace.json   ← marketplace declaration
claude-code/                      ← Claude Code plugin (manifest + skills + …)
  .claude-plugin/plugin.json
  skills/
  templates/
codex/                            ← Codex layout (analogous)
docs/                             ← Run-specific implementation docs
```

The same skill is authored once at canonical source and compiled into each
harness's native layout — see
[Agent-agnostic source, per-agent build output](#agent-agnostic-source-per-agent-build-output).

## Versioning and roadmap

Kix Agents customization mirrors the Customization Roadmap:

- **V1** — default skills only, copied on init, sync overwrites; no fork
- **V2** — fork command available; project-local skills supported; per-phase
  agent overrides
- **V3+** — UI for managing forks, sharing forked skills across projects,
  custom orchestration rules

See [Roadmap](roadmap.md) for the full picture.
