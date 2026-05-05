---
description: Implement a Kix Request on a branch and open a PR
argument-hint: <request-id>
---

You are implementing a Kix Request end-to-end: branch, implement, close the
Request, open a PR.

The user's argument: $ARGUMENTS

## Argument parsing

Parse `$ARGUMENTS` for a single **request id** — a bare integer (`18`),
hash-prefixed (`#18`), or a file path containing an `<id>-` segment
(`.kix/requests/inbox/18-foo.md`). Extract the integer id.

If `$ARGUMENTS` is empty or no id can be parsed, ask the user for the request
id and wait for their reply before continuing.

## Steps

### 1. Load the Request

Find the Request file by globbing across all outcome subfolders:

```bash
ls .kix/requests/*/<id>-*.md
```

Exactly one file must match. If zero files match, abort with a clear error.
Read the file's front-matter (`title`, `id`) and body.

### 2. Derive the branch name

- Extract the **slug** from the filename (the part after `<id>-`, before
  `.md`).
- Branch name: `kix/<id>-<slug>`
  (e.g. `kix/18-implement-request-skill`).

### 3. Create and switch to the branch

```bash
git checkout -b kix/<id>-<slug>
```

If the branch already exists, check it out with `git checkout` and warn the
user that work may already exist on this branch.

### 4. Implement the Request

Read the Request body carefully. It is raw input — a bug report, an idea, a
task. Understand what is being asked and implement it directly in the codebase.

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
git mv .kix/requests/<current-subfolder>/<id>-<slug>.md .kix/requests/closed/
```

Then update the `updated_at` field in the moved file to the current UTC
timestamp (`date -u +%Y-%m-%dT%H:%M:%SZ`). Do not change any other
front-matter fields or the body.

Commit this change with a message like:

```
close request #<id>: <title>
```

### 6. Open a pull request

Push the branch and open a PR against the default branch (typically `main`):

```bash
git push -u origin kix/<id>-<slug>
```

Then create the PR using the GitHub MCP tool (`mcp__github__create_pull_request`)
or `gh pr create`. Use:

- **Title:** `implement request #<id>: <title>`
- **Body:** a short summary of what was implemented, followed by a link back to
  the Request:

  ```
  Implements .kix/requests/closed/<id>-<slug>.md
  ```

  This ties the PR to the Kix Request so reviewers can trace implementation
  back to the original ask.

### 7. Confirm

Report:
- The branch name.
- The commits created.
- The PR URL.
- That the Request was moved to `closed/`.
