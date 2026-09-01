---
name: save-session
description: Archive the current Claude session in a GitHub repo as a `log.md` — an append-only running history of what was decided and why. From a checkout it stages the log and stops; `--create-pr` carries it through to a commit, a push, and a PR. Re-saving the same session appends to its log in place.
argument-hint: [--no-commit] [--create-pr]
---

# Save Session

Capture what the current chat / Claude Code session did and write it into the
surrounding GitHub repository as `docs/sessions/<stem>/log.md`. **The log is
the only artifact today**: no transcript file, no raw conversation dump. The
per-session folder stays, so anything a future save wants to keep alongside the
log has a place to go.

Invoked as `/kix:save-session [--no-commit] [--create-pr]`. **No repo
argument.** When run from Claude Code, the target is the repo of the current
checkout (read `git remote get-url origin`); chat-session callers have no
checkout, so the skill either writes through the GitHub API or switches to
**handoff mode** and emits a Claude-Code paste prompt that lands the log in
whatever repo _that_ CC session points at. Re-running it on a session that was
saved before **appends to that log in place** — same folder, same branch —
instead of creating a duplicate (the session id is the key).

**From a local checkout, a save writes and stages the log and stops there.** It
does not commit, push, or open a pull request. The log is left in the index of
whatever branch you're on, for you to fold into your next commit (or for
`/kix:commit` to pick up) and push when you're ready. A session archive is a
by-product of the work, not a reason to interrupt it with git operations you
didn't ask for — and from a live session the branch, the commit boundary, and
the timing are yours to choose.

**`--no-commit`**: pins that default explicitly — write, format, `git add`,
stop. It is what a plain save already does with a checkout; the flag exists
because `/kix:commit` passes it to say out loud that it, not the save, owns the
commit. Requires a local checkout.

**`--create-pr`** (opt-in): carry the save all the way through — commit, push,
and open a pull request for the log. With a local checkout this is the only way
a save touches the remote at all. It's opt-in because a session archive is
rarely something you want in the review queue the moment it's written; without
it there is nothing to undo but a staged file.

The flag gates **creating** a PR. If an open PR already covers the branch the
push lands on, the save **just pushes** and leaves that PR's title and body
alone — the commit shows up there because that's what pushing to a PR's branch
does, and the PR belongs to the work, not to the log. On the paths where the
skill can't create a PR anyway (`--no-commit`, handoff) the flag is a
**no-op**, never an error.

The skill is meant to run from a Claude Code session (or be handed off to one
from a chat session). It uses the GitHub tools the host exposes (the
`mcp__github__*` names below are the concrete tools when running in Claude Code
— substitute the equivalent the host provides).

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

Parse `$ARGUMENTS` for the `--no-commit` and `--create-pr` flags (the only
arguments; they may be combined, in either order); anything else is ignored.

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
     session)** → switch to **handoff mode** in Step 4: produce the log in
     chat + a Claude-Code paste prompt the user can run in a CC session that
     _does_ have access. **Do not abort.**

Record the repo's **default branch** — it decides whether the current branch is
a work branch, and any branch a save cuts is based on it and any PR a save
opens targets it.

---

## Step 2 — Write the log

**Session id (the Step 3 re-save key).** Use `CLAUDE_CODE_REMOTE_SESSION_ID`
when set — in hosted/cloud sandboxes (`CLAUDE_CODE_REMOTE` truthy) it's the
only id stable across turns (each turn is a fresh `claude --resume` with a new
per-turn id). Otherwise use `CLAUDE_CODE_SESSION_ID`, or whatever the runtime
exposes.

The log is an **append-only running history** of the session — never
regenerated. Build it **from context** (what's in working memory, compacted
older turns included, is plenty; never read the session transcript `.jsonl` to
summarize — the log is a distillation, not a dump).

If there's no conversation content in context to distill, abort with: "Nothing
to save — this session has no conversation content to log." Do not create a
branch or PR.

**Be specific.** Each update section should record: what was decided this turn,
the alternatives considered and why this option won, and concrete refs (beads
id, PR #, commit SHA, file path). Enough detail that a reader (or a later you)
can reconstruct the reasoning — not just the final state. The log is the whole
archive, so anything worth keeping has to be in it.

**First save** — create the file with this layout. Reconstruct the prior
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

**Re-save** — do **not** rewrite the file. Read the existing log, leave every
prior section byte-for-byte, and:

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

Older archives may carry a `transcript:` frontmatter field pointing at a
`transcript.jsonl.gz` / `transcript.md` sibling. On a re-save, leave both where
they are — pruning a transcript is a deliberate repo-wide cleanup, not
something a save should do mid-flight. Never add a `transcript:` field to a new
log.

If the `caveman` skill is available (the `caveman:caveman` compression mode —
invocable as `/caveman`; check the host's skill list), run it over the
new-since-last-update turns and use its output as the section body; note
`caveman` was used.

---

## Step 3 — Destination, title, paths (with re-save lookup)

1. **Destination mode.** Pick the first that matches:
   - Local git checkout of the target repo → **local save**. Default (and under
     `--no-commit`): write, format, `git add`, stop. Under `--create-pr`: also
     commit, push, and open a PR.
   - No checkout, but Step 1 #2 found MCP or token write access → **standalone
     save** (own `claude/save-session-<stem>` branch, written and pushed
     through the GitHub API; a PR for it only under `--create-pr`).
   - No checkout and no write access → **handoff** (chat-session output + a CC
     paste prompt; Step 4 handoff branch).
2. **Short id** — strip any prefix like `cse_`, lowercase, keep the first 8
   alphanumerics of the session id.
3. **Existing archive? (re-save check.)** Look for a `docs/sessions/<dir>/`
   whose name ends with `-<short-id>`, or whose `log.md` frontmatter carries
   `session_id: <full id>` — in the **current branch's working tree** for a
   local save, or on the **default branch** (via
   `mcp__github__get_file_contents`) for a standalone save. If found, this is a
   **re-save**: append to that folder's `log.md`, at that exact path (and, for
   a standalone save, reuse the `claude/save-session-<stem>` branch). Don't
   rename, don't move, don't suffix. Skip to step 6.
4. **Title** — a concise summary of the session's main topic, ≤ 70 characters
   (the `# ` heading in the log; and the PR title, when a PR is created).
   Derive it from what the session accomplished, not the first message. (On a
   re-save the title may be refreshed in the file body; the stem stays put.)
5. **Stem & paths** (new archive only) — stem =
   `<YYYY-MM-DD>-<slug>-<short-id>` (slug = lowercased title, non-alphanumerics
   → `-`, trimmed, ≤ ~50 chars; date UTC); if that exact stem is already taken,
   append `-2`, `-3`, … The archive directory is `docs/sessions/<stem>/`,
   holding `log.md` — the only file a save writes today.
6. **Branch.** Local save → the current branch, whatever it is; nothing is
   checked out or created, since a plain save doesn't commit. The one exception
   is `--create-pr` while sitting **on the default branch** — there a save has
   somewhere to push but nowhere sane to push it, so cut
   `claude/save-session-<stem>` from `HEAD` and switch to it before committing.
   Standalone save → `claude/save-session-<stem>` (stable: a re-save reuses
   it).

---

## Step 4 — Land the log

**Local save.** Write the log at the path Step 3 resolved —
`docs/sessions/<stem>/log.md` for a new archive, the existing path on a re-save
— into the current checkout, run the repo's formatter over that path (e.g.
`make autofix`, or `npx prettier --write <path>`), then `git add` it. The log
is ordinary prose markdown: it belongs under the repo's format gate like any
other doc, so don't add an ignore rule for it.

- **Default (and under `--no-commit`):** **stop here** — do not `git commit`,
  push, or open a PR. Report the staged path and return; skip Step 5. The log
  waits in the index for the user's next commit, or for `/kix:commit` to fold
  it in with the code.
- **`--create-pr`:** if Step 3 #6 said to (you're on the default branch),
  create and switch to `claude/save-session-<stem>` first. Then
  `git commit -m "docs: save session — <title>"` (re-save:
  `docs: update saved session — <title>`) and `git push`.
  - If an **open PR already covers the branch you pushed**, you're done —
    **skip Step 5**. It picks up the commit from the push; **leave its title
    and body alone** (it's the PR for the actual work, or an earlier save's;
    the log just rides along).
  - Otherwise proceed to Step 5 to open one.

**Standalone save** (no checkout — everything goes through the GitHub API).

1. **Branch.** Reuse `claude/save-session-<stem>` if it already exists on the
   remote (re-save), else create it from the repo's default branch
   (`mcp__github__create_branch`).
2. **Commit** the Step 3 log path (`docs/sessions/<stem>/log.md` for a new
   archive, the existing path on a re-save) onto it — message as above — via
   `mcp__github__create_or_update_file` / `mcp__github__push_files` (pass the
   existing blob `sha` when overwriting).
   - **Format before the commit**, or the branch lands with a failing format
     gate and nobody in the loop to fix it. Through the Contents API there's no
     formatter to run, so match the target repo's Prettier settings (read
     `.prettierrc*` / the `prettier` key in `package.json`) while rendering the
     log — hard-wrap the prose at its `printWidth` (default 80) when
     `proseWrap` is `always`.
3. If `--create-pr` was passed and no open PR already covers
   `claude/save-session-<stem>`, proceed to Step 5. Otherwise you're done —
   report the pushed branch and skip Step 5.

If any call fails, surface the error and stop — do not leave a PR pointing at a
half-written branch.

**Handoff (chat session, no checkout).** Triggered when there's no checkout to
push from (typically a Claude chat session). You can't push, so don't try —
produce the log as chat output and hand off to a Claude Code session that _can_
push. **Two turns**, so the user only ever copies one block at the end:

**Turn A — ask for the session URL.** Stop and ask plainly (no
`AskUserQuestion` — there's nothing to disambiguate):

> Before I build the handoff package: open this chat in **claude.ai** in your
> browser and copy a link to it — either the URL from the address bar
> (`https://claude.ai/chat/<uuid>`) or one from the **Share** button. Paste it
> in your next message and I'll bake it into the log and the Claude-Code prompt
> so you only need to copy one block.

Wait for the user's reply with the URL. Either form (address-bar chat URL or
Share-button link) is accepted; record whatever they pasted.

**Turn B — emit a single copy-paste block.** With the URL in hand, render the
final log with the URL substituted into the frontmatter `session_url:` and the
`> Source:` blockquote (no placeholders left). Then emit **one outer fenced
block** (use a 4-backtick fence so the inner 3-backtick fence survives) the
user copies once and pastes into a Claude Code session checked out at the
target repo. Template:

````markdown
I'm handing off a Claude chat session to archive in the current repo (this
checkout). Session URL: <pasted URL>.

Create the per-session folder `docs/sessions/<stem>/` with the file below and
add it following `claude-code/skills/save-session/SKILL.md` Step 4 (local
save: write, format, `git add`). Use `/kix:commit` so the log rides along with
whatever's already in the index.

File: `docs/sessions/<stem>/log.md`
```markdown
<final log content, URL already inlined>
```
````

Above the block in the chat reply, a single one-liner: "Copy the block below
and paste it into a Claude Code session at `<owner/repo>`." Nothing else above
it — the user shouldn't have to scroll past anything to copy.

**Don't** create a branch, file, or PR yourself — there's no way to. Skip
Step 5. Report: handoff package emitted; the user pastes it into CC to land the
log.

---

## Step 5 — Open the pull request (`--create-pr` only)

Reached only from Step 4, and only when `--create-pr` was passed **and** no
open PR already covers the pushed branch (if one does, Step 4 stopped there and
left it alone). Everything else — a plain local save, `--no-commit`, handoff —
never gets here.

Open the PR (`mcp__github__create_pull_request`) from the branch Step 4 pushed
into the repo's default branch. Check once more for an open PR on that branch
(`mcp__github__list_pull_requests` / `pull_request_read`) before creating, so a
race or a stale read can't leave two PRs on one branch.

PR fields:

- **Title** — the Step 3 title (the session's main topic, ≤ 70 chars).
- **Body** — one paragraph summarizing the session's outcome (what was decided,
  built, or resolved), then a relative link to the log:

  ```markdown
  <one-paragraph outcome summary>

  Session log: [`docs/sessions/<stem>/log.md`](docs/sessions/<stem>/log.md)

  ---

  _Generated by Claude Code_
  ```

---

## Step 6 — Report

Print:

- The target `owner/repo` (derived from `git remote get-url origin`).
- **Destination:** local save → the staged log path, the branch it's staged on,
  and "not committed — commit and push it when you're ready (or let
  `/kix:commit` fold it in); pass `--create-pr` to have the save do it";
  `--create-pr` → the branch, the commit, and either the new PR URL or "pushed
  into existing PR #N (left untouched)"; standalone save → the
  `claude/save-session-<stem>` branch plus the same PR line; handoff → "log
  emitted in chat + Claude-Code paste prompt; nothing written."
- If `--create-pr` was passed on a path that can't create a PR (`--no-commit`,
  handoff), say it was a no-op.
- New archive or re-save (which `docs/sessions/<stem>/`).
- How the log was produced (`caveman` or directly), and whether older turns
  were compacted out of context when it was written.

---

## Error handling summary

| Situation                                                               | Behavior                                                                                   |
| ----------------------------------------------------------------------- | ------------------------------------------------------------------------------------------ |
| Repo outside MCP allowlist (token available)                            | Fall back to GitHub REST API with `GITHUB_TOKEN` / `GH_TOKEN`.                             |
| No checkout and no MCP/GITHUB_TOKEN reach (chat session)                | Switch to **handoff mode** (Step 4): emit the log + a CC paste prompt in chat. Don't push. |
| GitHub MCP tools return 401/403 (and no `GITHUB_TOKEN` fallback works)  | Abort: instruct the user to re-auth the GitHub MCP server.                                 |
| Empty session (no conversation content in context)                      | Abort before creating any branch or PR.                                                    |
| `--no-commit` with no local checkout                                    | Abort: "`--no-commit` needs a local git checkout."                                         |
| `--create-pr` on a path that can't create a PR (`--no-commit`, handoff) | No-op — never an error. Note it in the Step 6 report.                                      |
| `--create-pr` and an open PR already covers the pushed branch           | Push only; leave that PR's title and body alone. Not an error.                             |
| Branch / file / PR creation fails midway                                | Surface the error, stop; do not leave a PR pointing at a half-written branch.              |

Never write any token (or other secret) into a committed file, the commit
message, the PR title/body, or terminal output.
