---
name: save-session
description: Archive the current Claude session in a GitHub repo — a log plus the verbatim conversation (transcript file, or a markdown render) — and open (or update) a PR for it. Re-saving the same session overwrites its archive in place.
argument-hint: [--no-commit]
---

# Save Session

Capture the content of the current chat / Claude Code session and commit it to
the surrounding GitHub repository — a `log.md` plus the verbatim conversation
(the transcript file when one exists, otherwise a markdown render) — landing on
the work branch when there is one, or on its own branch + PR otherwise.

Invoked as `/kix:save-session [--no-commit]`. **No repo argument.** When run
from Claude Code, the target is the repo of the current checkout (read
`git remote get-url origin`); chat-session callers can't push from chat, so the
skill switches to **handoff mode** and emits a Claude-Code paste prompt that
lands the archive in whatever repo _that_ CC session points at. Re-running it
on a session that was saved before **updates that archive in place** — same
folder, same branch — instead of creating a duplicate (the session id is the
key).

When run from Claude Code on a feature branch — i.e. the branch that holds the
work this very session did — the archive is committed **straight onto that
branch**, so it rides along with that branch's PR rather than getting its own.
A standalone `claude/save-session-<stem>` branch + PR is created only when
there's no work branch to attach to: you started Claude Code on the default
branch.

**`--no-commit`** (stage-only mode): do everything up to and including
`git add` of the archive files into the current checkout, then **stop** — no
commit, no push, no PR; the caller commits. `kix:commit` uses this so the
archive lands in the same commit as the code. Requires a local checkout.

The skill is meant to run from a Claude Code session (or be handed off to one
from a chat session). It uses the GitHub tools the host exposes (the
`mcp__github__*` names below are the concrete tools when running in Claude Code
— substitute the equivalent the host provides). The verbatim artifact is the
Claude Code transcript `.jsonl`, gzipped to `transcript.jsonl.gz` (in a hosted
sandbox, the largest file in the project dir — the complete cumulative
transcript); a chat session with no transcript renders the conversation in
context to `transcript.md` instead.

---

## Credentials

Tokens are read from the environment (or the plugin's secret storage) —
**never** hard-coded, logged, echoed into commands, or written into a committed
file, the commit message, or the PR body.

- GitHub auth — preferred path is the GitHub MCP server's own credential
  storage; all repo writes go through the `mcp__github__*` tools
  (`create_branch`, `create_or_update_file` / `push_files`,
  `create_pull_request` / `update_pull_request`, plus `search_repositories` /
  `list_*` / `get_file_contents` for inference and re-save lookup). If those
  tools return 401/403, abort with: "Re-authenticate the GitHub MCP server,
  then retry."

**Token fallback (`GITHUB_TOKEN` / `GH_TOKEN`).** Whenever the GitHub MCP path
isn't usable for the target repo — the MCP tools aren't present, **or** the
repo is outside the MCP server's allowlist — fall back to the GitHub REST API
via `curl` with `${GITHUB_TOKEN:-${GH_TOKEN}}` for every subsequent write
(branch, file, PR). All `mcp__github__*` calls below have direct REST
equivalents (e.g. `POST /repos/{o}/{r}/git/refs` for `create_branch`,
`PUT /repos/{o}/{r}/contents/{path}` for `create_or_update_file`,
`POST /repos/{o}/{r}/pulls` for `create_pull_request`). Never invoke the `gh`
CLI. If neither MCP nor a token is available (e.g. running inside a Claude chat
session with no GitHub connector and no token), the skill switches to **handoff
mode** — see Step 4 — and does not attempt to push.

---

## Step 1 — Resolve the target repository

Parse `$ARGUMENTS` for the `--no-commit` flag (the only argument); anything
else is ignored.

1. **From a local checkout (Claude Code, the normal path):** derive
   `owner/repo` from `git remote get-url origin` of the current checkout. No
   user prompt — the repo is the one you're sitting in.
   - `--no-commit` requires a local checkout; if there isn't one, abort:
     "`--no-commit` needs a local git checkout."
2. **Verify reachability** of `owner/repo` — try a cheap read (e.g.
   `mcp__github__get_file_contents` on `/`):
   - **OK** → use the MCP tools for all subsequent writes.
   - **Outside the MCP allowlist** (or no MCP tools at all) but a token is
     available → fall back to the GitHub REST API with
     `${GITHUB_TOKEN:-${GH_TOKEN}}` + `curl` for every subsequent write — see
     the Credentials section.
   - **Neither MCP nor a token reaches it, or there's no checkout at all (chat
     session)** → switch to **handoff mode** in Step 4: produce the archive
     files in chat + a Claude-Code paste prompt the user can run in a CC
     session that _does_ have access. **Do not abort.**

Record the repo's **default branch** — a new branch is cut from it and the PR
targets it.

---

## Step 2 — Capture the session content

**Session id (the Step 3 re-save key).** Use `CLAUDE_CODE_REMOTE_SESSION_ID`
when set — in hosted/cloud sandboxes (`CLAUDE_CODE_REMOTE` truthy) it's the
only id stable across turns (each turn is a fresh `claude --resume` with a new
per-turn id). Otherwise use `CLAUDE_CODE_SESSION_ID`, or whatever the runtime
exposes.

Pick the content source, in order:

1. **Local transcript (preferred).** Look in the Claude Code project dir
   `~/.claude/projects/<project-slug>/` for `*.jsonl` transcripts. Each
   `claude --resume` copies the prior transcript forward and appends, so a
   hosted sandbox leaves many files for one conversation — pick the **largest**
   (= newest, the complete cumulative transcript; _not_ the file named after
   the current per-turn id, which may be an older fork). It's append-only and
   keeps every original turn even after a context compaction, so it's the
   fullest record there is — every turn, tool call, tool result, and system
   block, byte-for-byte. `gzip` it (don't otherwise touch it) and commit the
   result as `transcript.jsonl.gz`: these files are multi-MB raw, ~4–5× smaller
   gzipped, and write-once — a compressed blob in git is fine and keeps the
   repo from ballooning (no Git LFS needed at any realistic volume).
2. **Rendered fallback** — only when there is no transcript file at all (e.g. a
   Claude chat session). Render the conversation already in context to markdown
   in `transcript.md`, **as verbatim as the source allows**: turn order, roles,
   message text, tool calls, tool results, and system content all kept; nothing
   collapsed, truncated, or omitted. If the runtime has already compacted older
   turns, only the surviving in-context view can be rendered — say so in the
   file's header.

If no path yields conversation content, abort with: "Nothing to save — couldn't
read this session's conversation content." Do not create a branch or PR.

### Log

`log.md` is an **append-only running history** of the session — never
regenerated. Build it **from context** (what's in working memory, compacted
older turns included, is plenty; don't re-read the transcript `.jsonl` to
summarize).

**Be specific.** Each update section should record: what was decided this turn,
the alternatives considered and why this option won, and concrete refs (beads
id, PR #, commit SHA, file path). Enough detail that a reader (or a later you)
can reconstruct the reasoning — not just the final state.

**First save** — create `log.md` with this layout. Reconstruct the prior
conversation as a **step-by-step history**, not a final-state condensed
summary: emit **multiple `## <ISO-8601 date> — update` sections** broken by
natural slices (one per calendar date when the session spans days; one per
distinct topic-chunk inside a single day). Same step-by-step shape a series of
re-saves would have produced.

```markdown
---
saved_at: <ISO-8601 timestamp>
session_id: <id>
session_url: <https://claude.ai/chat/<id> for a chat session; omit for Claude Code>
transcript: transcript.jsonl.gz
---

# <Session title — see Step 3>

> **Source:** [Claude session `<short-id>`](<session_url>) — or, for a Claude
> Code session, `~/.claude/projects/<project-slug>/<session-id>.jsonl` (local;
> not a public link).

## Goal

<one short paragraph: what this session set out to do>

## <YYYY-MM-DD> — update

- <step-by-step record of that slice (date or topic): what was decided, the
  alternatives considered, what won and why, refs (beads id / PR # / commit
  SHA / file path)>

## <YYYY-MM-DD> — update

- <next slice>

## Open Questions

- [ ] <question 1>
- [ ] <question 2>

## Action Items

- [ ] <thing to remember to do>
```

(Give `transcript.md` the same frontmatter + `# <title>`; drop the
`transcript:` field when there's no `transcript.jsonl.gz`, i.e. the
rendered-fallback path.)

**Re-save** — do **not** rewrite the file. Read the existing `log.md`, leave
every prior section byte-for-byte, and:

1. **Insert a new `## <ISO-8601 timestamp> — update` section immediately
   _before_ the `## Open Questions` section** (updates stay in time order;
   `## Open Questions` and `## Action Items` remain the trailing pair).
2. **Update `## Open Questions`** as a GitHub-style checklist:
   - When a question gets answered this session, flip its bullet from `- [ ]`
     to `- [x]` and add the answer as a **sub-item** beneath it (don't delete
     the question — keep the trail). The discussion that led to the answer goes
     in the new update section above.
   - New questions surfaced this turn: add as fresh `- [ ]` items.
3. **Update `## Action Items`** the same way — checklist of things to remember
   to do (close a PR, follow up on a beads issue, ship a follow-up change, …):
   - When an action item is done, flip to `- [x]` and add a sub-item with the
     reference (e.g. `bd kxa-xyz`, PR #N, commit SHA) — don't delete the line,
     so the trail stays.
   - If a beads issue is filed for an action item, mark it `- [x]` with the
     beads id as the sub-item; the issue tracker carries it from there.
   - New action items surfaced this turn: add as fresh `- [ ]` items.
4. Refresh only the frontmatter `saved_at`; touch the `# ` heading or `## Goal`
   only if the session's overall aim genuinely changed (the stem/slug never
   changes). The "what's new" boundary is whatever the last update section
   already covered.

If the `caveman` skill is available (the `caveman:caveman` compression mode —
invocable as `/caveman`; check the host's skill list), run it over the
new-since-last-update turns and use its output as the section body; note
`caveman` was used.

---

## Step 3 — Destination, title, paths (with re-save lookup)

1. **Destination mode.** Pick one:
   - `--no-commit` flag → **work-branch save** (caller commits onto the current
     branch).
   - Step 1 #4 ended in outcome (c) (no MCP write access, no token) →
     **handoff** (chat-session output + a CC paste prompt; Step 4 handoff
     branch).
   - Local git checkout of the target repo + current branch ≠ default →
     **work-branch save** (the session is the work behind that branch).
   - Otherwise (default branch, or no checkout but GitHub access exists) →
     **standalone save** (own `claude/save-session-<stem>` branch + PR).
2. **Short id** — strip any prefix like `cse_`, lowercase, keep the first 8
   alphanumerics of the session id.
3. **Existing archive? (re-save check.)** Look for a `docs/sessions/<dir>/`
   whose name ends with `-<short-id>` (or whose `log.md` / `transcript.md`
   frontmatter carries `session_id: <full id>`) — in the **current branch's
   working tree** for a work-branch save, or on the **default branch** (via
   `mcp__github__get_file_contents`) for a standalone save. If found, this is a
   **re-save**: reuse that exact directory **stem** (and, for a standalone
   save, the `claude/save-session-<stem>` branch). Don't rename, don't suffix.
   Skip to step 6.
4. **Title** — a concise summary of the session's main topic, ≤ 70 characters
   (the `# ` heading in `log.md` / `transcript.md`; and the PR title for a
   standalone save). Derive it from what the session accomplished, not the
   first message. (On a re-save the title may be refreshed in the file body;
   the stem stays put.)
5. **Stem & paths** (new archive only) — stem =
   `<YYYY-MM-DD>-<slug>-<short-id>` (slug = lowercased title, non-alphanumerics
   → `-`, trimmed, ≤ ~50 chars; date UTC); if that exact stem is already taken,
   append `-2`, `-3`, … The archive directory is `docs/sessions/<stem>/`,
   holding `log.md` plus `transcript.jsonl.gz` (transcript path) **or**
   `transcript.md` (no-transcript fallback).
6. **Branch.** Work-branch save → the current branch. Standalone save →
   `claude/save-session-<stem>` (stable: a re-save reuses it).

---

## Step 4 — Commit the archive

**Work-branch save.** Write
`docs/sessions/<stem>/{log.md, transcript.jsonl.gz}` into the current checkout
(if the repo runs Prettier with a prose-wrap rule and `docs/sessions/` isn't in
its `.prettierignore`, add that line too), then `git add` those paths.

- **`--no-commit` (stage-only):** **stop here** — do not `git commit`, push, or
  open a PR. Report the staged paths and return to the caller; skip Step 5.
- **Otherwise:** `git commit -m "docs: save session — <title>"` (re-save:
  `docs: update saved session — <title>`), `git push`. If an open PR already
  covers this branch, it picks up the commit — **leave that PR's title and body
  alone** (it's the PR for the actual work; the archive just rides along).
  **You're done — skip Step 5.**

**Standalone save.**

1. **Branch.** Reuse `claude/save-session-<stem>` if it already exists on the
   remote (re-save), else create it from the repo's default branch
   (`mcp__github__create_branch`).
2. **Commit** `docs/sessions/<stem>/…` onto it — message as above — via
   `mcp__github__push_files` / `mcp__github__create_or_update_file` (pass the
   existing blob `sha` when overwriting), or via a local git checkout if
   available (branch from `origin/<default>` / fetch + reset, write the files,
   commit, `git push`). The gzipped transcript is sub-MB; the `transcript.md`
   fallback is small too — the Contents API handles either.
   - If the target repo runs Prettier with a prose-wrap rule and
     `docs/sessions/` isn't in its `.prettierignore`, add that line in the same
     commit (the `transcript.md` fallback would otherwise be reflowed).
3. Proceed to Step 5.

If any call fails, surface the error and stop — do not leave a PR pointing at a
half-written branch.

**Handoff (chat session, no checkout).** Triggered when there's no checkout to
push from (typically a Claude chat session). You can't push, so don't try —
produce the archive as chat output and hand off to a Claude Code session that
_can_ push. **Two turns**, so the user only ever copies one block at the end:

**Turn A — ask for the session URL.** Stop and ask plainly (no
`AskUserQuestion` — there's nothing to disambiguate):

> Before I build the handoff package: open this chat in **claude.ai** in your
> browser and copy a link to it — either the URL from the address bar
> (`https://claude.ai/chat/<uuid>`) or one from the **Share** button. Paste it
> in your next message and I'll bake it into the files and the Claude-Code
> prompt so you only need to copy one block.

Wait for the user's reply with the URL. Either form (address-bar chat URL or
Share-button link) is accepted; record whatever they pasted.

**Turn B — emit a single copy-paste block.** With the URL in hand, render the
final `transcript.md` and `log.md` with the URL substituted into the
frontmatter `session_url:` and the `> Source:` blockquote (no placeholders
left). Then emit **one outer fenced block** (use a 4-backtick fence so the
inner 3-backtick fences survive) the user copies once and pastes into a Claude
Code session checked out at the target repo. Template:

````markdown
I'm handing off a Claude chat session to archive in the current repo (this
checkout). Session URL: <pasted URL>.

Create the per-session folder `docs/sessions/<stem>/` containing the two
files below, then commit + push following
`claude-code/skills/save-session/SKILL.md` Step 3 (work-branch save if on a
feature branch, standalone otherwise) and open/update the PR. Use
`/kix:commit` so the archive rides along with whatever's already in the
index.

File: `docs/sessions/<stem>/transcript.md`
```markdown
<final transcript.md content, URL already inlined>
```

File: `docs/sessions/<stem>/log.md`
```markdown
<final log.md content, URL already inlined>
```
````

Above the block in the chat reply, a single one-liner: "Copy the block below
and paste it into a Claude Code session at `<owner/repo>`." Nothing else above
it — the user shouldn't have to scroll past anything to copy.

Note: the payload can be very large (full `transcript.md` inlined), so
streaming to chat is slow. That's a cost-of-the-feature, not a rendering bug —
claude.ai renders the nested 3-backtick fences inside the 4-backtick outer
fence correctly once printing finishes.

**Don't** create a branch, file, or PR yourself — there's no way to. Skip
Step 5. Report: handoff package emitted; the user pastes it into CC to land the
archive.

---

## Step 5 — Open or update the pull request (standalone save only)

(Work-branch saves stopped at Step 4 — the archive is already on the work
branch and its PR.)

1. If an **open** PR already exists for `claude/save-session-<stem>`
   (`mcp__github__list_pull_requests` / `pull_request_read`), update it
   (`mcp__github__update_pull_request`) — the Step 4 push already added the
   commit; refresh the title/body to the current state.
2. Otherwise (none, or a prior one was merged/closed) open a new PR
   (`mcp__github__create_pull_request`) from `claude/save-session-<stem>` into
   the repo's default branch.

PR fields:

- **Title** — the Step 3 title (the session's main topic, ≤ 70 chars).
- **Body** — one paragraph summarizing the session's outcome (what was decided,
  built, or resolved), then relative links to the archive files:

  ```markdown
  <one-paragraph outcome summary>

  Session log: [`docs/sessions/<stem>/log.md`](docs/sessions/<stem>/log.md)
  Raw transcript: [`docs/sessions/<stem>/transcript.jsonl.gz`](docs/sessions/<stem>/transcript.jsonl.gz)

  ---
  *Generated by Claude Code*
  ```

On the rendered-fallback path, point "Raw transcript" at
`docs/sessions/<stem>/transcript.md` instead.

---

## Step 6 — Report

Print:

- The target `owner/repo` (derived from `git remote get-url origin`).
- **Destination:** `--no-commit` → the staged file paths + "caller will commit
  them"; work-branch save → which branch ("added to PR #N" if one covers it);
  standalone save → the `claude/save-session-<stem>` branch + PR URL; handoff →
  "files emitted in chat + Claude-Code paste prompt; nothing pushed."
- New archive or re-save (which `docs/sessions/<stem>/`).
- Whether the artifact is `transcript.jsonl.gz` (which project transcript —
  filename + size) or the `transcript.md` fallback (and, for `transcript.md`,
  whether older turns were compacted out), and how `log.md` was produced
  (`caveman` or directly).

---

## Error handling summary

| Situation                                                              | Behavior                                                                                                      |
| ---------------------------------------------------------------------- | ------------------------------------------------------------------------------------------------------------- |
| Repo outside MCP allowlist (token available)                           | Fall back to GitHub REST API with `GITHUB_TOKEN` / `GH_TOKEN`.                                                |
| No checkout, or no MCP/GITHUB_TOKEN reach (chat session)               | Switch to **handoff mode** (Step 4): emit `transcript.md` + `log.md` + a CC paste prompt in chat. Don't push. |
| GitHub MCP tools return 401/403 (and no `GITHUB_TOKEN` fallback works) | Abort: instruct the user to re-auth the GitHub MCP server.                                                    |
| Empty session (no conversation content from either path)               | Abort before creating any branch or PR.                                                                       |
| `--no-commit` with no local checkout                                   | Abort: "`--no-commit` needs a local git checkout."                                                            |
| Branch / file / PR creation fails midway                               | Surface the error, stop; do not leave a PR pointing at a half-written branch.                                 |

Never write any token (or other secret) into a committed file, the commit
message, the PR title/body, or terminal output.

```

```
