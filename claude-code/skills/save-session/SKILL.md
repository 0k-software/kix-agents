---
description: Archive the current Claude session in a GitHub repo — raw transcript + summary when a transcript file exists, a verbatim markdown render otherwise — and open a PR for it (title = session topic, body = outcome summary + link).
argument-hint: [owner/repo]
---

# Save Session

Capture the content of the current chat / Claude Code session, commit it to a
target GitHub repository on a new branch — the raw transcript plus a summary
when a transcript file is available, or a verbatim markdown render otherwise —
and open a pull request summarizing the session.

Invoked as `/kix:save-session [owner/repo]`. The repo argument is optional —
when omitted, the skill infers a likely target and asks the user to confirm
before any write.

The skill runs from **either** a Claude chat session or Claude Code. It uses
the GitHub tools the host exposes (the `mcp__github__*` names below are the
concrete tools when running in Claude Code — substitute the equivalent the host
provides) rather than assuming a shell or a checked-out git repo. When a local
transcript file is present (Claude Code) it is committed verbatim as the raw
artifact; otherwise the skill falls back to the conversation available in
context.

---

## Credentials

Tokens are read from the environment (or the plugin's secret storage) —
**never** hard-coded, logged, echoed into commands, or written into a committed
file, the commit message, or the PR body.

- `ANTHROPIC_API_KEY` — used by the rendered-fallback path (Step 2.2) to fetch
  conversation content via the Anthropic API when no local transcript exists.
  If that path is taken and the key is missing or rejected (401), abort with:
  "Set `ANTHROPIC_API_KEY` to a key with access to this conversation."
- GitHub auth — handled by the GitHub MCP server's own credential storage. All
  repo writes go through the `mcp__github__*` tools (`create_branch`,
  `create_or_update_file` / `push_files`, `create_pull_request`, plus
  `search_repositories` / `list_*` for inference). If those tools return
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

Record the repo's **default branch** — the new branch is cut from it and the PR
targets it.

---

## Step 2 — Capture the session content

Pick the source in this order:

1. **Raw transcript (preferred).** If a local Claude Code transcript JSONL
   exists for this session (e.g. under
   `~/.claude/projects/<slug>/<session-id>.jsonl`), use it **as-is** — this is
   the raw artifact: committed byte-for-byte, no edits, no frontmatter, no
   reformatting.
2. **Rendered fallback.** If no transcript JSONL is reachable (e.g. a Claude
   chat session), fall back to the conversation tool the host exposes — the
   Claude API / conversation tool, authenticated with `ANTHROPIC_API_KEY` (the
   session id comes from the host context, not an argument) — or, failing that,
   the conversation already in context. Render it to markdown **verbatim**:
   turn order, roles, and message text preserved; tool calls, tool results, and
   system content all kept; nothing collapsed, truncated, or omitted.

If neither path yields any conversation content (no user/assistant turns),
abort with: "Nothing to save — couldn't read this session's conversation
content." Do not create a branch or PR.

### Summary (only when the raw transcript was used)

When path 2.1 produced a raw JSONL transcript, also generate a human-readable
summary of the conversation:

- **If the `caveman` skill is available** (the `caveman:caveman` compression
  mode — invocable as `/caveman`; check the host's skill list), invoke it and
  write the summary in its compressed format. It strips filler while keeping
  every technical fact, code block, URL, and decision intact. Note in the
  summary itself that `caveman` was used (e.g. a one-line blockquote at the
  top).
- **Otherwise**, write the summary directly: the goal, the key decisions, what
  was built or changed, and any open follow-ups — a few short sections, not a
  blow-by-blow replay.

Prepend this header to the summary markdown (and to the path 2.2 `.raw.md`,
minus `raw_transcript`):

```markdown
---
saved_at: <ISO-8601 timestamp>
session_id: <id>
raw_transcript: <basename of the .jsonl committed alongside, if any>
---

# <Session title — see Step 3>
```

---

## Step 3 — Derive the title, slug, and file paths

1. **Title** — a concise summary of the session's main topic, ≤ 70 characters,
   used as the PR title and the summary's `# ` heading. Derive it from what the
   session actually accomplished, not the first message.
2. **Stem** — lowercase the title, replace runs of non-alphanumerics with `-`,
   trim leading/trailing `-`, cap the slug at ~50 chars, then prefix today's
   date (UTC): `<YYYY-MM-DD>-<slug>`. If any file with that stem already exists
   under `docs/conversations/`, append `-2`, `-3`, … until it is unique.
3. **File paths** under `docs/conversations/`:
   - Raw transcript available → `<stem>.jsonl` (verbatim) **and**
     `<stem>.summary.md`.
   - No raw transcript → `<stem>.raw.md` (the verbatim markdown render).
4. **Branch** — `claude/save-session-<slug>`.

---

## Step 4 — Create the branch and commit the file(s)

1. Create the branch `claude/save-session-<slug>` from the repo's default
   branch (`mcp__github__create_branch`).
2. Commit the Step 3 artifact(s) under `docs/conversations/` on that branch
   with the message `docs: save session — <title>` (`mcp__github__push_files`
   for both files at once, or `mcp__github__create_or_update_file` per file).

If any call fails, surface the error and stop — do not open a PR against a
half-created branch.

---

## Step 5 — Open the pull request

Open a PR from `claude/save-session-<slug>` into the repo's default branch
(`mcp__github__create_pull_request`):

- **Title** — the Step 3 title (the session's main topic, ≤ 70 chars).
- **Body** — one paragraph summarizing the session's outcome (what was decided,
  built, or resolved), then a relative link to the primary artifact (the
  `.summary.md` when it exists, otherwise the `.raw.md`); when a raw transcript
  was committed, also link it:

  ```markdown
  <one-paragraph outcome summary>

  Saved conversation: [`docs/conversations/<stem>.summary.md`](docs/conversations/<stem>.summary.md)
  Raw transcript: [`docs/conversations/<stem>.jsonl`](docs/conversations/<stem>.jsonl)

  ---
  *Generated by Claude Code*
  ```

  When only a `.raw.md` was committed, drop the "Raw transcript" line and point
  "Saved conversation" at the `.raw.md` instead.

If the repo argument was **inferred** (Step 1 path 2), the user has already
confirmed the repo — proceed. If anything about the inferred target still feels
ambiguous, re-confirm via `AskUserQuestion` before creating the PR.

---

## Step 6 — Report

Print:

- The target `owner/repo` and whether it was explicit or inferred+confirmed.
- The branch name and the committed file path(s).
- The PR URL.
- Whether a raw transcript was found (and summarized via `caveman` or directly)
  or the rendered-markdown fallback was used.

---

## Error handling summary

| Situation                                                              | Behavior                                                                      |
| ---------------------------------------------------------------------- | ----------------------------------------------------------------------------- |
| No repo arg and no plausible candidate / user declines                 | Abort: ask the user to pass `owner/repo`.                                     |
| Repo not accessible / outside MCP allowlist                            | Abort with a clear message; no writes.                                        |
| Rendered-fallback path taken and `ANTHROPIC_API_KEY` missing/rejected  | Abort: instruct the user to set the env var.                                  |
| GitHub MCP tools return 401/403 (and no `GITHUB_TOKEN` fallback works) | Abort: instruct the user to re-auth the GitHub MCP server.                    |
| Empty session (no conversation content from either path)               | Abort before creating any branch or PR.                                       |
| Branch / file / PR creation fails midway                               | Surface the error, stop; do not leave a PR pointing at a half-created branch. |

Never write any token (or other secret) into a committed file, the commit
message, the PR title/body, or terminal output.
