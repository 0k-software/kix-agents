# Kix Agents

**Purpose:** Open-source library of agents, skills, and prompts.

Kix Agents is a separate, public repository
([`kix-agents`](https://github.com/0k-software/kix-agents)) that ships the
canonical agents, skills, and prompts authored for the Kix workflow. It serves
two roles:

- the **source of defaults** that Kix Run invokes, and that Kix Flow wires into
  phase transitions
- a **direct interface to Kix from a coding agent prompt** — slash commands and
  prompt skills that capture and move work without going through the App,
  delegating issue tracking to beads

The second role is what makes Kix usable on day one, before any Kix App or
`kix_elixir` exists: a plain Claude Code (or Codex) setup with Kix Agents
installed can already capture and progress work, with
[beads](https://github.com/steveyegge/beads) tracking issues alongside the
code.

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

Today, Kix Agents skills lean on deterministic tooling where it exists (beads
for issue tracking, git for branches and PRs) and otherwise let the LLM do the
work directly from the skill's prompt. The LLM-driven slice is **stochastic**:
it works, but it can drift or skip a hygiene rule when the model has a bad day.

The long-term direction is that as Kix App matures it provides additional
**deterministic tooling** — typed CLI commands and library calls that own phase
transitions, hygiene checks, and the rest of the workflow surface that isn't
already covered by beads. Skills then shrink further into thin wrappers that
**invoke those App commands**. The stochastic surface stays at the "what did
the human mean?" boundary; the structural moves become deterministic.

Implication: standalone Kix Agents (no App installed) is best understood as the
**day-one entry point**, not a permanent steady state. Once the App is
available, the same skills lean on it. A workspace running an old Kix Agents
build against a new App still works; running a new Kix Agents build that
expects the App without it installed will become a degraded path over time.

## What it ships

- **Agents configuration** — definitions for each coding agent harness Kix
  supports (Claude Code, Codex, …) including the manifest each harness expects
- **Skills** — slash commands, prompts, and hooks that drive Kix from a coding
  agent: capture work into beads, claim and progress an issue, commit, rebase,
  address PR review. These are what make MVP 1 useful before the App exists.
  They start by doing the work themselves and shrink to App delegations as Kix
  App matures (see
  [Skills are stochastic; Kix App is deterministic](#skills-are-stochastic-kix-app-is-deterministic)).
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

This works fully today because Kix Agents skills implement the moves
themselves. As the App matures and skills delegate the deterministic work to
it, "no App installed" becomes a progressively more limited path — see
[Skills are stochastic; Kix App is deterministic](#skills-are-stochastic-kix-app-is-deterministic).

## How Kix invokes them

The default workflow that comes with Kix invokes these skills as the agent
layer for each phase. Projects can override the wiring per Pitch or Task to
call a different skill or a forked variant.

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
codex/                            ← Codex layout (analogous, when added)
docs/                             ← Run-specific implementation docs
```

Each harness directory is hand-authored against that harness's native plugin
layout (Claude Code's `SKILL.md`, Codex's prompt format, …). Skills aren't
generated from a shared source today.
