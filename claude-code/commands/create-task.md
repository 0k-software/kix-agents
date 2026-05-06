---
description: Create a Kix Task (optionally seeded from Requests or under a Pitch)
argument-hint: [--pitch <pitch-id>] [<request-id>...] [framing instructions]
---

You are creating a new Kix Task — a single unit of work. A Task is smaller in
scope than a Pitch (hours to a couple of days), starts in the `backlog` phase,
and may live standalone or under a parent Pitch. A Task may be seeded from one
or more existing Requests, or captured directly when someone already has a
clear unit of work in mind.

This skill is called during triage **and** ad-hoc capture. **Speed matters.**
Do not refine, reword, or shape the Task content. Copy known info into a
`Summary` section and stop. Refinement is a separate, later step.

The user's brief: $ARGUMENTS

## Argument parsing

Parse `$ARGUMENTS` into three parts:

- **Parent Pitch id** (optional) — if `$ARGUMENTS` contains `--pitch <id>` or
  `--pitch=<id>`, extract the integer id and remove the flag from the remaining
  text. The Task will be attached to that Pitch via the `pitch` front-matter
  field. If absent, the Task is standalone (`pitch: null`).
- **Request ids** — zero or more numeric ids. Accept bare numbers (`4`),
  hash-prefixed (`#4`), or paths/links that contain an `<id>-` segment in the
  filename (`.kix/requests/inbox/4-create-task-skill.md`,
  `requests/closed/4-...`). Extract the integer id from each.
- **Framing** — any remaining free text after removing the `--pitch` flag and
  id tokens. This is the user's description of what the Task is about.

Determine the Task shape:

- **Solo Task** — exactly one Request id and no framing text. The Task is about
  that one Request; seed Summary from it directly.
- **Grouped Task** — multiple Request ids, or any framing text alongside one or
  more ids. Themed Task. Has two variants — **framed** (framing + ids) and
  **unframed** (multiple ids only); see Step 2 and Step 5's Summary content for
  how each is handled.
- **Standalone Task** — no Request ids, framing text only. The user already has
  the unit of work; there is nothing to seed from. The Summary is the framing
  text verbatim. The `Sources` section and the `requests:` front-matter list
  are empty.

A `--pitch` flag may accompany any of these shapes — it only affects parent
attachment, not seeding.

If `$ARGUMENTS` is empty (no flag, no ids, no framing), ask the user for a
brief and wait for their reply before continuing.

## Steps

1. **Resolve and load source Requests** (skip for **Standalone Task**).
   - For each id, find the matching file by globbing across outcome subfolders:
     `.kix/requests/*/<id>-*.md` (typically resolves under `inbox/`, but a
     Request being re-linked or pulled from `postponed/` is also valid).
     Exactly one file should match.
   - If any id resolves to zero files, abort with a clear error naming the
     missing id(s). Do not create a partial Task.
   - Read each Request's front-matter and body. You will need its `title`,
     existing `slug` (from filename), current outcome subfolder, and body text.
   - If any Request is already under `.kix/requests/linked/` (i.e. has
     `linked_to` set to an existing Pitch/Task id), warn the user and ask
     whether to proceed (re-linking) or abort. Wait for their reply.

2. **Resolve the parent Pitch** (skip if no `--pitch` flag).
   - Find the Pitch file by globbing: `.kix/pitches/<pitch-id>-*/pitch.md`.
     Exactly one folder should match.
   - If zero folders match, abort with a clear error naming the missing Pitch
     id. Do not create an orphaned Task pointing at a non-existent Pitch.
   - Read the Pitch's `title` for the confirmation message in step 8.

3. **Derive the Task's `title` and `slug`.**
   - **Solo Task:** reuse the Request's title as a starting point. Title may be
     lightly cleaned (drop leading "Add a", "Fix the", etc., if it makes a
     better Task title) but **do not reword the substance**. Slug: reuse the
     Request's slug from filename.
   - **Grouped Task (framed) / Standalone Task:** derive a title from the
     framing text (a short noun phrase, ≤80 chars, no trailing punctuation). If
     the framing is too thin to title from (e.g. only the word `bugs`), ask the
     user for a Task title and wait for their reply.
   - **Grouped Task (unframed):** read every source Request's title and body,
     identify the common thread (shared subsystem, repeating symptom,
     overlapping outcome), and write a short noun phrase that names that
     thread. ≤80 chars, no trailing punctuation. If the Requests have no
     plausible common thread, ask the user for a Task title and wait for their
     reply rather than guessing.
   - **Slug** (all modes except Solo): 2–3 words from the title, sanitized
     (lowercase; spaces → `-`; strip non-`[a-z0-9-]`; collapse runs of `-`;
     trim leading/trailing `-`). If empty after sanitization, use `untitled`.
   - Duplicate slugs are allowed — ID is identity, slug is decoration.

4. **Allocate the next ID.**
   - Read `.kix/.state/next-id`. If the file does not exist or is empty, treat
     the value as `1`.
   - The new Task's ID is the integer you read.
   - You will write `id + 1` back to `.kix/.state/next-id` in step 7.

5. **Capture creator and timestamps.**
   - `created_by`: run `git config user.email`. If empty, leave blank.
   - `created_at` and `updated_at`: the same ISO 8601 UTC timestamp. Use
     `date -u +%Y-%m-%dT%H:%M:%SZ`.

6. **Instantiate the Task template via `envsubst`.**
   - The template at `claude-code/templates/task.md` is the source of truth for
     the Task shape. **Do not hand-write the Task body.** Run `envsubst`
     against the template with these variables exported. The template's
     `${...}` placeholders are the only things that get substituted; everything
     else passes through untouched, regardless of which sections the template
     currently carries.
   - Compute each variable:
     - `id` — the Task id from step 4.
     - `title` — the title from step 3.
     - `pitch_id` — the parent Pitch id from step 2, or the literal string
       `null` if no `--pitch` flag was given.
     - `request_ids` — YAML list literal of source Request ids in the order the
       user provided them, e.g. `[3, 7, 12]`. Solo Task: a single-element list.
       Standalone Task: `[]`.
     - `email` — value from step 5 (blank if `git config user.email` returned
       empty).
     - `now` — the timestamp from step 5.
     - `summary` — the Summary content (see below).
   - **Summary content:**
     - **Solo Task:** copy the source Request's body verbatim. If the body is
       empty, write `_(source Request had no body.)_`.
     - **Grouped Task (framed):** the framing text from `$ARGUMENTS`. Light
       rewording for clarity is fine; do not change the essence and do not add
       anything that wasn't in the input.
     - **Grouped Task (unframed):** a short paragraph (1–3 sentences) that
       names the connection between the source Requests — drawn from what the
       Requests themselves say, not invented scope. Bounded synthesis: state
       the link, do not propose solutions.
     - **Standalone Task:** the framing text from `$ARGUMENTS`. Light rewording
       for clarity is fine; do not change the essence and do not add anything
       that wasn't in the input.

     Source Requests are tracked in the `requests:` front-matter list — that's
     the link; do not copy Request bodies into the Task.

   - Run:

     ```bash
     mkdir -p .kix/tasks/<id>-<slug>
     export id title pitch_id request_ids email now summary
     envsubst '${id} ${title} ${pitch_id} ${request_ids} ${email} ${now} ${summary}' \
       < claude-code/templates/task.md \
       > .kix/tasks/<id>-<slug>/task.md
     ```

     The explicit variable list passed to `envsubst` scopes substitution to the
     placeholders we control — any incidental `$...` in the template stays
     literal.

7. **Link each source Request back to the Task** (skip for **Standalone
   Task**).
   - For every source Request file:
     - Move it into `.kix/requests/linked/` with `git mv` (e.g.
       `git mv .kix/requests/inbox/4-foo.md .kix/requests/linked/`). The
       outcome is encoded by location — there is no `outcome:` field.
       `mkdir -p .kix/requests/linked/` first if needed.
     - Update its front-matter at the new path:
       - `linked_to: <task_id>` (single integer — the Task id)
       - `updated_at: <new timestamp>` (same one captured in step 5)
   - Do not modify the Request's body.

8. **Update the ID counter.**
   - Write `<id + 1>` followed by a single newline to `.kix/.state/next-id`.

9. **Confirm.**
   - Print the path of the new Task file and its title.
   - If a parent Pitch was given, state that the Task is attached to Pitch
     `<pitch-id>: <pitch-title>`.
   - If source Requests were used, list their ids and note that each was moved
     to `.kix/requests/linked/` with `linked_to: <task_id>`. For a Standalone
     Task, just state that no source Requests were attached.
