---
description: Implement a Kix Request on a branch and open a PR
argument-hint: <beads-id> [extra context]
---

You are implementing a Kix Request end-to-end: branch, implement, close the
beads issue, open a PR.

The user's argument: $ARGUMENTS

## Argument parsing

Parse `$ARGUMENTS` for a single **beads issue id**. Accept any of:

- the full id (`kix-jlb`)
- the suffix only (`jlb`) — the skill prepends the prefix using
  `bd config get prefix` (or just tries `kix-<suffix>`)
- a hash-prefixed form (`#kix-jlb`, `#jlb`)

Strip the leading `#` if present. Resolve to the canonical full id with
`bd show <id> --json`.

Any remaining text after the id is **supplemental context** — extra framing,
constraints, or instructions from the user that should guide the implementation
(e.g. `kix-jlb keep it minimal` or `#kix-jlb also update the README`). Carry
this context into Step 4 and let it shape the work.

If `$ARGUMENTS` is empty or no id can be parsed, ask the user for the issue id
and wait for their reply before continuing.

## Steps

### 1. Load the issue

```bash
bd show <id> --json
```

Read the title, description, type, and status. If the issue does not exist,
abort with a clear error.

### 2. Derive the branch name

Compute a slug from the title (2–3 words, lowercase, `[a-z0-9-]` only, collapse
runs of `-`, trim). The branch is:

```
kix/<bd-id>-<slug>
```

For example, `kix-jlb` with title "Replace Kix file-based task storage with
beads" → `kix/kix-jlb-replace-storage-with-beads`. If the slug is empty after
sanitization, use the id alone (`kix/kix-jlb`).

### 3. Create and switch to the branch

```bash
git checkout -b kix/<bd-id>-<slug>
```

If the branch already exists, check it out with `git checkout` and warn the
user that work may already exist on this branch.

> **Note:** A future improvement is to use `git worktree add` here instead of
> checking out in the current directory, so the implementation runs in an
> isolated worktree and leaves the working tree clean.

### 4. Move the issue into `doing`

```bash
bd update <id> --status doing
```

This signals that work has started. Status hops are fine — Kix's phase rail
doesn't require passing through `refining`/`planning` for a direct Request
implementation.

### 5. Implement

Read the issue title and description carefully, and factor in any supplemental
context from `$ARGUMENTS`. The Request is raw input — a bug report, an idea, a
task. Understand what is being asked and implement it directly in the codebase.

**Commit discipline:**

- Split the work into logical commits so the PR is easy to review.
- Each commit should represent one coherent change (e.g. "add the skill file",
  "register skill in plugin manifest", "add docs entry").
- Use the `kix:commit` skill (or equivalent git commit flow) for each commit,
  or commit directly with a clear message.
- Do not batch everything into a single commit unless the change is truly
  atomic.

There is no pitch or plan required. Implement from the issue description
directly.

### 6. Update the changelog (if present)

Check whether the repo has a changelog file at the root:

```bash
ls CHANGELOG.md 2>/dev/null || ls changelog.md 2>/dev/null
```

If a changelog file exists, prepend a new entry for this change under the
appropriate `## [Unreleased]` section (or create one if absent), following the
[Keep a Changelog](https://keepachangelog.com) format. Summarise what was
added, changed, or fixed — one bullet per logical change. Commit the update
together with or immediately after the implementation commits.

If no changelog file exists, skip this step silently.

### 7. Close the beads issue

Once the implementation is on the branch, close the issue:

```bash
bd close <id>
```

Then attach a resolution comment that records the branch, a one-sentence
summary of what was done, and the PR URL (or `pending` if not yet opened):

```bash
bd comment <id> "Implemented on branch kix/<bd-id>-<slug>. <summary>. PR: <pr-url>"
```

If you know the commit SHAs at this point, list them; otherwise the PR link
alone is sufficient. Update the comment (or add another) after opening the PR
if the URL wasn't available yet.

### 8. Open a pull request

Push the branch and open a PR against the default branch (typically `main`):

```bash
git push -u origin kix/<bd-id>-<slug>
```

Then create the PR using one of the following methods, tried in order:

1. **GitHub MCP tool** — `mcp__github__create_pull_request` if available.
2. **`gh` CLI** — `gh pr create` if the `gh` binary is present.
3. **curl fallback** — if neither is available but `GITHUB_TOKEN` or `GH_TOKEN`
   is set in the environment, create the PR via the GitHub REST API:

   ```bash
   curl -s -X POST \
     -H "Authorization: token ${GITHUB_TOKEN:-$GH_TOKEN}" \
     -H "Accept: application/vnd.github+json" \
     https://api.github.com/repos/<owner>/<repo>/pulls \
     -d '{
       "title": "implement <bd-id>: <title>",
       "head": "kix/<bd-id>-<slug>",
       "base": "main",
       "body": "<body>"
     }'
   ```

   Determine `<owner>/<repo>` from `git remote get-url origin`.

If none of these methods succeed, report the failure clearly and ask the user
to open the PR manually.

**PR content:**

- **Title:** `implement <bd-id>: <title>`
- **Body:** a short summary of what was implemented, followed by a link back to
  the beads issue:

  ```
  Implements beads issue <bd-id>.
  ```

  This ties the PR to the Kix Request so reviewers can trace implementation
  back to the original ask.

Once the PR URL is known, post a follow-up `bd comment <id> "PR: <pr-url>"` (or
amend the resolution comment) so the issue carries the PR link.

### 9. Confirm

Report:

- The beads issue id and title.
- The branch name.
- The commits created.
- The PR URL.
- That the beads issue was closed and a resolution comment was added.
- Whether the changelog was updated.
