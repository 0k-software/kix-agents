---
name: title
description:
  Use when the user types /kix:title, asks to name or rename the session ("renomeia
  a sessão", "atualiza o título"), or when another skill or CLAUDE.md says to
  set the session title for a state change.
---

# Title the session

The title shows, at a glance in the sidebar, the project, the tracker item and
where that item is in its life:

```
<emoji> <code>-<id> │ <description>
```

`📐 dot-mrr │ Session naming skill`. With no tracker item yet:
`📥 dot │ <description>`. The prefix is everything before `│` (space, U+2502
box-drawing bar, space); the description is everything after it.

**Language.** The description follows the language the user is speaking.

## Arguments

None → guess every part. Any part given overrides the guess, in any order:

- a state, as emoji or word (table below);
- a tracker id (`dot-abc`, `qst-abc`);
- anything else → the description.

**Called by another skill** (`kix:close` — always with a state): never ask and
never write. Several candidate items → take the best guess silently; skip the
supersede and epic proposals. The caller is in the middle of its own work, and
a question or a tracker write would stop it.

## States

| Emoji | Word      | When                                                                |
| ----- | --------- | ------------------------------------------------------------------- |
| 📥    | `reg`     | items filed or triaged (created, classified, moved), none worked on |
| 📐    | `plan`    | the work shaped (brainstorm, spec, plan) but not done               |
| 🏭    | `impl`    | the item's own work being done                                      |
| 📦    | `ship`    | `kix:close` delivering landed work                                  |
| 🏁    | `shipped` | the item closed as shipped — the work is on the default branch      |

States follow the item's work, not the file type. 🏭 is whatever the item
delivers: in a code repo, code (or a plan being executed); in a notes or docs
repo (a Kingdone vault), the deliverable notes, research, documents, or ticking
the item's checklist by doing it. Editing an item note counts as 📥 only when
the edit files or triages it.

Reviews (`kix:preflight`, debrief, a code review) and landing on the default
branch are gates the item can pass while still being implemented — they are not
states. Guessing: the latest of these signals in the session wins. 🏁 never
comes from a guess alone — only when the work is in `origin/<default>`
(`git merge-base --is-ancestor HEAD <base>`) and the item is closed. An item
closed without shipping (cancelled, superseded, wontfix) has no state of its
own: leave the title as it is.

## Steps

1. **Project code.** Run `project-code` (on PATH from the kix plugin's `bin/`;
   else `${CLAUDE_PLUGIN_ROOT}/bin/project-code`, or
   `claude-code/bin/project-code` in a kix-agents checkout) and use its output
   — it is the only source of the code: the one saved in
   `.claude/settings.json`, else one generated from the repo name. Never derive
   or ask for a code yourself. Exit 1 (not a git repo) → no code; the prefix is
   just `<emoji>`. Exit 3 (`.claude/settings.json` is not valid JSON) → no code
   this time; tell the user the file needs fixing by hand. To pin another code,
   the user runs `project-code set <code>`.
2. **Tracker.** From the repo root, first match wins: **Kingdone**
   (`Gates/Gates.md` exists; items are quests `qst-<id>`), **Beads** (`.beads/`
   exists and `command -v bd`), **neither** (no id in the title).
3. **Main item.** Candidates: items this session created, claimed or edited, an
   id in the branch name, one the conversation names. Then, in order:
   1. one candidate, or one clearly central → it;
   2. **supersede first** — one candidate covers the others (or they are
      duplicates): propose closing the rest as superseded by it (Beads:
      `bd supersede <other> --with=<main>`; Kingdone: the vault's own
      convention from its `CLAUDE.md`). Ask; write only on yes. The survivor is
      the main item;
   3. the rest share a parent → the parent;
   4. the rest share a topic, no parent → propose a new epic (title and
      children) and reparenting them under it (`bd create --type=epic`, then
      `bd update <child> --parent=<epic>`). Ask; write only on yes. The epic is
      the main item;
   5. unrelated → ask which one is main.

   The id in the title drops the tracker prefix and keeps any child suffix:
   `dot-mrr` → `mrr`, `dot-s52.3` → `s52.3`, `qst-abc` → `abc`.

4. **State.** Argument, else the table above.
5. **Description.** Argument; else the main item's title; else a short topic of
   the session. Trim to about 40 characters on a word boundary. When the
   current title already has a `│` separator and its description still fits the
   main item, keep that description.
6. **Rename.** Load `mcp__ccd_session_mgmt__set_session_title` with ToolSearch
   if it is deferred, then call it for this session (`session_id: "self"`). If
   the tool does not exist (plain CLI), print `/rename <title>` in a code block
   for the user to run.
7. **Report.** One line: the new title.

Never fail hard: leave out any part that cannot be resolved; the worst case is
printing the proposed title.

## Common mistakes

- Taking the repo name from the worktree folder — always `project-code repo`.
- Reading 🏭 as code-only — in a notes repo, researching and writing the item's
  documents is the work, even when no code and only "tracker" notes changed.
- Setting 🏁 because ship started, or because close ran with another reason.
- Writing a supersede or an epic without the user's yes.
- Dropping the user's description on every rename instead of swapping only the
  prefix.
