---
description: Create a Kix Pitch (optionally seeded from Requests)
argument-hint: [<beads-id>...] [framing instructions]
---

You are creating a new Kix Pitch — a strategic initiative. A Pitch lives as a
[Beads](https://github.com/steveyegge/beads) issue of type `epic`, plus a
long-form `spec.md` file under `.kix/pitches/<bd-id>-<slug>/` that captures the
Shape Up content (problem, appetite, solution, …). A Pitch may be seeded from
one or more existing Requests (beads issues at status `triaging`/ `backlog`),
or captured directly when someone already has a clear idea.

This skill is called during triage **and** ad-hoc capture. **Speed matters.**
Do not refine, reword, or shape the Pitch content. Copy known info into a
`Summary` section and stop. Refinement is a separate, later step.

The user's brief: $ARGUMENTS

## Argument parsing

Parse `$ARGUMENTS` into two parts:

- **Request ids** — zero or more beads issue ids. Accept the full id
  (`kix-jlb`), the suffix only (`jlb`), or hash-prefixed forms (`#kix-jlb`,
  `#jlb`). Strip leading `#`. Resolve each to its canonical id via
  `bd show <id> --json`.
- **Framing** — any remaining free text after removing the id tokens. This is
  the user's description of what the Pitch is about (e.g. `Q2 bug bash`,
  `auth modernization`, `collect into a UX polish bet`, or a fully-formed pitch
  idea with no Requests attached).

Determine the Pitch shape:

- **Solo Pitch** — exactly one Request id and no framing text. The Pitch is
  about that one Request; seed Summary from it directly.
- **Grouped Pitch** — multiple Request ids, or any framing text alongside one
  or more ids. Themed Pitch (bug bash, initiative, batch). Has two variants —
  **framed** (framing + ids) and **unframed** (multiple ids only); see Step 4
  for how each derives the title and Summary.
- **Standalone Pitch** — no Request ids, framing text only. The user already
  has the idea; there is nothing to seed from. The Summary is the framing text
  verbatim. No source Request links.

If `$ARGUMENTS` is empty (no ids and no framing), ask the user for a brief and
wait for their reply before continuing.

## Steps

1. **Resolve and load source Requests** (skip for **Standalone Pitch**).
   - For each id, run `bd show <id> --json` and read the title, description,
     type, and status.
   - If any id resolves to no issue, abort with a clear error naming the
     missing id(s). Do not create a partial Pitch.
   - If any source Request is already type `epic`, or already a child of an
     existing Pitch, warn the user and ask whether to proceed (re-linking) or
     abort. Wait for their reply.

2. **Derive the Pitch's `title`.**
   - **Solo Pitch:** reuse the Request's title as a starting point. Title may
     be lightly cleaned (drop leading "Add a", "Fix the", etc., if it makes a
     better Pitch title) but **do not reword the substance**.
   - **Grouped Pitch (framed) / Standalone Pitch:** derive a title from the
     framing text (a short noun phrase, ≤80 chars, no trailing punctuation). If
     the framing is too thin to title from (e.g. only the word `bugs`), ask the
     user for a Pitch title and wait for their reply.
   - **Grouped Pitch (unframed):** read every source Request's title and
     description, identify the common thread (shared subsystem, repeating
     symptom, overlapping outcome), and write a short noun phrase that names
     that thread (e.g. `Auth flow modernization`, `Triage skill suite`). ≤80
     chars, no trailing punctuation. If the Requests have no plausible common
     thread, ask the user for a Pitch title and wait for their reply rather
     than guessing.

3. **Derive a `slug` from the title.**
   - 2–3 words ideal, 4–5 maximum. Sanitize: lowercase; spaces → `-`; strip
     non-`[a-z0-9-]`; collapse runs of `-`; trim leading/trailing `-`. If empty
     after sanitization, use `untitled`.

4. **Compose the Summary.**
   - **Solo Pitch:** copy the source Request's description verbatim. If the
     description is empty, write `_(source Request had no description.)_`.
   - **Grouped Pitch (framed):** the framing text from `$ARGUMENTS`. Light
     rewording for clarity is fine; do not change the essence and do not add
     anything that wasn't in the input.
   - **Grouped Pitch (unframed):** a short paragraph (1–3 sentences) that names
     the connection between the source Requests — drawn from what the Requests
     themselves say, not invented scope. Bounded synthesis: state the link, do
     not propose solutions.
   - **Standalone Pitch:** the framing text from `$ARGUMENTS`. Light rewording
     for clarity is fine; do not change the essence and do not add anything
     that wasn't in the input.

5. **Create the beads epic.**
   - Run:

     ```bash
     bd create -t epic "<title>" --description "<summary>" --silent
     ```

     `--silent` makes `bd` print only the new issue id; capture it as
     `<pitch-id>`.

6. **Link source Requests to the Pitch** (skip for **Standalone Pitch**).
   - For every source Request id, attach a `discovered-from` edge so the Pitch
     records where it came from:

     ```bash
     bd dep add <pitch-id> <request-id> -t discovered-from
     ```

   - Move each source Request out of `triaging` so it doesn't show up in the
     inbox view anymore — its work has flowed into the Pitch:

     ```bash
     bd update <request-id> --status backlog
     ```

7. **Instantiate the Pitch spec via `envsubst`.**
   - The template at `claude-code/templates/spec.md` is the source of truth for
     the Pitch's long-form shape. **Do not hand-write the spec body.** Run
     `envsubst` against the template with these variables exported:
     - `title` — the title from step 2.
     - `summary` — the Summary from step 4.

     The template's `${...}` placeholders are the only things that get
     substituted; everything else passes through untouched.

   - Run:

     ```bash
     mkdir -p .kix/pitches/<pitch-id>-<slug>
     export title summary
     envsubst '${title} ${summary}' \
       < claude-code/templates/spec.md \
       > .kix/pitches/<pitch-id>-<slug>/spec.md
     ```

     The explicit variable list passed to `envsubst` scopes substitution to the
     placeholders we control — any incidental `$...` in the template stays
     literal.

8. **Confirm.**
   - Print the new beads issue id, the Pitch title, and the path to the new
     `spec.md` file.
   - If source Requests were used, list their ids and note that each was linked
     via `discovered-from` and moved to status `backlog`.
   - For a Standalone Pitch, just state that no source Requests were attached.
