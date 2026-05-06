---
description: Implement a Kix Request on a branch and open a PR
argument-hint: <request-id> [extra context]
---

You are implementing a Kix Request end-to-end: branch, implement, close the
Request, open a PR.

The user's argument: $ARGUMENTS

## Argument parsing

Parse `$ARGUMENTS` for a single **request id** — a bare integer (`18`),
hash-prefixed (`#18`), or a file path containing an `<id>-` segment
(`.kix/requests/inbox/18-foo.md`). Extract the integer id.

Any remaining text after the id is **supplemental context** — extra framing,
constraints, or instructions from the user that should guide the implementation
(e.g. `18 keep it minimal` or `#18 also update the README`). Carry this context
into Step 4 and let it shape the work.

If `$ARGUMENTS` is empty or no id can be parsed, ask the user for the request
id and wait for their reply before continuing.

## Steps

### 1. Load the Request

Find the Request file by globbing across all outcome subfolders:

```bash
ls .kix/requests/*/<id>-*.md
```

Exactly one file must match. If zero files match, abort with a clear error.
Read the file's front-matter (`id`) and body. The Request's title is the H1 at
the top of the body (the first `# ...` line after the front-matter), not a
front-matter field.

### 2. Derive the branch name

Strip `.md` from the Request filename and prefix with `kix/`:

```
kix/<filename-without-extension>
```

For example, `18-implement-request-skill.md` →
`kix/18-implement-request-skill`.

### 3. Create and switch to the branch

```bash
git checkout -b kix/<filename-without-extension>
```

If the branch already exists, check it out with `git checkout` and warn the
user that work may already exist on this branch.

> **Note:** A future improvement is to use `git worktree add` here instead of
> checking out in the current directory, so the implementation runs in an
> isolated worktree and leaves the working tree clean.

### 4. Implement the Request

Read the Request body carefully, and factor in any supplemental context from
`$ARGUMENTS`. The Request is raw input — a bug report, an idea, a task.
Understand what is being asked and implement it directly in the codebase.

**Commit discipline:**

- Split the work into logical commits so the PR is easy to review.
- Each commit should represent one coherent change (e.g. "add the skill file",
  "register skill in plugin manifest", "add docs entry").
- Use the `kix:commit` skill (or equivalent git commit flow) for each commit,
  or commit directly with a clear message.
- Do not batch everything into a single commit unless the change is truly
  atomic.

There is no pitch or plan required. Implement from the Request description
directly.

### 5. Close the Request

Once the implementation is complete, move the Request file to the `closed/`
subfolder and update its `updated_at` timestamp:

```bash
mkdir -p .kix/requests/closed
git mv .kix/requests/<current-subfolder>/<filename> .kix/requests/closed/
```

Update the `updated_at` field in the moved file to the current UTC timestamp
(`date -u +%Y-%m-%dT%H:%M:%SZ`).

Then append a `## Resolution` section to the end of the file body:

```markdown
## Resolution

Implemented on branch `kix/<filename-without-extension>`. <one-sentence summary
of what was done.> PR: <pr-url> (or "PR pending" if not yet opened).
```

If you know the commit SHAs at this point, list them; otherwise the PR link
alone is sufficient. Update this section after opening the PR if the URL wasn't
available yet.

Commit this change with a message like:

```
close request #<id>: <title>
```

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

### 7. Open a pull request

Push the branch and open a PR against the default branch (typically `main`):

```bash
git push -u origin kix/<filename-without-extension>
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
       "title": "implement request #<id>: <title>",
       "head": "kix/<filename-without-extension>",
       "base": "main",
       "body": "<body>"
     }'
   ```

   Determine `<owner>/<repo>` from `git remote get-url origin`.

If none of these methods succeed, report the failure clearly and ask the user
to open the PR manually.

**PR content:**

- **Title:** `implement request #<id>: <title>`
- **Body:** a short summary of what was implemented, followed by a link back to
  the Request:

  ```
  Implements .kix/requests/closed/<filename>
  ```

  This ties the PR to the Kix Request so reviewers can trace implementation
  back to the original ask.

Once the PR URL is known, go back and fill it into the `## Resolution` section
of the closed Request file (if you wrote "PR pending" earlier) and amend or add
a follow-up commit.

### 8. Confirm

Report:

- The branch name.
- The commits created.
- The PR URL.
- That the Request was moved to `closed/` and the Resolution section was added.
- Whether the changelog was updated.
