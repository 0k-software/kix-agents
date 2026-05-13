---
saved_at: 2026-05-13T10:55:00Z
session_id: cse_01Qz8ByMxYiCeBo6KQz2Ez5L
transcript: transcript.jsonl.gz
---

# Build the kix:save-session skill

## Goal

Ship `/kix:save-session [owner/repo] [--no-commit]` — archive a Claude session
(chat or Claude Code) into `docs/sessions/<stem>/` in a target repo as
`transcript.jsonl.gz` (the gzipped session transcript) + an append-only
`log.md`, opening a PR for it or riding along on the current branch's PR.
Plus wire `kix:commit` to bundle the archive into every commit via a
stage-only `--no-commit` mode.

## 2026-05-11 — update

- **Four clarifying questions** for `kxa-bpt` (AskUserQuestion), and what was
  picked:
  1. Session source — Anthropic API conversation fetch vs local-transcript
     read vs both auto-detect. **Picked:** Anthropic API fetch (later
     superseded by reading the project `.jsonl` directly — see 2026-05-12).
  2. Skill location — `/kix:save-session` (kix-namespaced, under
     `claude-code/skills/save-session/`) vs standalone `/save-session`.
     **Picked:** kix-namespaced.
  3. File layout — `conversations/YYYY-MM-DD-slug.md` vs `YYYY/MM/slug.md`
     vs `<ISO-timestamp>.md`. **Picked:** `YYYY-MM-DD-slug.md` (later
     evolved into a per-stem folder with fixed inner filenames — see
     2026-05-12).
  4. Repo-arg resolution — required `<owner/repo>` arg vs default-org
     fallback vs short-name infer. **Picked:** infer from accessible repos
     + chat content, with user confirmation when inferred.
- Filed beads issue **`kxa-bpt`** (feature, P2): "Build /kix:save-session
  skill to archive chat sessions as GitHub PRs", with description,
  acceptance criteria, design notes, follow-ups.
- Opened **PR #34** with `bd: add kxa-bpt` on
  `claude/save-session-skill-gJPv2`.
- First implementation of `claude-code/skills/save-session/SKILL.md` landed
  on PR #34 (Steps 1–6 + error table + `CHANGELOG` `[Unreleased]` entry).
  Set `kxa-bpt` status=`in_progress` + PR #34 link in notes (per the
  `do-not-close-a-beads-issue-right-after` memory).

## 2026-05-12 — update

- **Review round 1 (PR #34 by @kelvinst, "LBTM")** — 4 inline comments,
  addressed in commit `5b3c960`:
  1. Bare repo arg: search accessible repos by name (repo names effectively
     unique across a user's orgs); drop the git-remote-owner guess.
  2. Runtime-agnostic: Step 2 must work from a Claude chat session too —
     not Claude-Code-only.
  3. Store under `docs/conversations/` (vs top-level `conversations/`).
  4. De-assume a shell / checked-out repo / local transcript file; `curl`
     + `GITHUB_TOKEN` is an explicit shell-only fallback.
- **Review round 2** — @kelvinst: "no, do not collapse anything." Commit
  `e2424b3` — Step 2 says render verbatim; nothing collapsed/truncated;
  tool calls, tool results, system content all kept.
- **Testing Q&A** — walked the user through Claude Code vs claude.ai test
  paths. Surfaced honest caveats: no public Anthropic API to fetch
  arbitrary past sessions; a hand-rendered `transcript.md` in a remote
  sandbox is lossy because of compaction.
- **`/kix:rebase!`** onto `origin/main` (which advanced `d899b87..370bef0`,
  picking up the caveman-plugin work). 5 commits replayed; 4 conflicts
  resolved autonomously: `.beads/issues.jsonl` ×2 (kept caveman issues +
  `kxa-bpt`), `CHANGELOG.md` ×2 (kept both `[Unreleased]` bullets).
  Force-pushed with `--force-with-lease`.
- **First dry-run as PR #41** (since closed). Hit a real limit: the 1.2 MB
  transcript was too big to round-trip through the GitHub Contents API in
  a tool call, so the archive was committed via a local git checkout
  branched from `main`. Findings: transcript size vs API; "current
  session ≠ this conversation" — hosted-sandbox Claude Code spawns a
  fresh `claude --resume` per web turn, leaving many `.jsonl` files; two
  PRs for one skill is confusing.
- **Session-id keying** — user: "reference by id so a re-save overwrites."
  Embedded the session's short id (first 8 alphanumerics of the session
  id) in the filename suffix; pre-write lookup matches `*-<short-id>*`
  and reuses the stem on re-save; branch `claude/save-session-<stem>` is
  stable; an existing open PR is updated, not duplicated.
- **One folder per session** — user: "maybe a folder with the stem."
  Switched to `docs/conversations/<stem>/` with fixed inner filenames
  (initially `transcript.jsonl`, `summary.md`, `raw.md`). Re-save lookup
  matches the directory name (or inner frontmatter `session_id`).
- Closed PR #41 (dry-run). Iterated inner filenames: first `raw.jsonl` /
  `raw.md` (pairing the verbatim artifact); later (2026-05-13) renamed
  back to **`transcript.jsonl.gz`** / **`transcript.md`** — the standard
  term and what Claude/Anthropic docs use. Iterated PR-body link labels:
  "Conversation Summary:" → "Session summary:" → final "Session log:"
  after the `log.md` rename. Opened **PR #43** as a second standalone-save
  demo.
- **Local vs remote distinction** — answered the user: local Claude Code
  keeps one growing `.jsonl` per session (`claude --continue` /
  `--resume <id>` keeps the same id); the fragmentation seen in this
  conversation is a hosted-sandbox artifact.
- **Remote sandbox env vars** — discovered `CLAUDE_CODE_REMOTE=true` and
  `CLAUDE_CODE_REMOTE_SESSION_ID=cse_01Qz8ByMxYiCeBo6KQz2Ez5L` (stable
  across turns; the only id that doesn't change). First wired the skill
  to "skip jsonl, render the fallback from context" in remote mode
  (commit `6c6aa98`).
- **Corrected** (commit `683cb4e`) — the remote-skip was based on a wrong
  premise: each `claude --resume` *copies the prior transcript forward
  and appends*, so the **largest** `.jsonl` in the project dir is the
  complete cumulative transcript, not a fragment. The skill now always
  uses the largest project `.jsonl`; the rendered fallback applies only
  when no transcript file exists at all (chat session).
  `CLAUDE_CODE_REMOTE_SESSION_ID` still picks the re-save key.
- **Compaction does not shrink the `.jsonl`** — inspected all ~50
  `.jsonl` files under `~/.claude/projects/-home-user-kix-agents/`:
  sizes only grow (135 KB → 311 KB → … → ~2.4 MB at the time); no
  compaction-truncation markers. The largest `.jsonl` is *more*
  complete than the live in-context view.

## 2026-05-13 — update

- **Repo-size math vs Git LFS** — measured: this session ≈ 2.6 MB raw,
  ≈ 0.61 MB gzipped (4.3×, not the 10× I'd guessed). Sessions to a 1 GB
  repo: ~430 plain / ~1,800 gz. A single `transcript.jsonl.gz` would have
  to hit ~100 MB to force LFS, which would mean ~1 GB raw ≈ ~80k turns
  in one session — never happens. **Verdict:** gzip in-repo, no LFS;
  prune old archives or move raw transcripts to a backup repo only if
  cumulative volume warrants.
- **Rendered-`.md` experiment** — also measured: rendering the `.jsonl`
  to markdown (drop hook noise, elide `<system-reminder>` blocks, cap
  tool results) → ~0.41 MB plain / 0.087 MB gz, ~6× smaller than raw
  `.jsonl` and readable in the GitHub UI. Briefly switched to this.
  **User reverted:** rendering costs LLM tokens; a gzipped raw `.jsonl`
  stays searchable via `zcat | grep` and is the true raw record.
  **Final:** commit `transcript.jsonl.gz` (the largest project `.jsonl`,
  gzipped). Added `.gitattributes` marking
  `docs/sessions/**/transcript.jsonl.gz binary` so diffs read "Binary
  files differ".
- **Work-branch destination** — user: don't open a new PR when the
  current branch already has one; bundle the archive into that branch's
  PR instead. Step 3 now has a Destination Mode: local checkout +
  current branch ≠ default → **work-branch save** (commit straight onto
  the working branch; leave its PR title/body alone); otherwise (default
  branch / no checkout / chat session) → standalone
  `claude/save-session-<stem>` branch + new PR.
- **`log.md` from context, not the `.jsonl`** — user: don't re-read the
  transcript to summarize; the in-context view (compacted older turns
  included) is plenty.
- **Append-only `log.md`** — user: re-saves should not regenerate the
  file (LLM nondeterminism → noisy diffs, lost history). First save
  creates a Goal + one or more update sections; each re-save *appends*
  a `## <timestamp> — update` section covering only what's happened
  since.
- **Auto-bundle on every `/kix:commit`** — user picked "always bundle
  on every kix:commit". First version duplicated the save-session
  details inline in `commit/SKILL.md` — user pushed back. Refactored by
  adding **`/kix:save-session --no-commit`** (stage-only: write archive
  + `git add`, no commit/push/PR — caller commits). `kix:commit`
  Step 1 collapsed to a one-line invocation. The bundling is placed
  **after staging** so in the mixed-index case the archive isn't swept
  into the auto-stash; session-scoped ≠ commit-scoped is fine — each
  split commit carries an updated archive, the last one is complete.
- **`docs/conversations/` → `docs/sessions/`** rename — "session" fits
  chat + Claude Code better than "conversation". Skill stays
  `kix:save-session`. PR-body link label, `.prettierignore`,
  `.gitattributes`, CHANGELOG, and the committed archive folder all
  followed.
- **Open Questions checklist** — user: questions go in a trailing
  `## Open Questions` section as GitHub-style `- [ ]` / `- [x]` items;
  when answered, flip to `[x]` and add the answer as a sub-item (don't
  delete the question — keep the trail); new questions surfaced this
  turn go in as fresh `- [ ]`. Update sections insert *before* Open
  Questions so updates stay in time order.
- **Action Items section** — user: add a trailing `## Action Items`
  checklist for things to remember to do (close a PR, follow up on a
  beads issue, ship a follow-up change, …). When done, flip to `- [x]`
  with a sub-item carrying the reference (beads id / PR # / commit
  SHA); if a beads issue is filed for the item, mark `[x]` with the
  beads id and let the tracker carry it. Order: Goal → updates (time
  order) → Open Questions → Action Items (tail).
- **Rename `summary.md` → `log.md`** — "summary" undersold the running
  step-by-step nature. Picked **`log.md`** (over `journal.md` /
  `notes.md` / keeping `summary.md`). PR-body link relabeled
  "Session log:".
- **Step-by-step specificity; first-save split by date** — user
  feedback: the file had been too vague and too final-state. Spec'd:
  - every update records what was decided, the alternatives
    considered, what won and why, and concrete refs (beads id, PR #,
    commit SHA, file path);
  - on a **first save**, reconstruct the prior conversation as
    multiple `## <YYYY-MM-DD> — update` sections (or per-topic
    sub-sections within a day), not one big section. Same shape a
    series of re-saves would have produced.
  - This `log.md` was rewritten to follow that.
- **Inner filename rename: `raw.*` → `transcript.*`** —
  `transcript.jsonl.gz` (the verbatim record) and `transcript.md` (the
  rendered fallback when no transcript file exists). "Transcript" is
  the standard term for the verbatim record of an LLM session — what
  Anthropic docs and Claude Code itself use. Frontmatter key
  `raw_transcript:` → `transcript:`. `.gitattributes` pattern updated.

## Open Questions

- [x] Is a gzipped `.jsonl` (not directly rendered/searchable in the
      GitHub UI) acceptable as the archive format?
  - **Resolved (2026-05-13):** yes — clone + `zcat | grep` is the
    accepted trade-off; the gz blob keeps the repo small and is the
    true raw record.
- [ ] At scale (~few thousand sessions ≈ 1 GB), prune older archives
      down to just `log.md` or move raw transcripts to a separate
      backup repo?

## Action Items

- [ ] Close or refresh PR #43 (standalone-save demo, still on the old
      `docs/conversations/` path with the older filenames).
- [ ] Close `kxa-bpt` once PR #34 merges.
