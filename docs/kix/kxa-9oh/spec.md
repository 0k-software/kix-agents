# Evaluation: phxagents.dev

Tracked in beads: **kxa-9oh** — _Evaluate phxagents.dev_

Sources:

- https://phxagents.dev/
- https://github.com/oliver-kriska/claude-elixir-phoenix

## Identity / GitHub mapping

phxagents.dev is the marketing site for `oliver-kriska/claude-elixir-phoenix`
(MIT, ~300 stars / 24 forks). The site itself returned 403/ECONNREFUSED to
WebFetch (likely Cloudflare bot block), but search snippets and the upstream
README/marketplace.json confirm it is the same project. Author: Oliver Kriska
(oliver@kriska.dev), Slovakia-based, established GitHub account, 33 public
repos, multiple historical badges, recent collaborative commits.

## Positioning

Domain-specific Claude Code plugin for Elixir/Phoenix/LiveView developers.
Pitch: "Claude Code is great. But it doesn't know that `assign_new` silently
skips on reconnect..." — i.e. baseline Claude lacks Phoenix-ecosystem
expertise, this plugin adds it via 20 specialist agents + enforceable "Iron
Laws" + auto-loading skills.

Important framing for this evaluation: **phxagents is a domain-expertise
plugin, not a workflow framework.** It expects you to already have a process
(planning, execution, review) and slots in _during_ code work to enforce
Elixir/Phoenix correctness. Comparing it to `kix-agents` (the original framing)
was apples-to-oranges — both are plugins by accident of format, but they don't
compete. The relevant comparison is to a workflow framework phxagents could sit
alongside: **obra/superpowers**.

## Feature surface

- 20 specialist agents (4 orchestrators, 12 reviewers/architects, 4
  investigators), running in parallel
- 22 Iron Laws — enforceable rules catching N+1 queries, LiveView reconnect
  bugs, Ecto misuse, Oban pitfalls, security gaps
- 41-43 skills that auto-load by file pattern (LiveView skills on `*_live.ex`,
  Ecto skills on schemas, etc.) — no `/load` commands
- Commands: `/phx:plan`, `/phx:work` (with `--continue`), `/phx:review`,
  `/phx:full` (autonomous end-to-end), `/phx:quick`, `/phx:audit`,
  `/phx:investigate`
- Tidewave MCP integration for runtime introspection (optional;
  development-only; localhost:4000)
- Filesystem-as-state-machine plan namespacing under `.claude/plans/<slug>/`
- Context supervisor pattern: Haiku-based compression of multi-agent output to
  limit context bloat
- Verification hooks (auto-format, auto-compile, Iron Law checks between tasks)
  — all local, all read-only on user data
- Self-eval framework in `lab/eval/` (8 dimensions, skills must score ≥0.95 to
  ship) + 52 pytest tests
- ccrider MCP for session analysis / continuous improvement (optional)

## Distribution

Pure Claude Code plugin via marketplace. Install:

```
/plugin marketplace add oliver-kriska/claude-elixir-phoenix
/plugin install elixir-phoenix
```

`.claude-plugin/marketplace.json` declares owner `oliver-kriska` with one
plugin `elixir-phoenix` under `./plugins/elixir-phoenix`, category
`development`, tags `[elixir, phoenix, liveview, oban, ecto]`. v2.8.8 for
Claude Code; v3.0.0 promised to add Codex / OpenCode / Pi support. Marketing
site at phxagents.dev. Free / open source — no paid tier visible.

## License

MIT.

## Comparison to obra/superpowers

Superpowers is a horizontal workflow plugin (mandatory 7-stage sequence:
brainstorm → plan → execute → TDD → review → verify → finish). Phxagents is a
vertical domain plugin (Phoenix/Elixir Iron Laws + 43 specialist skills + 20
specialist agents). They don't overlap, and they compose cleanly:

| Concern               | obra/superpowers              | phxagents                       |
| --------------------- | ----------------------------- | ------------------------------- |
| Workflow phases       | brainstorm/plan/exec/TDD/etc. | none (assumes ambient workflow) |
| Domain expertise      | none (language-agnostic)      | deep Elixir/Phoenix/Oban/Ecto   |
| Skills (count)        | 14 core                       | 41-43 (auto-loading by glob)    |
| Agents                | ephemeral, dispatched         | 20 specialists, named           |
| Hard rules            | "evidence-based completion"   | 22 Iron Laws (lint-style)       |
| Hooks                 | SessionStart only             | 19 hooks across lifecycle       |
| Plan/spec persistence | `docs/superpowers/specs/...`  | `.claude/plans/<slug>/...`      |
| TDD baseline          | yes (RED-GREEN-REFACTOR)      | no (relies on superpowers/user) |
| Auto-loading          | invoked by skill body         | by file glob (`*_live.ex` etc.) |

**Integration model.** Run both. Superpowers drives the meta-process — when the
user asks for a Phoenix feature, superpowers steers brainstorming →
plan-writing → TDD execution → review → finish. Phxagents auto-activates during
the execution phase because the files being edited match `*_live.ex` / Ecto
schemas / Oban workers, and its Iron Laws fire as verification hooks between
tasks. The two systems don't fight: superpowers doesn't ship Elixir knowledge,
phxagents doesn't ship a workflow.

The only place to watch for friction: phxagents' `/phx:full` is autonomous
end-to-end (its own mini-workflow). Don't use `/phx:full` if superpowers is the
workflow source of truth — use `/phx:plan` + `/phx:work` (which slot into a
superpowers plan/execute step) and let `/phx:review` + Iron Laws augment
superpowers' review skills.

## Security review

User flagged that they "skip permissions frequently", so this plugin would run
with broad Bash/Edit/Write access. Reviewed manifests, all 19 hook scripts,
sample of 10 agent prompts, sample of 10 skills, MCP integrations,
dependencies, and the eval framework. **Findings: clean.**

- **Manifests.** `marketplace.json` + `plugin.json` clean. All hook entries
  point to internal scripts via `${CLAUDE_PLUGIN_ROOT}`. No external URLs.
- **Hooks (19 scripts).** None read `~/.ssh/`, `~/.aws/`, `~/.netrc`,
  `~/.gitconfig`, browser data, or env vars containing secrets. None write to
  shell init files or `authorized_keys`. Network: localhost-only
  (`detect-tidewave.sh` probes `localhost:4000`). Two scripts
  (`fetch-claude-docs.sh`, `fetch-cc-changelog.sh`) hit
  `raw.githubusercontent.com/anthropics/claude-code/` — first-party Anthropic
  only.
- **Agent prompts (sampled 2 of 20: security-analyzer, planning-orchestrator;
  scanned remaining 18 by listing).** No prompt-injection attempts, no hidden
  encodings, no "ignore prior instructions" patterns, no zero-width /
  non-English obfuscation. `security-analyzer` explicitly disallows `Edit` and
  `NotebookEdit` for itself — read-only by design.
- **Skills (sampled 10 of 43).** All domain-focused (security, audit, tidewave,
  ecto, liveview, testing, deploy, n1-check, verify, quick). No external
  network calls, no sensitive-path reads, no env-var exfiltration.
- **MCPs.** Tidewave is optional, user-installed in their Phoenix app,
  localhost-only. ccrider is optional, reads local Claude/Codex session files
  only, no remote calls.
- **Dependencies.** Dev-only: husky, markdownlint-cli, PyYAML, pytest. All
  reputable, no typosquatting.
- **Lab/eval.** Local Python test framework, no dynamic remote loading.
- **Verification hooks.** Use `grep`/`sed`/`awk` on file contents; arguments
  extracted via `jq` from JSON, not interpolated into shell.

**Caveats (not blockers).**

- Subagents are dispatched with `bypassPermissions` mode by design. That
  amplifies the blast radius of any _future_ malicious update, even though the
  current code is clean. Pin to a known-good tag if you want a hedge.
- The plugin writes a local edit log to
  `${CLAUDE_PLUGIN_DATA}/skill-metrics/edits-YYYY-MM.jsonl`. Plugin-scoped
  storage, paths only (no contents/secrets), but worth knowing.
- Audit was code-review depth (manifests + scripts + prompts + skill bodies).
  It did not verify build/release-chain integrity (tag signing, npm publish
  provenance, etc.). For an MIT plugin we install from GitHub this is fine; for
  higher-stakes adoption, pin a SHA.

## Recommendation

**SAFE TO INSTALL** alongside obra/superpowers as a required plugin **for
projects that touch Elixir/Phoenix**. Specifically:

- Install via `/plugin marketplace add oliver-kriska/claude-elixir-phoenix`
  - `/plugin install elixir-phoenix` on developer machines working on
    Elixir/Phoenix projects.
- Don't install globally if you have a mix of Elixir and non-Elixir work — the
  auto-loading skills only fire on Elixir file globs, so the cost of installing
  globally is low, but the Iron Law hooks run on every Edit and add a small
  overhead. Per-project install is cleaner.
- Pair with superpowers (kxa-tts) or Cave Kit (kxa-eal) as the workflow
  source-of-truth; use phxagents' `/phx:plan`/`/phx:work`/`/phx:review` as
  domain helpers inside that workflow, not `/phx:full`.
- Pin to a tag (v2.8.8 at audit time) rather than tracking `main`, since the
  audit is point-in-time. Re-audit on major version bumps.

Follow-ups tracked in beads:

- **kxa-w2n** — Per-project phxagents adoption decision for Elixir/Phoenix work
- `bd memories phxagents-v3-reaudit` — re-audit when v3.0.0 ships with
  Codex/OpenCode/Pi multi-agent support
