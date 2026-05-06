---
id: 4
type: request
linked_to: null
created_by: kelvin.stinghen@me.com
created_at: 2026-05-05T12:52:37Z
updated_at: 2026-05-05T15:08:56Z
---

# `create-pitch` skill

Add a `create-pitch` skill that creates a Pitch from one or more existing
Requests. Input: a Request id/link, multiple Request ids/links, or Request
ids/links plus framing instructions about what the Pitch is about (e.g. a
bug-bashing batch).

- **Single Request, no extra framing** — infer the Pitch is about that one
  Request. Seed the Summary from it directly.
- **Multiple Requests, or any framing instructions alongside the id(s)** —
  treat it as a grouped Pitch (e.g. a bug bash, a theme). The Summary should
  reflect the group/theme, with each source Request copied in.

Pitches need a template (default format) — create that too as part of this
work. When the skill runs, it instantiates the template, references the source
Request(s) (via `linked_to` or equivalent — supporting multiple links), and
copies the known info into a **Summary** section at the top of the Pitch.

**Do not refine or shape the Pitch during creation** — no AI or human time
spent rewording. Refinement is a separate, later step. This skill is called
during triage, and triage must be fast.

## Resolution

Shipped in:

- [4537db3](https://github.com/0k-software/kix/commit/4537db3) — feat: harden
  `/commit` skill failure path and refine Request 4
- [4fd3ad7](https://github.com/0k-software/kix/commit/4fd3ad7) — chore: expand
  Request 4 to cover grouped Pitches
- [e675658](https://github.com/0k-software/kix/commit/e675658) — feat: add
  `/kix:create-pitch` skill and Pitch template
