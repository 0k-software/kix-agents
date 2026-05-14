---
name: triage
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

## Step 2 — Fill in missing descriptions

A good description is the most important context for the next steps — without
it you can't reliably pick a priority, category, epic linkage, or dependencies.
Before reasoning about the items, fill the gaps.

For each item with an empty or thin description, walk the user through it one
at a time:

1. Propose a description, drafted from the title and whatever surrounding
   context you have (related epic, sibling items, project conventions, recent
   activity).
2. Show the proposal and ask the user to **accept**, **edit**, or **skip**.
   Skipping leaves the item with no description; the later steps will have to
   work without it.
3. On accept or edit, apply:

   ```bash
   bd update <id> --description="<final description>"
   ```

Walk these one at a time — do **not** batch them. The user needs to read and
steer each proposal individually before the next one shows up. Only after every
missing description is filled or skipped do you continue to Step 3.

## Step 3 — Reason through the whole list

Walk every item and decide its final shape. For each item, in this order:

1. **Pick a priority** (`0`–`4`; `0` = critical, `4` = backlog). Every item
   gets one — priority is independent of type.
2. **Pick a category** — `bug` / `feature` / `chore`:
   - Default to whichever fits the kind of work.
   - If the item is too big to be a single deliverable (it would need sub-tasks
     of its own), change the category to `epic` instead — it gets promoted in
     place.
   - If the item is closeable (duplicate, obsolete, never going to happen),
     mark it for closure and record a reason. Closures still go through epic
     linkage in step 3.
3. **Decide epic linkage** (skip only for items that became `epic`; closures
   still get linked):
   - If the item fits inside an open or in-progress epic from Step 1, plan to
     set its `parent` to that epic.
   - If it doesn't fit any existing epic but clusters with other todo items,
     plan to create a new epic for the cluster and parent the members under it
     (draft the new epic's title, description, and priority now).
   - For a closure marked as a duplicate of / superseded by another task,
     parent it to whatever epic that other task belongs to (so the closure
     stays grouped with what replaced it).
   - For a closure marked obsolete / never-going-to-happen but still tied to a
     running epic, parent it to that epic.
   - Otherwise, leave the item parentless.
4. **Identify dependencies.** Look at what other open issues block this one or
   are blocked by it — anything that has to ship first, or anything that can
   only land once this one is done. Plan a `bd dep add` for each dependency you
   find. The parent/epic relationship is membership, not blocking; record real
   blocking relationships separately here even when the items are already in
   the same epic.

Reason through the whole list before talking to the user — clusterings, epic
assignments, and dependencies need to stay coherent across items.

## Step 4 — Present the plan overview

Show the user a single before/after view — current shape of every item next to
its proposed shape. Suggested format:

- For each item that is **not** being closed and **not** a member of a new
  epic, show one line:

  ```
  <id>: <title>
    before: <current-type> P<current-priority> (parent: <current-parent|none>)
    after:  <new-type>      P<new-priority>     (parent: <new-parent|none>)
  ```

- For each closure, show:

  ```
  <id>: <title>
    before: <current-type> P<current-priority>
    after:  closed — <reason>
  ```

- For each **new epic**, show the proposed epic first and its members beneath,
  each as a normal before/after line with the new parent pointing at the
  epic-to-be:

  ```
  NEW: <proposed epic title>     epic P<priority>
    <member-id>: <title>
      before: <current-type> P<current-priority> (parent: <current-parent|none>)
      after:  <new-type>      P<new-priority>     (parent: <NEW epic above>)
    …
  ```

End with a one-line totals summary (how many items change type, change
priority, get a new parent, get closed; how many new epics get created). Wait
for the user's reaction before applying.

## Step 5 — Confirm

Wait for the user to react to the Step 4 overview. They can:

- **Accept all** — apply the whole plan as-is.
- **Review step-by-step** — when the plan is too big to read in one go, walk
  the user through each proposed change one at a time. For each item (or
  new-epic group), show only that item's before/after and offer **accept / edit
  / skip**. Track confirmed decisions; drop skipped items.
- **Push back with changes** — adjust priorities, types, epic groupings,
  parents, closures, dependencies. Update the plan and re-present (back to Step
  4).
- **Reject specific items** — drop them from the plan; they stay in `bd todo`
  untouched.

Only proceed to Step 6 once the user explicitly says go.

## Step 6 — Apply

Run `bd` commands in this order, so dependencies (epic exists before its
members are parented) are satisfied:

1. **Closures:**
   - For a closure with no epic linkage:

     ```bash
     bd close <id> --reason="<reason>"
     ```

   - For a closure that should land inside an epic (duplicate's epic, related
     running epic), set the parent first, then close:

     ```bash
     bd update <id> --parent=<epic-id>
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

6. **Dependencies** (add last, once both ends exist with their final
   types/parents):

   ```bash
   bd dep add <issue-id> <depends-on-id>
   ```

If a `bd` call fails (validation error, unknown id, etc.), stop and surface the
offending command and its error — do not continue applying the rest of the
plan.

## Step 7 — Verify and report

1. Re-run `bd todo` and confirm the list is empty, or contains only items the
   user explicitly skipped.
2. Show the new shape of every item that moved. Run `bd list --all` and filter
   the output to keep only the lines that contain any **touched id** — every
   previous `bd todo` item plus every new or referenced epic. The tree output
   preserves parent → child structure, so grouping survives the filter:

   ```bash
   bd list --all | grep -E '<touched-id-1>|<touched-id-2>|…'
   ```

3. Report the totals and any follow-ups:
   - How many items were closed, re-typed, promoted, grouped, slotted, skipped.
   - The ids of any new epics created and how many members each got.
   - Any `bd` calls that failed and still need follow-up.
