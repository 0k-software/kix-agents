---
name: close
description:
  Use when the user types /close, or says they want to close, finish, wrap up
  or archive the current Claude session ("fechar a sessão", "encerrar", "posso
  arquivar?").
---

# Close the session

The user opens more sessions than they close. `/close` answers one question —
**can this session be archived without losing anything?** Only a session whose
work is on the default branch gets archived. The checks themselves live in the
`preflight` skill, which `ship` runs; close adds only what comes after the
ship.

**Language.** Everything you produce follows the language the user is speaking:
replies, AskUserQuestion questions and option labels, and every commit you
write.

## Repo type

Detect it from the repository root (`git rev-parse --show-toplevel`), the same
way `preflight` does. The first match wins:

1. **Kingdone** — `Gates/Gates.md` exists. The vault's own conventions (its
   `CLAUDE.md`) apply: renames through the Obsidian CLI, and so on.
2. **Beads** — a `.beads/` directory exists and `command -v bd` succeeds.
3. **Neither** — no tracker.

**Default branch.** Never assume `main`:

```bash
git symbolic-ref --short refs/remotes/origin/HEAD 2>/dev/null \
  || { git remote set-head origin --auto >/dev/null && git symbolic-ref --short refs/remotes/origin/HEAD; }
```

Below, `<base>` is that ref (e.g. `origin/main`) and `<default>` is the branch
name without `origin/`.

## Progress

Print a progress line when each step ends, and a ❓ line before each question,
as preflight's _Progress_ says: `ship` (with its preflight) prints 1–15, then
step 2a is 16/17 and 2b is 17/17.

## 1. Ship

Shipping is always the **last** thing a session does: nothing — no fix, no
arrival, no task, no other work — runs after it. The only exceptions are the
bookkeeping of step 2 (marking the shipped task done on the user's yes) and the
archive.

Run the `ship` skill. It runs `preflight` (rebase, the six checks, findings,
fixes and deferrals), asks the user to confirm, and pushes. If it stops — a
**changed** or **open** verdict, a "Not yet", a failed push — report why and
stop: the session is not ready to archive.

## 2. Archive

Tell the user what was done: fixes with their commits, what was deferred, what
was left or discarded (each discard with its reason), what was inferred and
from where. Every arrival you mention is a link to its note; every bd task and
every closed issue is named by its id.

Everything below runs **only after a successful ship**, in this order.

**a. Mark the task done.** Find the task the session was about, the same way
the Create task job finds the current work: an id in the branch name, the task
claimed or worked on in this session, or one the conversation names. If none is
identifiable, say so and ask nothing.

A task is done only when nothing is left: its work is in use, or ready for the
tasks that depend on it. Before asking, read the whole task — there is no fixed
format for what is pending, so read it for meaning, not for a keyword or a
heading. Look for anything it says to do at a moment that is now or later:
"after this is merged", "after it ships", "before deploying", "after the
deploy", a migration to run, a config to change, something to install. Each
such item is still pending unless the task, the conversation or the tracker
shows it done. An item this session only created or planned (wrote or rewrote
its description, design or acceptance) without doing its work is not the
session's task and is never offered as done: its work has not started. An item
created and then worked on in the same session is the session's task as usual.
When planning items is all the session did, say so, ask nothing, and go to 2b.
Also look for what is still open under the task:

- _(Beads)_ `bd show <id>` (description, design, notes, acceptance, comments),
  plus any open or in-progress issue it depends on (`blocks`, in
  `bd dep list <id>`) or, for an epic, any open child (`bd children <id>`);
- _(Kingdone)_ the quest's notes, and the arrivals they link that are still in
  `Gates/`;
- _(Neither)_ the after-ship findings of this run's preflight.

When there is any, do not offer to mark the task done: print
`⚠️ 16/17 Mark task done — <task> has <n> item(s) left`, list each — when it
applies (as the task says it) and what to do, or the blocking issue's id — and
stop there: skip 2b, do not offer to archive. End on that ⚠️ block, and say to
run `/close` again once the items are done — the rerun ships nothing new and
goes straight to marking the task done and archiving.

Otherwise run the `title` skill with `📦` — the task's work landed and is being
delivered — then ask with AskUserQuestion, naming each task: "Mark <task> done"
(Recommended) — "Its work is now on `<default>`." · "Leave it open". Never mark
a task done without that yes.

- _(Beads)_ The task is a bd issue. On yes:
  `bd close <id> --reason="shipped to <default>"`, then `bd dolt push` when the
  repo has a Dolt remote.
- _(Kingdone)_ The task is a quest (`qst-<id> <title>`, a note or a folder), in
  progress in `Satchel/Quest Pocket/` or planned in
  `Observatory/Drawer/Quests/Planned/`. On yes: stamp its note's frontmatter
  with `completed: YYYY-MM-DD` (today) — for a note quest, that note; for a
  folder quest, its main note, the one named after the quest's subject without
  the `qst-<id>` prefix or verb, which the supporting notes are named after
  (e.g. `Kix Checkpoints.md`; when unclear, ask the user which) — move it (a
  folder quest moves whole) to `Observatory/Drawer/Quests/Completed/` through
  the Obsidian CLI so links follow, commit
  (`docs(observatory): <qst-id> is completed`), and push it straight to
  `<default>` as a fast-forward (`git push origin HEAD:<default>`, then the
  branch). This status-only commit is the one commit allowed after the ship.
- _(Neither)_ No tracker: skip this.

Then run the `title` skill: `🏁` once the task is marked done, or when there is
no task or no tracker — the work is on the default branch now; `🏭` when the
user chose to leave it open, or when 2a stops on items left — landed is not
finished.

**b. Archive.** First check the session's mode. When the
`mcp__ccd_session_mgmt__*` tools are not available, the session was started
from the phone through a terminal `claude remote-control` server: Remote
Control is its only transport, so turning it off would kill the session, and
nothing inside it can archive it. There, skip this step's question, switch and
archive entirely — tell the user in one line that the work is shipped and the
session can be archived from the phone (the session's menu → Archive), and
stop.

Otherwise ask with AskUserQuestion: "Archive this session now?" — "Archive"
(Recommended) · "Leave it open". On "Archive", get this session's state with
`mcp__ccd_session_mgmt__get_session` (`"self"`), then, before archiving:

- **Remote Control.** When `remoteControlState` is `on` or `connecting`, turn
  it off with `mcp__ccd_session_mgmt__set_remote_control`
  (`session_id: "self"`, `enabled: false`) — the app asks the user to approve —
  so no phone or claude.ai link stays open on an archived session. When
  `startedViaRemoteControl` is true the switch is locked: say so and go on.
- **Pin.** When `pinned` is true, unpin it with `mcp__ccd_sidebar__set_pinned`
  (`session_id: "self"`, `pinned: false`), so the sidebar's Pinned list only
  holds live work.

Then call `mcp__ccd_session_mgmt__archive_session` with `session_id: "self"`.
Never archive without that answer, or while the work is not in `<base>`, or
while the task has items left (2a).

## Common mistakes

- Reviewing, rebasing or resolving findings from close itself instead of
  through `ship` → `preflight`.
- Doing any work after the ship.
- Marking a bd issue or a quest done without asking, or before the ship.
- Offering to mark done a bd issue or arrival this session only created or
  planned without doing its work — or refusing one it created and then did.
- Offering to mark a task done while its content says something is still to be
  done after the ship or the deploy, or while an open blocker on it is still
  pending.
- Archiving while the task still has items left after the ship.
- Archiving after a ship that stopped.
- Archiving with Remote Control still on, or the session still pinned.
- In a terminal `claude remote-control` session (no `ccd_session_mgmt` tools),
  trying to turn Remote Control off or to archive — it ends the session; point
  the user to the phone instead.
- Hardcoding `main` instead of the detected default branch.
- Naming an arrival without linking it, or a task without its id.
- Writing in English to a user who speaks Portuguese.
