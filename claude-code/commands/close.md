---
description: Close a Kix Request, Pitch, or Task
argument-hint: <id> [reason]
---

You are closing a Kix entity — moving it to its terminal state. Counterpart to
the create/link skills: those bring work into the system; this skill takes it
out.

The terminal state differs by type:

- **Request** — outcome `closed` (encoded as `.kix/requests/closed/`). Use this
  when a Request being triaged from `inbox/`, or re-triaged from `postponed/`,
  is decided "no, won't do": superseded, duplicate, won't-fix, no longer
  relevant. Linked Requests are already processed — once a Request is linked to
  a Pitch or Task, the work continues there and the Request itself is done;
  this skill does not close from `linked/`. For Requests whose work landed,
  prefer `kix:implement`, which closes the Request as part of opening the PR.
- **Pitch** — phase `shipped`. The Pitch's work landed.
- **Task** — phase `done`. The Task's work landed.

The user's argument: $ARGUMENTS

## Argument parsing

Parse `$ARGUMENTS` for a single **id** — a bare integer (`13`), hash-prefixed
(`#13`), or a path containing an `<id>-` segment
(`.kix/requests/inbox/13-foo.md`, `.kix/pitches/14-id-conflicts-teams/`).
Extract the integer id.

Any remaining text after the id is the **closing reason** — free text the user
provided to explain why the entity is being closed (e.g.
`13 superseded by #20`, `#7 won't fix, browser limitation`). It becomes part of
the closing record.

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
top of the body. You will also need the current location/phase, and any
`linked_to` (Request) or `requests: [...]` (Pitch).

### 2. Apply the type-specific close

Use the current UTC timestamp as the new `updated_at` value:

```bash
date -u +%Y-%m-%dT%H:%M:%SZ
```

#### Request

If the file is already in `.kix/requests/closed/`, warn the user that the
Request is already closed and stop without making changes.

If it is in `.kix/requests/linked/`, abort with a clear message: a linked
Request is already processed — the work has been promoted to a Pitch or Task
and continues there. `/kix:close` only applies to Requests still in `inbox/` or
`postponed/` (those whose triage decided against doing the work). To close the
underlying work, close the Pitch or Task the Request is linked to.

Move the file:

```bash
mkdir -p .kix/requests/closed
git mv .kix/requests/<current-subfolder>/<filename> .kix/requests/closed/
```

Update the front-matter `updated_at` field at the new path.

Append a `## Resolution` section to the body:

```markdown
## Resolution

Closed during triage. <reason text from $ARGUMENTS, lightly cleaned. If no
reason was given, write a short one-liner like "no further action needed" — do
not invent a reason the user did not state.>
```

#### Pitch

If `phase: shipped` already, warn the user and stop.

Update the front-matter at `.kix/pitches/<id>-<slug>/pitch.md`:

- `phase: shipped`
- `updated_at: <new timestamp>`

Append a `## Resolution` section to the body. If one already exists (e.g. from
prior implementation work), append a new bullet to it; otherwise add a fresh
section:

```markdown
## Resolution

Shipped. <reason / one-line summary, from $ARGUMENTS or empty if no reason
given.>
```

#### Task

If `phase: done` already, warn the user and stop.

Update the front-matter at
`.kix/pitches/<pitch-slug>/tasks/<id>-<slug>/task.md`:

- `phase: done`
- `updated_at: <new timestamp>`

Append a `## Resolution` section to the body, mirroring the Pitch shape:

```markdown
## Resolution

Done. <reason / one-line summary.>
```

### 3. Commit

Commit the change with a clear message:

```
close <type> #<id>: <title>
```

For example: `close request #7: flaky CI tests` or
`close pitch #14: ID conflicts when multiple people allocate IDs in parallel`.

### 4. Confirm

Report:

- The entity type, id, and title.
- Where it was moved to (Request) or what `phase` it now holds (Pitch / Task).
- The closing reason that was recorded.
- The commit SHA.
- For Pitches with non-empty `requests: [...]`: list those linked Request ids
  so the user can decide whether to also close them. This skill does not
  cascade — closing a Pitch does not auto-close its linked Requests.
