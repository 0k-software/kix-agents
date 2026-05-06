---
description: Create a Kix Task under a parent Pitch (optionally seeded from Requests)
argument-hint: <pitch-id> [<request-id>...] [framing instructions]
---

You are creating a new Kix Task — a single unit of work. A Task is smaller in
scope than a Pitch (hours to a couple of days), starts in the `backlog` phase,
and **always lives under a parent Pitch** — its file is written at
`.kix/pitches/<pitch-folder>/tasks/<task-folder>/task.md`. A Task may be seeded
from one or more existing Requests, or captured directly when someone already
has a clear unit of work in mind.

This skill is called during triage **and** ad-hoc capture. **Speed matters.**
Do not refine, reword, or shape the Task content. Refinement is a separate,
later step.

The user's brief: $ARGUMENTS

## Argument parsing

Parse `$ARGUMENTS` into three parts:

- **Parent Pitch id** (required) — a bare integer (`7`), hash-prefixed (`#7`),
  or a path/link containing the `<id>-` segment
  (`.kix/pitches/7-foo/pitch.md`). The Pitch id is the **first** integer parsed
  from `$ARGUMENTS`; subsequent integers are Request ids.
- **Request ids** (zero or more) — same formats as above. Each Request id must
  come **after** the Pitch id token in the argument string.
- **Framing** — any remaining free text after removing the Pitch id and Request
  id tokens. This is the user's description of what the Task is about. The
  framing **may** start with an explicit `<kind>:` prefix (`feature:`,
  `chore:`, `bug:`, or `enhancement:`, case-insensitive) to pin the Task kind
  directly; if present, strip the prefix from the framing and remember the kind
  for step 6.

Determine the Task shape:

- **Solo Task** — Pitch id + exactly one Request id, no framing text. The Task
  is about that one Request; seed Summary from it directly.
- **Grouped Task (framed)** — Pitch id + framing + one or more Request ids.
- **Grouped Task (unframed)** — Pitch id + multiple Request ids only.
- **Bare Task** — Pitch id + framing only, no Request ids. The Summary is the
  framing text verbatim. The `requests:` front-matter list is empty.

**No Pitch given.** If `$ARGUMENTS` does not contain a parseable Pitch id, ask
the user which Pitch the Task should live under and wait for their reply.
_TODO: once the project's "urgent / emergency" Pitch convention is decided,
suggest it as the default for incident-style work — currently unresolved, see
review thread on this point._

If `$ARGUMENTS` is entirely empty, ask the user for a brief and wait for their
reply before continuing.

## Steps

1. **Resolve and load source Requests** (skip if no Request ids were given —
   **Bare Task**).
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

2. **Resolve the parent Pitch.**
   - Find the Pitch file by globbing: `.kix/pitches/<pitch-id>-*/pitch.md`.
     Exactly one folder should match. **Capture the folder name** (e.g.
     `14-id-conflicts-teams`) — you'll need it as `<pitch-folder>` when writing
     the Task file in step 7.
   - If zero folders match, abort with a clear error naming the missing Pitch
     id. Do not create an orphaned Task pointing at a non-existent Pitch.
   - Read the Pitch's `title` for the confirmation message in step 10.

3. **Derive the Task's `title` and `slug`.**
   - **Solo Task:** reuse the Request's title as a starting point. Title may be
     lightly cleaned (drop leading "Add a", "Fix the", etc., if it makes a
     better Task title) but **do not reword the substance**. Slug: reuse the
     Request's slug from filename.
   - **Grouped Task (framed) / Bare Task:** derive a title from the framing
     text (a short noun phrase, ≤80 chars, no trailing punctuation). If the
     framing is too thin to title from (e.g. only the word `bugs`), ask the
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
   - You will write `id + 1` back to `.kix/.state/next-id` in step 9.

5. **Capture creator and timestamps.**
   - `created_by`: run `git config user.email`. If empty, leave blank.
   - `created_at` and `updated_at`: the same ISO 8601 UTC timestamp. Use
     `date -u +%Y-%m-%dT%H:%M:%SZ`.

6. **Pick the Task kind.**

   Decide which per-kind template to stamp out. There are four kinds, each with
   its own template under `claude-code/templates/`:
   - `feature` — new functionality, capability, or product surface
     (`task-feature.md`)
   - `chore` — infrastructure, migration, setup, dependency upgrade, or other
     work with little to no product change (`task-chore.md`)
   - `bug` — broken behaviour to fix or investigate (`task-bug.md`)
   - `enhancement` — improvement, polish, refactor, performance, or DevX change
     to existing functionality (`task-enhancement.md`)

   **Explicit kind takes priority over inference.** If the user pinned the kind
   via a `<kind>:` prefix in the framing (captured during argument parsing),
   use that kind directly — do **not** override it with inference, even if the
   rest of the framing seems to suggest a different kind.

   Otherwise, infer the kind from these signals, in order of priority:
   1. **Framing text from `$ARGUMENTS`.** Cues like "fix", "broken",
      "regression", "crash", "doesn't work" → `bug`. Cues like "speed up",
      "improve", "polish", "refactor", "DX", "tighten" → `enhancement`. Cues
      like "add", "build", "introduce", "support", "ship" → `feature`. Cues
      like "migrate", "upgrade dependency", "set up", "infrastructure",
      "tooling" → `chore`.
   2. **The parent Pitch's title and Summary** (loaded in step 2). If the Pitch
      is clearly a feature / bug / enhancement initiative, inherit that kind
      unless the framing text contradicts it.
   3. **The seed Requests' titles and bodies** for Solo and Grouped Tasks.
      Apply the same word-level cues as above.

   If no signal points to a clear kind, fall back to `chore`. Echo the chosen
   kind in the confirmation output (step 10) — and note whether it was set
   explicitly or inferred — so the user can correct it.

7. **Instantiate the Task template via `envsubst`.**
   - The template at `claude-code/templates/task-<kind>.md` (selected from
     step 6) is the source of truth for the Task shape. **Do not hand-write the
     Task body.** Run `envsubst` against the chosen template with these
     variables exported. The template's `${...}` placeholders are the only
     things that get substituted; everything else passes through untouched,
     regardless of which sections the template currently carries.
   - Compute each variable:
     - `id` — the Task id from step 4.
     - `title` — the title from step 3.
     - `pitch_id` — the parent Pitch id from step 2.
     - `requests` — YAML list literal of source Request **id-slug** identifiers
       in the order the user provided them, e.g.
       `[3-create-pitch-skill, 7-creation-through-app]`. Each entry uses the
       Request's `<id>-<slug>` form (the filename without the `.md` extension
       and the outcome subfolder) so the list is readable on its own without
       cross-referencing files. Solo Task: a single-element list. Bare Task:
       `[]`.
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
     - **Bare Task:** the framing text from `$ARGUMENTS`. Light rewording for
       clarity is fine; do not change the essence and do not add anything that
       wasn't in the input.

     Source Requests are tracked in the `requests:` front-matter list — that's
     the link; do not copy Request bodies into the Task.

   - Run:

     ```bash
     mkdir -p .kix/pitches/<pitch-folder>/tasks/<id>-<slug>
     export id title pitch_id requests email now summary
     envsubst '${id} ${title} ${pitch_id} ${requests} ${email} ${now} ${summary}' \
       < claude-code/templates/task-<kind>.md \
       > .kix/pitches/<pitch-folder>/tasks/<id>-<slug>/task.md
     ```

     `<pitch-folder>` is the captured folder name from step 2 (e.g.
     `14-id-conflicts-teams`). `<kind>` is the kind string from step 6
     (`feature`, `chore`, `bug`, or `enhancement`). Each per-kind template
     hard-codes its own `kind:` front-matter value, so `kind` is not an
     envsubst variable — only the template path varies.

     The explicit variable list passed to `envsubst` scopes substitution to the
     placeholders we control — any incidental `$...` in the template stays
     literal.

8. **Link each source Request back to the Task** (skip if no Request ids —
   **Bare Task**).
   - For every source Request file:
     - Move it into `.kix/requests/linked/` with `git mv` (e.g.
       `git mv .kix/requests/inbox/4-foo.md .kix/requests/linked/`). The
       outcome is encoded by location — there is no `outcome:` field.
       `mkdir -p .kix/requests/linked/` first if needed.
     - Update its front-matter at the new path:
       - `linked_to: <task_id>` (single integer — the Task id)
       - `updated_at: <new timestamp>` (same one captured in step 5)
   - Do not modify the Request's body.

9. **Update the ID counter.**
   - Write `<id + 1>` followed by a single newline to `.kix/.state/next-id`.

10. **Confirm.**
    - Print the path of the new Task file (under
      `.kix/pitches/<pitch-folder>/tasks/<id>-<slug>/task.md`) and its title.
    - **State the inferred kind** (`feature`, `chore`, `bug`, or `enhancement`)
      so the user can correct it if the inference was wrong.
    - State that the Task is attached to Pitch `<pitch-id>: <pitch-title>`.
    - If source Requests were used, list their ids and note that each was moved
      to `.kix/requests/linked/` with `linked_to: <task_id>`. For a Bare Task,
      just state that no source Requests were attached.
