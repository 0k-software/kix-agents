---
saved_at: 2026-05-14T21:00:45Z
session_id: cse_01Qz8ByMxYiCeBo6KQz2Ez5L
transcript: transcript.jsonl.gz
---

# Build the kix:save-session skill

## Goal

Ship `/kix:save-session [owner/repo] [--no-commit]` — archive a Claude session
(chat or Claude Code) into `docs/sessions/<stem>/` in a target repo as
`transcript.jsonl.gz` (the gzipped session transcript) and an append-only
`log.md` (step-by-step running history), opening a PR for it or riding along
on the current branch's PR. Plus wire `kix:commit` to bundle the archive into
every commit via a stage-only `--no-commit` mode.

## 2026-05-11 — update

### Filed the tracking issue (`kxa-bpt`)

Asked four clarifying questions before filing the beads issue
(AskUserQuestion); the choices made:

1. **Session source** — Anthropic API conversation fetch vs local-transcript
   read vs both auto-detect. **Picked:** Anthropic API fetch (later
   superseded — see 2026-05-12).
2. **Skill location** — `/kix:save-session` (kix-namespaced under
   `claude-code/skills/save-session/`) vs standalone `/save-session`.
   **Picked:** kix-namespaced.
3. **File layout** — `conversations/YYYY-MM-DD-slug.md` vs `YYYY/MM/slug.md`
   vs `<ISO-timestamp>.md`. **Picked:** `YYYY-MM-DD-slug.md` (later evolved
   into a per-stem folder with fixed inner filenames).
4. **Repo-arg resolution** — required `<owner/repo>` arg vs default-org
   fallback vs short-name infer. **Picked:** infer from accessible repos +
   chat content, with user confirmation when inferred.

Filed `kxa-bpt` (feature, P2) — "Build /kix:save-session skill to archive
chat sessions as GitHub PRs" — with description, acceptance criteria, design
notes, and follow-ups. Opened **PR #34** on
`claude/save-session-skill-gJPv2`. Set `kxa-bpt` status=`in_progress` + the
PR URL in `--notes` (per the `do-not-close-a-beads-issue-right-after`
memory).

### First implementation

Wrote `claude-code/skills/save-session/SKILL.md` (Steps 1–6 + error table)
and a `CHANGELOG` `[Unreleased]` entry. Updated PR #34 title and body.

## 2026-05-12 — update

### Review feedback addressed (PR #34 by @kelvinst, "LBTM")

Four inline comments, addressed in commit `5b3c960`:

1. **Bare repo arg**: search accessible repos by name (names are effectively
   unique across a user's orgs); drop the git-remote-owner guess.
2. **Runtime-agnostic**: Step 2 must work from a Claude chat session too —
   not Claude-Code-only.
3. **Move under `docs/conversations/`** (vs top-level `conversations/`).
4. **De-assume a shell / checked-out repo / local transcript file**; `curl`
   + `GITHUB_TOKEN` is an explicit shell-only fallback.

A fifth comment ("no, do not collapse anything") addressed in commit
`e2424b3` — Step 2 says render verbatim; nothing collapsed/truncated; tool
calls, tool results, system content all kept.

### Testing Q&A + rebase + first dry-run

Walked the user through Claude Code vs claude.ai test paths. Honest caveats
surfaced: no public Anthropic API to fetch arbitrary past sessions; a
hand-rendered `transcript.md` in a remote sandbox is lossy because of
compaction.

`/kix:rebase!` onto `origin/main` (advanced `d899b87..370bef0`, picked up
the caveman-plugin work). 5 commits replayed; 4 conflicts resolved
autonomously: `.beads/issues.jsonl` ×2 (kept caveman issues + `kxa-bpt`);
`CHANGELOG.md` ×2 (kept both `[Unreleased]` bullets). Force-pushed.

First dry-run as **PR #41** (since closed). Hit a real limit: the 1.2 MB
transcript was too big to round-trip through the GitHub Contents API in a
tool call, so the archive was committed via a local git checkout branched
from `main`. Findings: transcript size vs API; "current session ≠ this
conversation" — hosted-sandbox Claude Code spawns a fresh `claude --resume`
per web turn, leaving many `.jsonl` files; two PRs for one skill is
confusing.

### Artifact-design iteration

- **Session-id keying** — user: "reference by id so a re-save overwrites."
  Embedded the session's short id (first 8 alphanumerics) in the filename
  suffix; pre-write lookup matches `*-<short-id>*` and reuses the stem on
  re-save; branch `claude/save-session-<stem>` stays stable; an existing
  open PR is updated, not duplicated.
- **One folder per session** — user: "maybe a folder with the stem."
  Switched to `docs/conversations/<stem>/` with fixed inner filenames.
- PR #41 closed; opened **PR #43** as a second standalone-save demo (since
  closed on 2026-05-13).
- Inner filenames iterated: initially `transcript.jsonl` / `summary.md` /
  `raw.md`; renamed `transcript.jsonl` → `raw.jsonl` mid-day (pair the
  verbatim artifact); on 2026-05-13 reverted to **`transcript.jsonl.gz`** /
  **`transcript.md`** (the standard term for the verbatim record). PR-body
  link label went "Conversation Summary:" → "Session summary:" → finally
  "Session log:".

### Hosted-sandbox understanding

- **Local vs remote** — answered the user: local Claude Code keeps one
  growing `.jsonl` per session (`claude --continue` / `--resume <id>` keeps
  the same id); the fragmentation seen in this conversation is a
  hosted-sandbox artifact.
- **Env vars** — discovered `CLAUDE_CODE_REMOTE=true` and the stable
  `CLAUDE_CODE_REMOTE_SESSION_ID=cse_01Qz8ByMxYiCeBo6KQz2Ez5L` (the only id
  that doesn't change across turns).
- First wired the skill to "skip jsonl, render the fallback from context"
  in remote mode (commit `6c6aa98`).
- **Corrected** (commit `683cb4e`) — each `claude --resume` *copies the
  prior transcript forward and appends*, so the **largest** `.jsonl` in the
  project dir is the complete cumulative transcript, not a fragment. The
  skill now always uses the largest project `.jsonl`; the rendered fallback
  applies only when no transcript file exists at all (chat session).
  `CLAUDE_CODE_REMOTE_SESSION_ID` still picks the re-save key.
- **Compaction does not shrink the `.jsonl`** — verified by inspecting all
  ~50 `.jsonl` files in `~/.claude/projects/-home-user-kix-agents/`: sizes
  only grow; no compaction-truncation markers. The largest is *more*
  complete than the live in-context view.

## 2026-05-13 — update

### Repo-size math vs Git LFS

Measured: this session ≈ 2.6 MB raw, ≈ 0.61 MB gzipped (4.3×, not the 10×
I'd guessed). Sessions to a 1 GB repo: ~430 plain / ~1,800 gz. A single
`transcript.jsonl.gz` would have to hit ~100 MB to force LFS, which means
~1 GB raw ≈ ~80k turns in one session — never. **Verdict:** gzip in-repo,
no LFS; prune old archives or move raw transcripts to a backup repo only
if cumulative volume warrants.

### Rendered-`.md` experiment (and revert)

Tried rendering the `.jsonl` to markdown as the archive instead: ~0.41 MB
plain / 0.087 MB gz, ~6× smaller than raw `.jsonl` and readable in the
GitHub UI. **User reverted:** rendering costs LLM tokens; a gzipped raw
`.jsonl` stays searchable via `zcat | grep` and is the true raw record.
**Final:** commit `transcript.jsonl.gz`. Added `.gitattributes` marking
`docs/sessions/**/transcript.jsonl.gz binary` so diffs read "Binary files
differ".

### Behavior refinements

- **Work-branch destination** — user: don't open a new PR when the current
  branch already has one; bundle the archive into that branch's PR
  instead. Step 3 now has a Destination Mode: local checkout + current
  branch ≠ default → **work-branch save**; otherwise (default branch /
  no checkout / chat session) → standalone `claude/save-session-<stem>`
  branch + new PR.
- **`log.md` from context, not the `.jsonl`** — don't re-read the
  transcript to build the log; the in-context view (compacted older turns
  included) is plenty.
- **Append-only `log.md`** — re-saves don't regenerate the file (LLM
  nondeterminism → noisy diffs, lost history). First save creates a Goal
  + one or more update sections; each re-save *appends* a
  `## <timestamp> — update` section covering only what's happened since.
- **Auto-bundle on every `/kix:commit`** — user picked "always bundle on
  every kix:commit". First version duplicated the save-session details
  inline in `commit/SKILL.md` — user pushed back. Refactored by adding
  **`/kix:save-session --no-commit`** (stage-only: write archive +
  `git add`; no commit/push/PR — caller commits). `kix:commit` Step 1
  collapsed to a one-line invocation. Bundling is placed **after staging**
  so in the mixed-index case the archive isn't swept into the auto-stash;
  session-scoped ≠ commit-scoped is fine (each split commit carries an
  updated archive; the last one is complete).
- **`docs/conversations/` → `docs/sessions/`** rename — "session" fits
  chat + Claude Code better than "conversation". Skill stays
  `kix:save-session`.

### Trailing checklist sections

- **Open Questions** — trailing section as a GitHub-style `- [ ]` / `- [x]`
  checklist; when answered, flip to `[x]` and add the answer as a sub-item
  (don't delete the question — keep the trail). Update sections insert
  *before* Open Questions so updates stay in time order.
- **Action Items** — trailing section after Open Questions, same checklist
  shape, for things to remember to do (close a PR, follow up on a beads
  issue, ship a follow-up). When done, flip to `[x]` with a sub-item
  carrying the reference (beads id / PR # / commit SHA). If a beads issue
  is filed for the item, mark `[x]` with the beads id and let the tracker
  carry it. Final section order: Goal → updates (time order) → Open
  Questions → Action Items.

### Naming & quality refinements

- **Rename `summary.md` → `log.md`** — "summary" undersold the running
  step-by-step nature. Chose `log.md` (over `journal.md` / `notes.md` /
  keeping `summary.md`). PR-body link relabeled "Session log:".
- **Inner files `raw.*` → `transcript.*`** — `transcript.jsonl.gz` for the
  verbatim record, `transcript.md` for the rendered fallback. "Transcript"
  is the standard term for the verbatim record of an LLM session (what
  Anthropic docs and Claude Code itself use). Frontmatter key
  `raw_transcript:` → `transcript:`. `.gitattributes` pattern updated.
- **Step-by-step specificity; first-save split by date** — user feedback:
  the log had been too vague and too final-state. Spec'd:
  - every update records what was decided, the alternatives considered,
    what won and why, and concrete refs (beads id / PR # / commit SHA /
    file path);
  - on a **first save**, reconstruct the prior conversation as multiple
    `## <YYYY-MM-DD> — update` sections (or per-topic sub-sections within
    a day), not one big section.
- **Regenerated this `log.md` from scratch** to verify the from-scratch
  path produces a good step-by-step log on a long-running session.

## 2026-05-13T12:07Z — update

### Allowlist fallback to `GITHUB_TOKEN`

- User: if the GitHub MCP server's allowlist blocks the target repo, fall
  back to the REST API + `GITHUB_TOKEN` instead of aborting.
- Reworked Step 1 #4 in `claude-code/skills/save-session/SKILL.md`: try a
  cheap MCP read on the repo and branch into three outcomes — (a) OK → use
  MCP for writes; (b) outside allowlist or no MCP at all → fall back to
  `curl` + `${GITHUB_TOKEN:-${GH_TOKEN}}` for every subsequent write
  (`create_branch` → `POST /repos/{o}/{r}/git/refs`,
  `create_or_update_file` → `PUT /repos/{o}/{r}/contents/{path}`,
  `create_pull_request` → `POST /repos/{o}/{r}/pulls`, etc.); (c) neither
  works → abort with a clear "set a token or extend the allowlist"
  message. Never use the `gh` CLI.
- Credentials section updated to spell out the three states explicitly.
- Error-table row "Repo not accessible / outside MCP allowlist" relaxed:
  fall back to REST API + token; abort only when no token is set.

## 2026-05-14T11:51Z — update

### `name:` field added to every skill frontmatter

- User: add a `name` field to all skill files' frontmatter (previously
  implicit from the folder name).
- Inserted `name: <skill>` as the first frontmatter line under `---` in each
  `claude-code/skills/*/SKILL.md` (eight files: `save-session`, `commit`,
  `rebase`, `fix-pr`, `triage`, `address`, `address-pr`, `fix`); name value
  = the folder basename. Done by `sed -i "1a name: $name" "$f"` after a
  `grep -q '^name:'` guard so re-runs are idempotent.

## 2026-05-14T12:27Z — update

### Dropped Anthropic API path; chat sessions go to "handoff mode"

- User: the Anthropic-API conversation-fetch path doesn't apply — the skill is
  always called from inside the session being saved, never to fetch a foreign
  one. Removed `ANTHROPIC_API_KEY` from the Credentials section and the
  matching error-table row in `claude-code/skills/save-session/SKILL.md`. Also
  removed the API mention from CHANGELOG.
- Step 2 #2 rewritten: rendered fallback now reads only "the conversation
  already in context" (chat session) — no API call.
- **New chat-session behavior — handoff mode.** A chat-session caller has no
  GITHUB_TOKEN/MCP write access, so the skill can't push. Step 1 #4 outcome
  (c) ("no MCP write access AND no token") now switches to **handoff mode**
  instead of aborting:
  - Produce `transcript.md` (verbatim render of the in-context conversation)
    + `log.md` (same step-by-step shape as for any first save).
  - Emit both files as fenced markdown blocks in the chat reply, each preceded
    by its intended `docs/sessions/<stem>/<file>` path.
  - Emit a paste-able Claude-Code handoff prompt that tells a CC session to
    create the per-session folder + commit + push + PR with those two files.
  - Don't try to push/PR; the CC paste does that.
- Step 3 destination-mode reworked to include handoff as a first-class branch
  alongside work-branch / standalone / `--no-commit`. Step 6 report and the
  error table updated.

### Source-link in `log.md`

- User: every `log.md` should link back to the actual session that produced
  it. Added an optional `session_url:` frontmatter field (claude.ai sessions →
  `https://claude.ai/chat/<conversation-id>`; Claude Code → omit) and a
  `> Source: …` blockquote right under the `# Title` heading.

## 2026-05-14T12:34Z — update

### Dropped the `[owner/repo]` argument

- User: the repo argument is redundant. In CC, the repo is obvious from the
  checkout's `git remote get-url origin`. In chat, the skill emits a handoff
  prompt — the user pastes it into a CC session that *already knows* its repo.
  So there's nothing left for the argument to do.
- `argument-hint:` frontmatter → `[--no-commit]`.
- Step 1 collapsed: no more explicit-arg parsing, no inference, no
  `AskUserQuestion` confirmation. Just `git remote get-url origin`. Verify
  reachability + branch into MCP / token fallback / handoff exactly as before.
- Step 5's "if the repo argument was inferred …" paragraph removed.
- Step 6 report line shortened to "target = git remote".
- Error-table row "No repo arg and no plausible candidate / user declines"
  removed (no longer reachable).
- CHANGELOG bullet updated: `[owner/repo]` → `[--no-commit]`.

### Handoff prompt: paste the chat URL into it

- User: before the paste-prompt in the chat reply, instruct the user to grab
  their claude.ai chat URL (or click **Share** for a public link) and paste
  it into the prompt so CC can record it as `session_url:`.
- Step 4 Handoff branch reordered into three parts:
  1. A short paragraph at the top of the chat reply: open the chat in
     claude.ai, copy the URL or share link, paste it into the
     `<paste session URL here>` slot in the prompt below.
  2. The two files (`transcript.md` + `log.md`) as fenced blocks under their
     intended `docs/sessions/<stem>/…` paths. `log.md` frontmatter leaves a
     literal `<paste session URL here>` placeholder in `session_url:` and in
     the `> Source:` blockquote — the CC session replaces both when it lands
     the archive.
  3. The Claude-Code paste prompt itself, with `Session URL: <paste session
     URL here>` near the top so the swap is mechanical.
- Prompt no longer takes an `<owner/repo>` — it commits in "the current repo
  of the CC session."

## 2026-05-14T15:01Z — update

### Handoff: tell user to copy the private chat URL, not the Share link

- User: the handoff paragraph offered "either the chat URL or the public Share
  link" — change to **private chat URL only**. Share links are public
  snapshots (don't update; expose the conversation), whereas the private chat
  URL points back at the live conversation in the user's account.
- Edited Step 4's handoff paragraph in
  `claude-code/skills/save-session/SKILL.md`: tell the user to copy the URL
  from the browser address bar (`https://claude.ai/chat/<uuid>`) and
  explicitly **not** the Share link.

## 2026-05-14T17:06Z — update

### Handoff: one copy-paste block (two-turn flow)

- User: present the handoff as a **single block** that's pasted into Claude
  Code in one go — no instructions-then-files-then-prompt scavenger hunt.
- Step 4 Handoff rewritten as two turns:
  - **Turn A:** stop and ask the user for the **private** chat URL from the
    browser address bar (`https://claude.ai/chat/<uuid>` — not the public
    Share link). Wait for the reply.
  - **Turn B:** with the URL in hand, render the final `transcript.md` +
    `log.md` with the URL already substituted into `session_url:` frontmatter
    and the `> Source:` blockquote — no `<paste session URL here>`
    placeholders left. Emit **one outer fenced block** (4-backtick fence so
    the inner 3-backtick fences survive) containing the CC prompt + both
    files inline. The chat reply has only a one-liner above the block:
    "Copy the block below and paste it into a Claude Code session at
    `<owner/repo>`."
- The CC prompt instructs CC to use `/kix:commit` so the archive rides along
  with whatever's already in the index (work-branch save when on a feature
  branch, standalone otherwise).

## 2026-05-14T17:09Z — update

### Handoff URL: accept both address-bar URL and Share-button link

- User: the earlier "private chat URL, not the Share link" wording was too
  restrictive. Share-button links from claude.ai are fine too.
- Turn-A prompt in Step 4 reworded: "copy a link to it — either the URL from
  the address bar (`https://claude.ai/chat/<uuid>`) or one from the **Share**
  button". Whichever the user pastes is what gets baked into `session_url:`
  and the `> Source:` blockquote.

## 2026-05-14T17:17Z — update

### Pruning split out as a separate skill (`kxa-9nh`)

- The trailing Open Question "prune older archives at scale or move raw
  transcripts to a backup repo" is real future work but not in scope for
  `kxa-bpt` itself. Filed **`kxa-9nh`** (feature, P3) for a
  `/kix:prune-sessions` skill: lists archives under `docs/sessions/`
  oldest-first, takes a user-picked threshold (older-than-date / oldest-N /
  above-total-size), and either prunes in place (`git rm` the
  `transcript.jsonl.gz` / `transcript.md`, keep `log.md`) or moves the
  verbatim files to a backup repo configured via env var
  `KIX_SESSION_BACKUP_REPO=<owner/repo>`. User-driven (destructive),
  idempotent, commits through `/kix:commit`. Blocked-by `kxa-bpt` so the
  save-session skill lands first.
- The Open Question is flipped to `[x]` with `bd kxa-9nh` as the sub-item;
  the tracker carries it from here.

## 2026-05-14T20:58Z — update

### Handoff Turn B: drop outer 4-backtick fence, use BEGIN/END COPY sentinels

- User: 4-backtick outer fence doesn't actually fix rendering on claude.ai —
  the inner 3-backtick fences render mangled inside it.
- Step 4 Turn B reworked: drop the outer code fence entirely. Emit the handoff
  payload as plain markdown between two visible sentinels —
  `--- BEGIN COPY ---` and `--- END COPY ---`. The two 3-backtick fences
  inside (for `transcript.md` and `log.md`) render as their own code blocks;
  the prose around them renders as prose; the user selects the whole region
  between the sentinels and copies once.
- One-liner above the region: "Copy everything between
  `--- BEGIN COPY ---` and `--- END COPY ---` and paste it into a Claude Code
  session at `<owner/repo>`."

## 2026-05-14T21:00Z — update

### Revert: 4-backtick outer fence works, was just slow to print

- Correction to the previous turn: claude.ai **does** render nested 3-backtick
  fences inside a 4-backtick outer fence correctly. The earlier diagnosis
  ("renders mangled") was wrong — the symptom was slow streaming of a very
  large payload, not a rendering bug; once printing finishes the fences nest
  fine.
- Step 4 Turn B reverted to the **4-backtick outer fence** template (single
  copy-paste block). `--- BEGIN COPY ---` / `--- END COPY ---` sentinels
  removed.
- Added a note to Step 4 acknowledging the streaming cost: handoff payload
  can be very large (full `transcript.md` inlined), so emitting it to chat is
  slow — that's a feature-cost, not a renderer bug.

## Open Questions

- [x] Is a gzipped `.jsonl` (not directly rendered/searchable in the
      GitHub UI) acceptable as the archive format?
  - **Resolved (2026-05-13):** yes — clone + `zcat | grep` is the accepted
    trade-off; the gz blob keeps the repo small and is the true raw
    record.
- [x] At scale (~few thousand sessions ≈ 1 GB), prune older archives down
      to just `log.md` or move raw transcripts to a separate backup repo?
  - **Resolved (2026-05-14):** filed as a separate skill —
    `bd kxa-9nh` (`/kix:prune-sessions`, feature, P3, blocked-by `kxa-bpt`).
    The tracker carries it from here.

## Action Items

- [x] Close PR #43 (standalone-save demo, on the old `docs/conversations/`
      path with the older filenames).
  - **Done (2026-05-13):** PR #43 closed.
- [ ] Close `kxa-bpt` once PR #34 merges.
