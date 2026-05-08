---
description: Create a Kix Pitch (optionally seeded from Requests)
argument-hint: [<request-id>...] [framing instructions]
---

You are creating a new Kix Pitch — a strategic initiative. A Pitch is
multi-task scope (days to weeks), shows up on the roadmap, and starts in the
`ideas` phase. A Pitch may be seeded from one or more existing Requests, or
captured directly when someone already has a clear idea.

This skill is called during triage **and** ad-hoc capture. **Speed matters.**
Do not refine, reword, or shape the Pitch content. Copy known info into a
`Summary` section and stop. Refinement is a separate, later step.

The user's brief: $ARGUMENTS

## Argument parsing

Parse `$ARGUMENTS` into two parts:

- **Request ids** — zero or more numeric ids. Accept bare numbers (`4`),
  hash-prefixed (`#4`), or paths/links that contain an `<id>-` segment in the
  filename (`.kix/requests/inbox/4-create-pitch-skill.md`,
  `requests/closed/4-...`). Extract the integer id from each.
- **Framing** — any remaining free text after removing the id tokens. This is
  the user's description of what the Pitch is about (e.g. `Q2 bug bash`,
  `auth modernization`, `collect into a UX polish bet`, or a fully-formed pitch
  idea with no Requests attached).

Determine the Pitch shape:

- **Solo Pitch** — exactly one Request id and no framing text. The Pitch is
  about that one Request; seed Summary from it directly.
- **Grouped Pitch** — multiple Request ids, or any framing text alongside one
  or more ids. Themed Pitch (bug bash, initiative, batch). Has two variants —
  **framed** (framing + ids) and **unframed** (multiple ids only); see Step 2
  and Step 5's Summary content for how each is handled.
- **Standalone Pitch** — no Request ids, framing text only. The user already
  has the idea; there is nothing to seed from. The Summary is the framing text
  verbatim. The `Sources` section and the `requests:` front-matter list are
  empty.

If `$ARGUMENTS` is empty (no ids and no framing), ask the user for a brief and
wait for their reply before continuing.

## Steps

1. **Resolve and load source Requests** (skip for **Standalone Pitch**).
   - For each id, find the matching file by globbing across outcome subfolders:
     `.kix/requests/*/<id>-*.md` (typically resolves under `inbox/`, but a
     Request being re-linked or pulled from `postponed/` is also valid).
     Exactly one file should match.
   - If any id resolves to zero files, abort with a clear error naming the
     missing id(s). Do not create a partial Pitch.
   - Read each Request's front-matter and body. You will need its title (the H1
     at the top of the body — there is no `title:` front-matter field),
     existing `slug` (from filename), current outcome subfolder, and body text
     after the H1.
   - If any Request is already under `.kix/requests/linked/` (i.e. has
     `linked_to` set to an existing Pitch/Task id), warn the user and ask
     whether to proceed (re-linking) or abort. Wait for their reply.

2. **Derive the Pitch's `title` and `slug`.**
   - **Solo Pitch:** reuse the Request's title as a starting point. Title may
     be lightly cleaned (drop leading "Add a", "Fix the", etc., if it makes a
     better Pitch title) but **do not reword the substance**. Slug: reuse the
     Request's slug from filename.
   - **Grouped Pitch (framed) / Standalone Pitch:** derive a title from the
     framing text (a short noun phrase, ≤80 chars, no trailing punctuation). If
     the framing is too thin to title from (e.g. only the word `bugs`), ask the
     user for a Pitch title and wait for their reply.
   - **Grouped Pitch (unframed):** read every source Request's title and body,
     identify the common thread (shared subsystem, repeating symptom,
     overlapping outcome), and write a short noun phrase that names that thread
     (e.g. `Auth flow modernization`, `Triage skill suite`). ≤80 chars, no
     trailing punctuation. If the Requests have no plausible common thread, ask
     the user for a Pitch title and wait for their reply rather than guessing.
   - **Slug** (all modes except Solo): 2–3 words from the title, sanitized
     (lowercase; spaces → `-`; strip non-`[a-z0-9-]`; collapse runs of `-`;
     trim leading/trailing `-`). If empty after sanitization, use `untitled`.
   - Duplicate slugs are allowed — ID is identity, slug is decoration.

3. **Allocate the next ID.**
   - Read `.kix/.state/next-id`. If the file does not exist or is empty, treat
     the value as `1`.
   - The new Pitch's ID is the integer you read.
   - You will write `id + 1` back to `.kix/.state/next-id` in step 7.

4. **Capture creator and timestamps.**
   - `created_by`: run `git config user.email`. If empty, leave blank.
   - `created_at` and `updated_at`: the same ISO 8601 UTC timestamp. Use
     `date -u +%Y-%m-%dT%H:%M:%SZ`.

5. **Instantiate the Pitch template via `envsubst`.**
   - The template at `agents/claude-code/templates/pitch.md` is the source of
     truth for the Pitch shape. **Do not hand-write the Pitch body.** Run
     `envsubst` against the template with these variables exported. The
     template's `${...}` placeholders are the only things that get substituted;
     everything else passes through untouched, regardless of which sections the
     template currently carries.
   - Compute each variable:
     - `id` — the Pitch id from step 3.
     - `title` — the title from step 2.
     - `requests` — YAML list literal of source Request **id-slug** identifiers
       in the order the user provided them, e.g.
       `[3-create-pitch-skill, 7-creation-through-app]`. Each entry uses the
       Request's `<id>-<slug>` form (the filename without the `.md` extension
       and the outcome subfolder) so the list is readable on its own without
       cross-referencing files. Solo Pitch: a single-element list. Standalone
       Pitch: `[]`.
     - `email` — value from step 4 (blank if `git config user.email` returned
       empty).
     - `now` — the timestamp from step 4.
     - `summary` — the Summary content (see below).
   - **Summary content:**
     - **Solo Pitch:** copy the source Request's body verbatim. If the body is
       empty, write `_(source Request had no body.)_`.
     - **Grouped Pitch (framed):** the framing text from `$ARGUMENTS`. Light
       rewording for clarity is fine; do not change the essence and do not add
       anything that wasn't in the input.
     - **Grouped Pitch (unframed):** a short paragraph (1–3 sentences) that
       names the connection between the source Requests — drawn from what the
       Requests themselves say, not invented scope. Bounded synthesis: state
       the link, do not propose solutions.
     - **Standalone Pitch:** the framing text from `$ARGUMENTS`. Light
       rewording for clarity is fine; do not change the essence and do not add
       anything that wasn't in the input.

     Source Requests are tracked in the `requests:` front-matter list — that's
     the link; do not copy Request bodies into the Pitch.

   - Run:

     ```bash
     mkdir -p .kix/pitches/<id>-<slug>
     export id title requests email now summary
     envsubst '${id} ${title} ${requests} ${email} ${now} ${summary}' \
       < agents/claude-code/templates/pitch.md \
       > .kix/pitches/<id>-<slug>/pitch.md
     ```

     The explicit variable list passed to `envsubst` scopes substitution to the
     placeholders we control — any incidental `$...` in the template stays
     literal.

6. **Link each source Request back to the Pitch** (skip for **Standalone
   Pitch**).
   - For every source Request file:
     - Move it into `.kix/requests/linked/` with `git mv` (e.g.
       `git mv .kix/requests/inbox/4-foo.md .kix/requests/linked/`). The
       outcome is encoded by location — there is no `outcome:` field.
       `mkdir -p .kix/requests/linked/` first if needed.
     - Update its front-matter at the new path:
       - `linked_to: <pitch_id>` (single integer — the Pitch id)
       - `updated_at: <new timestamp>` (same one captured in step 4)
   - Do not modify the Request's body.

7. **Update the ID counter.**
   - Write `<id + 1>` followed by a single newline to `.kix/.state/next-id`.

8. **Confirm.**
   - Print the path of the new Pitch file and its title. If source Requests
     were used, list their ids and note that each was moved to
     `.kix/requests/linked/` with `linked_to: <pitch_id>`. For a Standalone
     Pitch, just state that no source Requests were attached.
