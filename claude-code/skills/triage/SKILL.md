---
description: Triage open `bd todo` items — assign each a real type (bug/feature/chore) + priority, promote to epic, group under a new epic, slot under an existing epic, or close.
---

# Triage Backlog

Walk every open `bd todo` (i.e. every open `task`-typed issue) and either:

- re-type it as `bug` / `feature` / `chore` with a real priority,
- promote it to an `epic`,
- group it with other related tasks under a freshly created epic,
- slot it under an open or in-progress epic that already exists, or
- close it.

After the run, `bd todo` should be empty — or contain only items the user
explicitly skipped.

## Three epic cases

1. **Promote single task to epic.** The task is large enough to break into
   sub-tasks. Promote it in place.
2. **Create new epic from a group.** Several related tasks form a coherent
   theme. Create a new epic and parent the tasks under it.
3. **Slot under existing epic.** The task fits inside an already-open or
   in-progress epic. Re-type it (`bug` / `feature` / `chore`) and set its
   parent to that epic — **do not** promote it to epic itself.

In beads, "slot under epic" is `bd update <id> --parent=<epic-id>` (the
canonical epic-membership relationship), not `bd dep add`.

## Step 1 — Gather

1. Pull the todo list:

   ```bash
   bd todo --json
   ```

   Record id, title, description, priority, and any dependencies — anything
   that helps you reason about type, priority, and grouping.

2. If `bd todo` is empty, report that and exit. Skip the rest of this step.

3. Pull the set of open and in-progress epics so you know the candidates for
   case 3 (slot under existing epic):

   ```bash
   bd list --type=epic --status=open --json
   bd list --type=epic --status=in_progress --json
   ```

## Step 2 — Reason through the whole list

Before talking to the user, decide for **every** item which outcome applies:

- **Re-type & prioritize** — `bug` / `feature` / `chore` plus priority `0`–`4`
  (`0` = critical, `4` = backlog).
- **Promote to epic** — large enough to decompose; pick a priority.
- **Group into new epic** — several items form a theme; draft an epic title,
  description, priority, and the member list.
- **Slot under existing epic** — pick the target epic from Step 1's list, plus
  a `bug` / `feature` / `chore` type and priority for the member.
- **Close** — duplicate, obsolete, or never going to be done; record a reason.

Do **not** ask one item at a time blind. Reason through the whole list first so
groupings and epic assignments stay coherent.

## Step 3 — Present the plan overview

Show the user one digestible overview of all proposed movements, bucketed by
outcome. Suggested format (one line per item, empty buckets omitted):

- **Close** (N items)
  - `<id>: <title> — <reason>`
- **Re-type & prioritize** (N items)
  - `<id>: <title> → <type> P<priority>`
- **Promote to epic** (N items)
  - `<id>: <title> → epic P<priority>`
- **New epics** (N groups)
  - **<proposed epic title>** (P<priority>)
    - `<id>: <title> → <type> P<priority>`
    - …
- **Slot under existing epic** (N items)
  - `<id>: <title> → child of <epic-id> "<epic-title>" as <type> P<priority>`

End with a one-line totals summary. Wait for the user's reaction before walking
through individual decisions.

## Step 4 — Walk through and confirm

Walk the buckets in this order: **Close**, **Re-type & prioritize**, **Promote
to epic**, **New epics**, **Slot under existing epic**.

- For independent items, walk task-by-task. Show the proposed action on one
  line and offer **accept / override / skip**.
- For new-epic groups, present the whole group at once and offer **accept /
  override / skip the group**. If the user keeps the proposed epic but wants
  different members, walk the members one by one inside the group.

Track confirmed decisions as you go. Drop anything the user skipped — do
**not** apply it in Step 5.

## Step 5 — Apply

Run `bd` commands in this order, so dependencies (epic exists before its
members are parented) are satisfied:

1. **Closures:**

   ```bash
   bd close <id> --reason="<reason>"
   ```

2. **Re-types & priorities:**

   ```bash
   bd update <id> --type=<bug|feature|chore> --priority=<0-4>
   ```

3. **Promotions to epic:**

   ```bash
   bd update <id> --type=epic --priority=<0-4>
   ```

4. **New epics + their members:**
   - Create the epic and capture the new id from the output:

     ```bash
     bd create --title="<epic title>" --description="<why>" --type=epic --priority=<0-4>
     ```

   - For each member, re-type and parent in a single `bd update`:

     ```bash
     bd update <member-id> --type=<bug|feature|chore> --priority=<0-4> --parent=<new-epic-id>
     ```

5. **Slot under existing epic:**

   ```bash
   bd update <id> --type=<bug|feature|chore> --priority=<0-4> --parent=<epic-id>
   ```

If a `bd` call fails (validation error, unknown id, etc.), stop and surface the
offending command and its error — do not continue applying the rest of the
plan.

## Step 6 — Verify and report

1. Re-run `bd todo` and confirm the list is empty, or contains only items the
   user explicitly skipped.
2. Report:
   - How many items were closed, re-typed, promoted, grouped, slotted, skipped.
   - The ids of any new epics created and how many members each got.
   - Any `bd` calls that failed and still need follow-up.
