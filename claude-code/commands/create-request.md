---
description: Capture a new Kix Request as a beads issue
argument-hint: [brief description of what to capture]
---

You are creating a new Kix Request — raw input captured friction-free in the
project's inbox. A Request is a bug report, an idea, a refactor, an unknown
problem; whatever someone wanted to capture without committing to a shape. It
lives as a [Beads](https://github.com/steveyegge/beads) issue of type `task` at
status `triaging`. Triage later flips its type (to `feature`/`bug`/`chore`/
`decision` for a Task, or `epic` for a Pitch) or its status (to `backlog`,
`closed`).

The user's brief: $ARGUMENTS

## Steps

1. **If the brief is empty**, ask the user for one and wait for their reply
   before continuing.

2. **Derive a `title` and `body` from the brief.**
   - **title**: a short noun phrase, ≤80 chars, no trailing punctuation. It
     should describe what the Request is about, not the user's first phrasing.
   - **body**: the rest of the brief as a short description, edited for
     clarity. Keep it brief — Requests are rough input, not specs. Do not
     invent facts the user did not state. If the brief contained nothing beyond
     a one-line title, leave the body empty.

3. **Create the beads issue.**
   - Run:

     ```bash
     bd create "<title>" --description "<body>" --silent
     ```

     `--silent` makes `bd` print only the new issue id (e.g. `kix-jlb`).
     Capture that id.

     If `body` is empty, omit the `--description` flag.

   - Set the status to `triaging` (the Kix default for fresh captures;
     `bd create` defaults to `open`):

     ```bash
     bd update <id> --status triaging
     ```

4. **Confirm — and warn if the body is vague.**
   - Print the new issue id, title, and status so the user can see what was
     captured. `bd show <id>` is a good way to render this.
   - **Vagueness check:** if the body is empty, a single short noun phrase, or
     otherwise gives a future triager no hint of the area touched, the desired
     outcome, or the motivation, also print a brief warning. The Request was
     still created — the warning is a nudge, not a rejection. Request creation
     stays friction-free.
     - Vague (warn): `create-pitch skill`, `fix the thing`, `auth bug`.
     - Useful (no warning):
       `Add a create-pitch skill that creates a Pitch from one or more existing Requests.`,
       `Login form crashes when the email contains a +`.
     - The warning should suggest adding a sentence about the area touched, the
       desired outcome, or the motivation, so future triagers can grasp what
       the Request is about without re-deriving it from scratch.
