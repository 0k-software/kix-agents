---
description: Cancel a Kix Request, Pitch, or Task
argument-hint: <id> [reason]
---

You are cancelling a Kix entity — marking work as discarded, not as finished.
Cancellation is orthogonal to phase progression: a Pitch or Task can be
cancelled at any phase, and the phase it was in when cancelled is preserved in
the artifact. Counterpart to the create/link skills: those bring work into the
system; this skill takes work out.

How cancellation is recorded differs by type:

- **Request** — the file moves to `.kix/requests/closed/` with a
  `## Resolution` section recording the cancellation reason. Use this when a
  Request being triaged from `inbox/`, or re-triaged from `postponed/`, is
  decided "no, won't do": superseded, duplicate, won't-fix, no longer relevant.
  Linked Requests are already processed — once a Request is linked to a Pitch
  or Task, the work continues there and the Request itself is done; this skill
  does not cancel from `linked/`. Implemented Requests share the `closed/`
  folder; the `## Resolution` body distinguishes "Cancelled. ..." from
  "Implemented...".
- **Pitch** — a `cancelled_at` timestamp is added to the front-matter; `phase:`
  is left untouched so the phase the Pitch was in at cancellation is preserved.
- **Task** — a `cancelled_at` timestamp is added to the front-matter; `phase:`
  is left untouched so the phase the Task was in at cancellation is preserved.

For work that landed (Pitches that shipped, Tasks that finished), this skill is
**not** the right tool — that is normal phase progression, not cancellation.
For Requests whose work landed, prefer `kix:implement`, which closes the
Request as part of opening the PR.

The user's argument: $ARGUMENTS

## Argument parsing

Parse `$ARGUMENTS` for a single **id** — a bare integer (`13`), hash-prefixed
(`#13`), or a path containing an `<id>-` segment
(`.kix/requests/inbox/13-foo.md`, `.kix/pitches/14-id-conflicts-teams/`).
Extract the integer id.

Any remaining text after the id is the **cancellation reason** — free text the
user provided to explain why the entity is being cancelled (e.g.
`13 superseded by #20`, `#7 won't fix, browser limitation`). It becomes part of
the cancellation record.

If `$ARGUMENTS` is empty or no id can be parsed, ask the user for the id and
wait for their reply.

## Steps

### 1. Identify the entity

Resolve the id by globbing across all entity locations:

```bash
ls .kix/requests/*/<id>-*.md 2>/dev/null
ls -d .kix/pitches/<id>-*/ 2>/dev/null
ls -d .kix/pitches/*/tasks/<id>-*/ 2>/dev/null
```

Exactly one location should match. If zero match, abort with a clear error
naming the missing id. If multiple match, abort and report the conflict (this
should not happen with a well-behaved allocator, but bail loudly if it does).

The matched location determines the entity type:

- match under `.kix/requests/<subfolder>/<id>-<slug>.md` → **Request**
- match `.kix/pitches/<id>-<slug>/` → **Pitch**
- match `.kix/pitches/<pitch-slug>/tasks/<id>-<slug>/` → **Task** (Tasks live
  in a `tasks/` subfolder of their parent Pitch)

Read the entity's front-matter and body. The title is the H1 (`# ...`) at the
top of the body. You will also need the current location, the existing
`cancelled_at` (Pitch / Task), and any `linked_to` (Request) or
`requests: [...]` (Pitch).

### 2. Apply the type-specific cancellation

Use the current UTC timestamp as the new `updated_at` value:

```bash
date -u +%Y-%m-%dT%H:%M:%SZ
```

#### Request

If the file is already in `.kix/requests/closed/`, warn the user that the
Request is already closed and stop without making changes.

If it is in `.kix/requests/linked/`, abort with a clear message: a linked
Request is already processed — the work has been promoted to a Pitch or Task
and continues there. `/kix:cancel` only applies to Requests still in `inbox/`
or `postponed/` (those whose triage decided against doing the work). To cancel
the underlying work, cancel the Pitch or Task the Request is linked to.

Move the file:

```bash
mkdir -p .kix/requests/closed
git mv .kix/requests/<current-subfolder>/<filename> .kix/requests/closed/
```

Update the front-matter `updated_at` field at the new path.

Append a `## Resolution` section to the body:

```markdown
## Resolution

Cancelled. <reason text from $ARGUMENTS, lightly cleaned. If no reason was
given, write a short one-liner like "no further action needed" — do not
invent a reason the user did not state.>
```

#### Pitch

If `cancelled_at` is already set, warn the user that the Pitch is already
cancelled and stop without making changes.

Update the front-matter at `.kix/pitches/<id>-<slug>/pitch.md`:

- `cancelled_at: <new timestamp>` (added)
- `updated_at: <new timestamp>`

Do **not** change `phase:` — the phase the Pitch was in at cancellation is
preserved as part of the record.

Append a `## Resolution` section to the body. If one already exists (e.g. from
prior implementation work), append a new bullet to it; otherwise add a fresh
section:

```markdown
## Resolution

Cancelled. <reason / one-line summary, from $ARGUMENTS or empty if no reason
given.>
```

#### Task

If `cancelled_at` is already set, warn the user that the Task is already
cancelled and stop without making changes.

Update the front-matter at
`.kix/pitches/<pitch-slug>/tasks/<id>-<slug>/task.md`:

- `cancelled_at: <new timestamp>` (added)
- `updated_at: <new timestamp>`

Do **not** change `phase:` — the phase the Task was in at cancellation is
preserved.

Append a `## Resolution` section to the body, mirroring the Pitch shape:

```markdown
## Resolution

Cancelled. <reason / one-line summary.>
```

### 3. Commit

Route the commit through the `kix:commit` skill, passing the cancellation as
the context so the message follows the project's standard commit shape:

```
/kix:commit cancelling <type> #<id> - <title>
```

For example: `/kix:commit cancelling request #7 - flaky CI tests` or
`/kix:commit cancelling pitch #14 - ID conflicts when multiple people allocate IDs in parallel`.

### 4. Confirm

Report:

- The entity type, id, and title.
- Where it was moved to (Request) or that `cancelled_at` was set (Pitch /
  Task), with the phase preserved at the time of cancellation.
- The cancellation reason that was recorded.
- The commit SHA.
- For Pitches with non-empty `requests: [...]`: list those linked Request ids
  so the user can decide whether to also cancel them. This skill does not
  cascade — cancelling a Pitch does not auto-cancel its linked Requests.
