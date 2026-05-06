---
description: Capture a new Kix Request in .kix/requests/
argument-hint: [brief description of what to capture]
---

You are creating a new Kix Request — raw input captured friction-free in the
project's inbox. A Request is a bug report, an idea, a refactor, an unknown
problem; whatever someone wanted to capture without committing to a shape. It
lives as a Markdown file under `.kix/requests/inbox/` and stays under
`.kix/requests/` permanently — triage moves it to a sibling outcome subfolder
(`postponed/`, `linked/`, or `closed/`), but the file is never deleted.

The user's brief: $ARGUMENTS

## Steps

1. **If the brief is empty**, ask the user for one and wait for their reply
   before continuing.

2. **Derive a `title` and `body` from the brief.**
   - **title**: a short noun phrase, ≤80 chars, no trailing punctuation. It
     should describe what the Request is about, not the user's first phrasing.
   - **body**: the rest of the brief as a short description, edited for
     clarity. Keep it brief — Requests are rough input, not specs. Do not
     invent facts the user did not state.

3. **Derive a `slug` from the title.**
   - 2–3 words ideal, 4–5 maximum.
   - Pick words that evoke what the Request is about and which area it touches
     (e.g. `billing-webhook`, `auth-login-flow`, `flaky-tests-ci`). Drop filler
     like "the", "a", "fix", "issue".
   - Sanitize: lowercase; spaces → `-`; strip non-`[a-z0-9-]`; collapse runs of
     `-`; trim leading/trailing `-`. If empty after sanitization, use
     `untitled`.
   - Duplicate slugs are allowed — ID is identity, slug is decoration.

4. **Allocate the next ID.**
   - Read `.kix/.state/next-id`. If the file does not exist or is empty, treat
     the value as `1`.
   - The new Request's ID is the integer you read.
   - You will write `id + 1` back to `.kix/.state/next-id` in step 7.

5. **Capture the creator and timestamps.**
   - `created_by`: run `git config user.email`. If that returns empty, leave
     the field blank.
   - `created_at` and `updated_at`: the same ISO 8601 UTC timestamp (e.g.
     `2026-05-05T14:32:00Z`). Use `date -u +%Y-%m-%dT%H:%M:%SZ`.

6. **Write the Request file.**
   - Path: `.kix/requests/inbox/<id>-<slug>.md`. Create `.kix/requests/inbox/`
     if it does not exist.
   - Outcome is encoded by location, not by front-matter: new Requests land in
     `inbox/`; triage later moves the file into `postponed/`, `linked/`, or
     `closed/`. Do not write an `outcome:` field.
   - Front-matter:
     ```yaml
     ---
     id: <id>
     linked_to: null
     created_by: <created_by>
     created_at: <timestamp>
     updated_at: <timestamp>
     ---
     ```
   - Body: an H1 carrying the title (`# <title>`), a blank line, then the
     description you derived in step 2. The H1 is the canonical title — there
     is no `title:` front-matter field. If the brief contained nothing beyond a
     one-line title, the H1 alone is the body.

7. **Update the ID counter.**
   - Write `<id + 1>` followed by a single newline to `.kix/.state/next-id`.

8. **Confirm — and warn if the body is vague.**
   - Print the path of the new Request file and its title so the user can see
     what was captured.
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
