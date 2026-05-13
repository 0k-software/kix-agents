---
description: Archive the current Claude session in a GitHub repo — a summary plus the verbatim conversation (raw transcript file, or a markdown render) — and open (or update) a PR for it. Re-saving the same session overwrites its archive in place.
argument-hint: [owner/repo]
---

# Save Session

Capture the content of the current chat / Claude Code session and commit it to
a target GitHub repository — a `summary.md` plus the verbatim conversation (the
raw transcript file when one exists, otherwise a markdown render) — landing on
the work branch when there is one, or on its own branch + PR otherwise.

Invoked as `/kix:save-session [owner/repo]`. The repo argument is optional —
when omitted, the skill infers a likely target and asks the user to confirm
before any write. Re-running it on a session that was saved before **updates
that archive in place** — same folder, same branch — instead of creating a
duplicate (the session id is the key).

When run from Claude Code on a feature branch — i.e. the branch that holds the
work this very session did — the archive is committed **straight onto that
branch**, so it rides along with that branch's PR rather than getting its own.
A standalone `claude/save-session-<stem>` branch + PR is created only when
there's no work branch to attach to: you started Claude Code on the default
branch, or there's no checkout at all (a chat session, where the repo is the
one you confirmed above).

The skill runs from **either** a Claude chat session or Claude Code. It uses
the GitHub tools the host exposes (the `mcp__github__*` names below are the
concrete tools when running in Claude Code — substitute the equivalent the host
provides) rather than assuming a shell or a checked-out git repo. The verbatim
artifact is the Claude Code transcript `.jsonl`, gzipped to `raw.jsonl.gz` (in
a hosted sandbox, the largest file in the project dir — the complete cumulative
transcript); a chat session with no transcript renders the conversation in
context to `raw.md` instead.

---

## Credentials

Tokens are read from the environment (or the plugin's secret storage) —
**never** hard-coded, logged, echoed into commands, or written into a committed
file, the commit message, or the PR body.

- `ANTHROPIC_API_KEY` — used by the rendered-fallback path (Step 2) to fetch
  conversation content via the Anthropic API when no local transcript is used.
  If that path is taken and the key is missing or rejected (401), abort with:
  "Set `ANTHROPIC_API_KEY` to a key with access to this conversation."
- GitHub auth — handled by the GitHub MCP server's own credential storage. All
  repo writes go through the `mcp__github__*` tools (`create_branch`,
  `create_or_update_file` / `push_files`, `create_pull_request` /
  `update_pull_request`, plus `search_repositories` / `list_*` /
  `get_file_contents` for inference and re-save lookup). If those tools return
  401/403, abort with: "Re-authenticate the GitHub MCP server, then retry."

If no GitHub tool is available but a shell is, fall back to the GitHub REST API
via `curl` with `${GITHUB_TOKEN:-${GH_TOKEN}}`. Never invoke the `gh` CLI.

---

## Step 1 — Resolve the target repository

1. **Explicit arg.** If `$ARGUMENTS` (trimmed) is non-empty:
   - If it contains a `/`, parse it as `owner/repo` — that is the target.
   - If it's a bare name, search the repos the GitHub tools can reach for one
     whose name matches case-insensitively (e.g.
     `mcp__github__search_repositories`). Repo names are effectively unique
     across a user's orgs, so a single match is the target. If several match,
     ask the user to pick (`AskUserQuestion`); if none match, abort with: "No
     accessible repo named `{name}` — pass `owner/repo`."
   - Once resolved, skip to Step 2.
2. **Inference.** If no arg was given:
   - Enumerate repositories the GitHub tools can reach (e.g.
     `mcp__github__search_repositories` / `list_*`; respect any allowlist).
   - Rank candidates against the conversation content (repo names, paths, and
     topics mentioned in the session; the current working directory's remote,
     if any).
   - Present the top candidate (and up to 3 runners-up) to the user via
     `AskUserQuestion` and **wait for confirmation**. Do not create a branch,
     file, or PR until the user confirms a repo.
3. If no plausible candidate exists, or the user declines all of them, abort
   with: "Specify the target repo: `/kix:save-session owner/repo`."
4. Verify the chosen repo is reachable (and within the MCP allowlist). If not,
   abort with: "`{owner}/{repo}` is not accessible from this session."

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
   result as `raw.jsonl.gz`: these files are multi-MB raw, ~4–5× smaller
   gzipped, and write-once — a compressed blob in git is fine and keeps the
   repo from ballooning (no Git LFS needed at any realistic volume).
2. **Rendered fallback** — only when there is no transcript file at all (e.g. a
   Claude chat session). Fall back to the conversation tool the host exposes —
   the Claude API / conversation tool, authenticated with `ANTHROPIC_API_KEY` —
   or, failing that, the conversation already in context. Render it to markdown
   in `raw.md`, **as verbatim as the source allows**: turn order, roles,
   message text, tool calls, tool results, and system content all kept; nothing
   collapsed, truncated, or omitted. If the runtime has already compacted older
   turns, only the surviving in-context view can be rendered — state that in
   the file's header.

If no path yields conversation content, abort with: "Nothing to save — couldn't
read this session's conversation content." Do not create a branch or PR.

### Summary

Always generate a human-readable `summary.md` of the conversation — alongside
`raw.jsonl.gz` or `raw.md`, whichever verbatim artifact was committed. Source
it from the conversation **in context** — what's in working memory (the
compacted view of older turns included) is plenty for a summary; do **not**
re-read the transcript `.jsonl` just to summarize (that's the verbatim
artifact's job and wastes tokens).

- **If the `caveman` skill is available** (the `caveman:caveman` compression
  mode — invocable as `/caveman`; check the host's skill list), invoke it and
  write the summary in its compressed format. It strips filler while keeping
  every technical fact, code block, URL, and decision intact. Note in the
  summary itself that `caveman` was used (e.g. a one-line blockquote at the
  top).
- **Otherwise**, write the summary directly: the goal, the key decisions, what
  was built or changed, and any open follow-ups — a few short sections, not a
  blow-by-blow replay.

Prepend this header to `summary.md` and to `raw.md` (drop `raw_transcript` when
there is no `raw.jsonl.gz` — i.e. the rendered-fallback path):

```markdown
---
saved_at: <ISO-8601 timestamp>
session_id: <id>
raw_transcript: raw.jsonl.gz
---

# <Session title — see Step 3>
```

---

## Step 3 — Destination, title, paths (with re-save lookup)

1. **Destination mode.** If the runtime has a **local git checkout** of the
   target repo and the current branch (`git branch --show-current`) is **not**
   the repo's default branch → this is a **work-branch save**: the session is
   the work behind that branch, so the archive is committed onto it. Otherwise
   (on the default branch, or no checkout — a chat session) → a **standalone
   save**: the archive gets its own `claude/save-session-<stem>` branch + PR.
2. **Short id** — strip any prefix like `cse_`, lowercase, keep the first 8
   alphanumerics of the session id.
3. **Existing archive? (re-save check.)** Look for a
   `docs/conversations/<dir>/` whose name ends with `-<short-id>` (or whose
   `summary.md` / `raw.md` frontmatter carries `session_id: <full id>`) — in
   the **current branch's working tree** for a work-branch save, or on the
   **default branch** (via `mcp__github__get_file_contents`) for a standalone
   save. If found, this is a **re-save**: reuse that exact directory **stem**
   (and, for a standalone save, the `claude/save-session-<stem>` branch). Don't
   rename, don't suffix. Skip to step 6.
4. **Title** — a concise summary of the session's main topic, ≤ 70 characters
   (the `# ` heading in `summary.md` / `raw.md`; and the PR title for a
   standalone save). Derive it from what the session accomplished, not the
   first message. (On a re-save the title may be refreshed in the file body;
   the stem stays put.)
5. **Stem & paths** (new archive only) — stem =
   `<YYYY-MM-DD>-<slug>-<short-id>` (slug = lowercased title, non-alphanumerics
   → `-`, trimmed, ≤ ~50 chars; date UTC); if that exact stem is already taken,
   append `-2`, `-3`, … The archive directory is `docs/conversations/<stem>/`,
   holding `summary.md` plus `raw.jsonl.gz` (transcript path) **or** `raw.md`
   (no-transcript fallback).
6. **Branch.** Work-branch save → the current branch. Standalone save →
   `claude/save-session-<stem>` (stable: a re-save reuses it).

---

## Step 4 — Commit the archive

**Work-branch save.** Write
`docs/conversations/<stem>/{summary.md, raw.jsonl.gz}` into the current
checkout, `git add` them, `git commit -m "docs: save session — <title>"`
(re-save: `docs: update saved session — <title>`), `git push`. If an open PR
already covers this branch, it picks up the commit — **leave that PR's title
and body alone** (it's the PR for the actual work; the archive just rides
along). **You're done — skip Step 5.**

**Standalone save.**

1. **Branch.** Reuse `claude/save-session-<stem>` if it already exists on the
   remote (re-save), else create it from the repo's default branch
   (`mcp__github__create_branch`).
2. **Commit** `docs/conversations/<stem>/…` onto it — message as above — via
   `mcp__github__push_files` / `mcp__github__create_or_update_file` (pass the
   existing blob `sha` when overwriting), or via a local git checkout if
   available (branch from `origin/<default>` / fetch + reset, write the files,
   commit, `git push`). The gzipped transcript is sub-MB; the `raw.md` fallback
   is small too — the Contents API handles either.
   - If the target repo runs Prettier with a prose-wrap rule and
     `docs/conversations/` isn't in its `.prettierignore`, add that line in the
     same commit (the `raw.md` fallback would otherwise be reflowed).
3. Proceed to Step 5.

If any call fails, surface the error and stop — do not leave a PR pointing at a
half-written branch.

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

  Conversation Summary: [`docs/conversations/<stem>/summary.md`](docs/conversations/<stem>/summary.md)
  Raw transcript: [`docs/conversations/<stem>/raw.jsonl.gz`](docs/conversations/<stem>/raw.jsonl.gz)

  ---
  *Generated by Claude Code*
  ```

  On the rendered-fallback path, point "Raw transcript" at
  `docs/conversations/<stem>/raw.md` instead.

If the repo argument was **inferred** (Step 1 path 2), the user has already
confirmed the repo — proceed; if anything about the target still feels
ambiguous, re-confirm via `AskUserQuestion` before creating the PR.

---

## Step 6 — Report

Print:

- The target `owner/repo` and whether it was explicit or inferred+confirmed.
- **Destination:** work-branch save (which branch; "added to PR #N" if one
  covers it) or standalone save (the `claude/save-session-<stem>` branch + PR
  URL).
- New archive or re-save (which `docs/conversations/<stem>/`).
- Whether the artifact is `raw.jsonl.gz` (which project transcript — filename +
  size) or the `raw.md` fallback (and, for `raw.md`, whether older turns were
  compacted out), and how `summary.md` was produced (`caveman` or directly).

---

## Error handling summary

| Situation                                                              | Behavior                                                                      |
| ---------------------------------------------------------------------- | ----------------------------------------------------------------------------- |
| No repo arg and no plausible candidate / user declines                 | Abort: ask the user to pass `owner/repo`.                                     |
| Repo not accessible / outside MCP allowlist                            | Abort with a clear message; no writes.                                        |
| Rendered-fallback path taken and `ANTHROPIC_API_KEY` missing/rejected  | Abort: instruct the user to set the env var.                                  |
| GitHub MCP tools return 401/403 (and no `GITHUB_TOKEN` fallback works) | Abort: instruct the user to re-auth the GitHub MCP server.                    |
| Empty session (no conversation content from either path)               | Abort before creating any branch or PR.                                       |
| Branch / file / PR creation fails midway                               | Surface the error, stop; do not leave a PR pointing at a half-written branch. |

Never write any token (or other secret) into a committed file, the commit
message, the PR title/body, or terminal output.
