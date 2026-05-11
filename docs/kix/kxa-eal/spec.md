# Evaluation: Cave Kit vs obra/superpowers as workflow foundation

Tracked in beads: **kxa-eal** — _Evaluate Cave Kit vs obra/superpowers as
workflow foundation_

Sources:

- https://github.com/JuliusBrussee/cavekit
- https://github.com/obra/superpowers

Context: kxa-tts tracks migrating Kix tooling onto a shared workflow plugin
(currently scoped to obra/superpowers). The user surfaced JuliusBrussee/cavekit
(a sister project to caveman — see kxa-x83) as a potential full replacement for
superpowers. This spec compares both head-to-head and recommends which to adopt
as the kix-agents workflow foundation.

## Cave Kit — feature surface

Cave Kit is a **spec-driven workflow framework**. v4.0.0 is the current
release; v3.1.0 is "frozen, fully functional" (had 16 commands and parallel
execution; v4 deliberately dropped most of that for token-efficiency and
architectural simplicity). All writes use the **caveman encoding** notation
(see kxa-x83) — symbolic section markers (§G goal, §C constraints, §I
interfaces, §V invariants, §T tasks, §B bugs) that compress prose ~75%.

| Skill              | Operations                                               |
| ------------------ | -------------------------------------------------------- |
| `/ck:spec`         | NEW / DISTILL / BACKPROP / AMEND — writes to `SPEC.md`   |
| `/ck:build`        | Load spec → plan tasks → execute → auto-rollback on fail |
| `/ck:check`        | Read-only drift detection (HOLD/VIOLATE/MISSING/EXTRA…)  |
| `backprop` helper  | Trace → analyze → propose → test → verify → log to §B    |
| `caveman` encoding | Compression ruleset applied to every spec write          |

v4 ships **no named subagents, no hooks, no orchestration binaries**. v3 had
sketch/map/make/review agents and a git-backed ledger for team coordination —
all removed in v4.

Distribution: `npx skills add JuliusBrussee/cavekit` or via the cavekit repo.
License: MIT (inferred from caveman; not explicitly stated on cavekit).
Activity: ~877 stars / 60 forks (per GitHub profile snapshot), v3.1.0 frozen
April 2026, v4 active.

## obra/superpowers — feature surface

Superpowers is a **mandatory-sequence workflow framework**. Skills enforce a
7-stage process (brainstorm → worktree → plan → execute → TDD → review →
finish), each with hard gates that forbid skipping. Skills are not slash
commands — they're invoked programmatically from inside other skill bodies via
a master dispatcher (`using-superpowers`). The only documented hook is
SessionStart, which injects the dispatcher and detects the platform (Claude
Code / Cursor / OpenCode / Codex / Gemini / Copilot CLI).

14 core skills (full list below). Persistent artifacts live in
`docs/superpowers/specs/YYYY-MM-DD-<topic>-design.md` and
`docs/superpowers/plans/YYYY-MM-DD-<feature>.md` — one file per
feature/iteration, ISO-date prefixed, append-only.

| Skill                          | Purpose                                                           |
| ------------------------------ | ----------------------------------------------------------------- |
| brainstorming                  | Validate design; ask clarifying questions; propose 2-3 approaches |
| writing-plans                  | Decompose into 2-5 minute tasks; full code + paths in each step   |
| executing-plans                | Execute plan with checkpoints; stop if blocked                    |
| using-git-worktrees            | Isolate work; prefer harness-native worktree tools                |
| subagent-driven-development    | Dispatch fresh subagents per task; two-stage review per task      |
| test-driven-development        | RED-GREEN-REFACTOR; no production code without failing test       |
| systematic-debugging           | Root-cause investigation before any fix                           |
| requesting-code-review         | Dispatch reviewer subagent at task/feature/pre-merge points       |
| receiving-code-review          | Verify accuracy, allow pushback with justification                |
| verification-before-completion | Run command, read output, confirm exit code before "done"         |
| finishing-a-development-branch | Detect git env, present finalization options                      |
| dispatching-parallel-agents    | Run 3+ independent investigations in parallel                     |
| writing-skills                 | TDD applied to skill creation                                     |
| using-superpowers              | Master dispatcher; check applicable skills before any response    |

Distribution: 6+ platforms (Claude Code, Cursor, Copilot CLI, Gemini, OpenCode,
Codex) via a single codebase with platform-conditional directories. Zero
runtime dependencies. License: MIT. Activity: very high (daily commits, v5.1.0
April 2026, strict contribution gate — high PR rejection rate by design).

## Skill-by-skill mapping

| Cave Kit (v4)               | Superpowers                              | Notes                                                                                                               |
| --------------------------- | ---------------------------------------- | ------------------------------------------------------------------------------------------------------------------- |
| `/ck:spec` NEW              | brainstorming + writing-plans (combined) | Cave Kit merges design + tasks into one `SPEC.md`. Superpowers separates exploratory brainstorm from concrete plan. |
| `/ck:spec` DISTILL          | _(no equivalent)_                        | Reverse-engineer spec from existing codebase. Unique to Cave Kit.                                                   |
| `/ck:spec` BACKPROP         | systematic-debugging (partial)           | Bug → invariant. Superpowers debug doesn't write the invariant back to a persistent doc.                            |
| `/ck:spec` AMEND            | _(implicit in spec/plan editing)_        | Targeted section edits without rewrite.                                                                             |
| `/ck:build`                 | executing-plans + subagent-driven        | Cave Kit is single-thread, no subagents in v4. Superpowers fans out tasks to fresh subagents.                       |
| `/ck:check`                 | verification-before-completion (broader) | Cave Kit checks drift against spec; superpowers checks every action's evidence.                                     |
| _(none)_                    | test-driven-development                  | No TDD primitive in Cave Kit. RED-GREEN-REFACTOR is core to superpowers.                                            |
| _(none)_                    | using-git-worktrees                      | Cave Kit doesn't address isolation.                                                                                 |
| _(none)_                    | requesting-code-review / receiving       | No review primitive in Cave Kit v4 (v3 had it; v4 removed).                                                         |
| _(none)_                    | finishing-a-development-branch           | No finalization step in Cave Kit.                                                                                   |
| _(none)_                    | dispatching-parallel-agents              | v4 has no parallelism; v3 did.                                                                                      |
| _(none)_                    | writing-skills                           | Cave Kit doesn't define a skill-authoring primitive.                                                                |
| _(none)_                    | using-superpowers                        | Cave Kit doesn't have a master dispatcher.                                                                          |
| caveman encoding (implicit) | _(none)_                                 | Cave Kit bakes ~75% prose compression into every write. Superpowers writes full prose.                              |

## Workflow shape comparison

**Cave Kit v4:** one living `SPEC.md` is the single source of truth. `/ck:spec`
mutates it, `/ck:build` reads + executes against it, `/ck:check` audits drift.
Tight loop. No subagents, no parallelism, no explicit TDD, no review step. Bug
recovery is automated: `/ck:build` fails → backprop runs → §B + §V update →
resume. The spec is the memory across context resets.

**Superpowers v5.1:** seven explicit stages, each with persistent artifacts
(design doc, plan doc) and hard gates. Per-task subagent dispatch with
two-stage review (spec compliance + code quality). TDD-first. Multiple review
checkpoints. Finalization stage detects git env and cleans up.

## Trade-offs

- **Cave Kit is leaner.** 3 commands + 1 helper vs. 14 skills. Lower cognitive
  overhead. Token-cheap by design (caveman encoding).
- **Cave Kit is thinner.** No TDD primitive, no review step, no worktree
  isolation, no parallel dispatch, no finalization. v3 had these and v4
  intentionally removed them.
- **Superpowers is more prescriptive.** Hard gates between every stage prevent
  shortcut behavior. The cost is process overhead even for small tasks — though
  it has been around longer and has more mileage on what works.
- **Cave Kit's `SPEC.md` is a single artifact**; superpowers' is dated
  per-feature files. The Cave Kit shape is closer to a living architectural
  doc; superpowers' shape is closer to a changelog of design decisions.
- **Caveman encoding baked in.** Cave Kit's compression is a feature not
  available in superpowers. If you adopt superpowers and care about token cost,
  you'd layer caveman (kxa-x83) on top separately.
- **Cross-platform.** Superpowers ships to 6+ agent platforms from one
  codebase. Cave Kit is Claude-only.
- **Maturity.** Superpowers is at v5.1 with very high activity. Cave Kit v4 is
  recent and intentionally narrow.

## Recommendation

**Adopt superpowers as the workflow foundation (proceed with kxa-tts).** Use
Cave Kit as an inspiration source, not a replacement. Reasoning:

1. The Kix workflow needs review, TDD, finalization, and parallel-agent
   primitives. Cave Kit v4 has none of these; v3 had some but is frozen.
   Reintroducing them on top of Cave Kit means rebuilding what superpowers
   already ships.
2. Superpowers' multi-platform distribution matters if Kix grows beyond Claude
   Code (Codex, OpenCode, Cursor are explicit kxa-tts goals). Cave Kit doesn't
   offer that.
3. **Patterns worth borrowing from Cave Kit into Kix:**
   - **Single living `SPEC.md` per project** (alongside per-feature plan docs)
     — could become a Kix convention paired with the bd issue tracker (bd is
     the §T/§B store; a `SPEC.md` could be the §G/§C/§I/§V store).
   - **`backprop`-style "bug → invariant" feedback loop** — when a bd bug issue
     closes, optionally write the lesson as a new acceptance rule on the parent
     epic.
   - **`/ck:spec DISTILL`** for onboarding existing repos — bd already supports
     `bd lint`/`bd doctor`; a "spec from codebase" extractor would complement
     that.
4. **Layer caveman (kxa-x83) regardless** to recover the compression Cave Kit
   gives for free.

Follow-ups tracked in beads:

- **kxa-tts** — continues as a superpowers migration (no scope change). Cave
  Kit was evaluated and rejected as a replacement; recorded here.
- **kxa-h0y** — Adopt living `SPEC.md` + bd convention (Cave Kit inspiration,
  not a replacement skill)
- **kxa-ly3** — Optional backprop hook on bd close (Cave Kit inspiration)
