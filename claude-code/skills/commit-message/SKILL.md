---
name: commit-message
description: Generate a commit message for the current changes and print it — nothing else. Never stages, never commits. Built for headless use (`claude -p "/kix:commit-message"`) so shell scripts, git hooks, and editors (e.g. Obsidian Git) can consume the raw message from stdout.
argument-hint: [reason for the change]
---

Generate a commit message for the current uncommitted changes and print it.

This skill is **read-only**: it never runs `git add`, `git commit`, or any
other command that mutates the repository, the index, or the working tree. If
you want a skill that also commits, use [`/kix:commit`](../commit/SKILL.md) —
it delegates message generation here.

## Output contract

**The entire response is the commit message and nothing else.** This is the
whole point of the skill: the caller pipes stdout straight into
`git commit -F -` or an editor's commit field.

- No preamble ("Here's the commit message:"), no trailing commentary, no
  summary of what you did, no questions.
- No fenced code block, no markdown quoting, no leading/trailing blank lines.
- No `Co-Authored-By` footer and no "Generated with Claude Code" line — you're
  helping write the message, not claiming authorship of the code.
- If there are no uncommitted changes, print nothing at all.

Announce nothing. Explain nothing. Emit the message.

## Argument parsing

The whole of `$ARGUMENTS` is **context text** — the reason/motivation behind
the changes. When non-empty, use it to write the body; it outranks everything
else, since the author knows why they made the change.

## Where the "why" comes from

A diff shows _what_ changed. It cannot show why, which alternative was
rejected, or which constraint forced an odd-looking decision. Those come from
outside the diff, in this order of authority:

1. **`$ARGUMENTS`** — the author said it explicitly. Highest authority.
2. **The current conversation**, when there is one. If this skill was invoked
   from inside a live session (typed as `/kix:commit-message`, or reached via
   [`/kix:commit`](../commit/SKILL.md)), that session's conversation is the
   record of why the work happened: the problem being solved, the approaches
   tried and abandoned, the constraints discovered mid-way, the trade-offs the
   user chose between, and any correction the user made to your first attempt.
   Mine it and put that reasoning in the body — it is the single richest source
   available and it is thrown away the moment the session ends. Prefer it over
   anything you would otherwise infer from reading the code.
3. **The diff itself** — the fallback. Describe intent as best it can be read
   from the change.

Two rules keep this honest:

- **Only what this commit contains.** A session usually covers more than the
  changes being committed — earlier commits, abandoned edits, unrelated
  digressions, tool output. Explain the diff in front of you, not the session.
  If a decision from the conversation isn't visible in this diff, leave it out.
- **Never invent a rationale.** Running headless (`claude -p`) there is no
  prior conversation at all, and that is a normal, expected case. Say what the
  diff supports and stop; a short honest message beats a plausible fabricated
  one.

## Steps

1. Run `git status --porcelain` once to pick the diff source. Each line is
   `XY path`: `X` is the index status, `Y` is the worktree status, `??` marks
   untracked files.
   - **Something staged** (any line whose `X` is neither a space nor `?`):
     describe the staged changes only — `git diff --no-ext-diff --staged`. The
     caller curated the index; the message must match what will be committed.
   - **Nothing staged**: describe everything uncommitted —
     `git diff --no-ext-diff HEAD` for tracked files, plus the untracked files
     from the `??` lines. Read the untracked ones that matter (skip binaries
     and anything obviously generated) so new files are described by content,
     not just by path.
   - **Nothing at all**: print nothing and stop.
2. If the diff is too large to read whole, start from
   `git diff --no-ext-diff --staged --stat` (or `HEAD --stat`) to get the shape
   of the change, then pull the hunks of the files that carry the actual intent
   rather than every file.
3. Determine the message style, in this order:
   - a `Commit message` section in the repo's `AGENTS.md` or `CLAUDE.md`, if
     present — this always wins;
   - otherwise, the repo's own history: `git log -20 --pretty=%s` for subject
     conventions (prefixes, casing, mood) and `git log -3 --pretty=%B` for body
     shape.
   - If the history is empty or gives no clear signal, default to: imperative
     mood, subject ≤ 72 characters with no trailing period, a blank line, then
     a body wrapped at 72 characters.
4. Gather the **why** from the sources ranked in `Where the "why" comes from`
   above — `$ARGUMENTS` first, then the current conversation if this is a live
   session, then the diff.
5. Write the message. The subject says **what changed**; the body says **why**,
   including any decision from step 4 that the diff alone would leave
   unexplained. Skip the body entirely when the subject already says everything
   (small, self-evident changes) — but a non-obvious decision is exactly when a
   body earns its place. Never pad the body by restating the diff file by file.
6. Print it, following the output contract above.

## Headless use

The skill is designed to be driven from a shell:

```bash
claude -p "/kix:commit-message" --output-format text
```

The bundled wrapper — `commit-message.sh` next to this file — does that with
the right tool allowlist and strips any stray fencing:

```bash
"${CLAUDE_PLUGIN_ROOT}/skills/commit-message/commit-message.sh" -C /path/to/repo
```

Run it with `-h` for the full usage, including how to pass context text and how
to pipe the result into `git commit -F -`.
