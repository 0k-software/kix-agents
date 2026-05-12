---
description: Archive the current Claude conversation as a markdown file in a GitHub repo and open a PR for it (title = session topic, body = outcome summary + link).
argument-hint: [owner/repo]
---

# Save Session

Capture the raw content of the current chat / Claude Code session, commit it as
a markdown file to a target GitHub repository on a new branch, and open a pull
request summarizing the session.

Invoked as `/kix:save-session [owner/repo]`. The repo argument is optional —
when omitted, the skill infers a likely target and asks the user to confirm
before any write.

The skill is designed to run from **either** a Claude chat session or Claude
Code: every step uses the conversation / GitHub tools the host exposes rather
than assuming a shell, a checked-out git repo, or local transcript files. The
`mcp__github__*` names below are the concrete tools when running in Claude Code
— substitute the equivalent GitHub tool the host provides.

---

## Credentials

Both tokens are read from the environment (or the plugin's secret storage) —
**never** hard-coded, logged, echoed into commands, or written into the file,
the commit message, or the PR body.

- `ANTHROPIC_API_KEY` — used to fetch conversation content via the Anthropic
  API. If missing or rejected (401), abort with: "Set `ANTHROPIC_API_KEY` to a
  key with access to this conversation."
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

## Step 2 — Gather the conversation content

This skill runs from Claude chat sessions **and** from Claude Code, so it must
not assume a particular runtime. Get the raw content of the **current session**
with whatever conversation/transcript tool the host exposes:

1. Use the available Claude API / conversation tool to fetch the full message
   history of the current session, authenticating with `ANTHROPIC_API_KEY`. The
   session id comes from the host context — it is not passed as an argument.
2. Render the history to markdown, preserving turn order, roles, and message
   text verbatim (this is a raw archive, not a summary). Tool-call noise may be
   collapsed, but user and assistant prose must be kept intact.
3. **Claude Code fallback only:** if no conversation tool is available but a
   local transcript JSONL exists for this session (e.g. under
   `~/.claude/projects/<slug>/<session-id>.jsonl`), read and render that
   instead, and note in the final report that the local transcript was used.

If no conversation content can be obtained, or it has no user/assistant turns,
abort with: "Nothing to save — couldn't read this session's conversation
content." Do not create a branch or PR.

Prepend a small frontmatter / header block to the rendered markdown:

```markdown
---
saved_at: <ISO-8601 timestamp>
source: <"conversation-api" | "local-transcript">
session_id: <id>
---

# <Session title — see Step 3>
```

---

## Step 3 — Derive the title, slug, and file path

1. **Title** — a concise summary of the session's main topic, ≤ 70 characters,
   suitable as both the PR title and the markdown `# ` heading. Derive it from
   what the session actually accomplished, not the first message.
2. **Slug** — lowercase the title, replace runs of non-alphanumerics with `-`,
   trim leading/trailing `-`, cap at ~50 chars.
3. **File path** — `docs/conversations/<YYYY-MM-DD>-<slug>.md`, where the date
   is today's date (UTC). If that path already exists in the repo, append `-2`,
   `-3`, … to the slug until it's unique.
4. **Branch** — `claude/save-session-<slug>` (same uniqueness suffix as the
   file if needed).

---

## Step 4 — Create the branch and commit the file

1. Create the branch `claude/save-session-<slug>` from the repo's default
   branch (`mcp__github__create_branch`).
2. Commit the rendered markdown at `docs/conversations/<YYYY-MM-DD>-<slug>.md`
   on that branch with the message `docs: save session — <title>`
   (`mcp__github__create_or_update_file` or `push_files`).

If either call fails, surface the error and stop — do not open a PR against a
half-created branch.

---

## Step 5 — Open the pull request

Open a PR from `claude/save-session-<slug>` into the repo's default branch
(`mcp__github__create_pull_request`):

- **Title** — the Step 3 title (the session's main topic, ≤ 70 chars).
- **Body** — one paragraph summarizing the session's outcome (what was decided,
  built, or resolved), followed by a relative link to the new file:

  ```markdown
  <one-paragraph outcome summary>

  Saved conversation: [`docs/conversations/<YYYY-MM-DD>-<slug>.md`](docs/conversations/<YYYY-MM-DD>-<slug>.md)

  ---
  *Generated by Claude Code*
  ```

If the repo argument was **inferred** (Step 1 path 2), the user has already
confirmed the repo — proceed. If anything about the inferred target still feels
ambiguous, re-confirm via `AskUserQuestion` before creating the PR.

---

## Step 6 — Report

Print:

- The target `owner/repo` and whether it was explicit or inferred+confirmed.
- The branch name and file path.
- The PR URL.
- Which content source was used (Anthropic API vs. local transcript).

---

## Error handling summary

| Situation                                                              | Behavior                                                                      |
| ---------------------------------------------------------------------- | ----------------------------------------------------------------------------- |
| No repo arg and no plausible candidate / user declines                 | Abort: ask the user to pass `owner/repo`.                                     |
| Repo not accessible / outside MCP allowlist                            | Abort with a clear message; no writes.                                        |
| `ANTHROPIC_API_KEY` missing or rejected                                | Abort: instruct the user to set the env var.                                  |
| GitHub MCP tools return 401/403 (and no `GITHUB_TOKEN` fallback works) | Abort: instruct the user to re-auth the GitHub MCP server.                    |
| Empty session (no user/assistant turns)                                | Abort before creating any branch or PR.                                       |
| Branch / file / PR creation fails midway                               | Surface the error, stop; do not leave a PR pointing at a half-created branch. |

Never write either token (or any other secret) into the committed file, the
commit message, the PR title/body, or terminal output.
