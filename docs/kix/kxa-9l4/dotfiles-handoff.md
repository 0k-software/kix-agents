# Handoff to the dotfiles session — session-lifecycle skills moved to kix

The `close`, `ship`, `preflight`, `title` and `next-up` skills, `project-code`
and their two Claude hooks now live in the kix plugin (kix-agents, bead
`kxa-9l4`) as `kix:close`, `kix:ship`, `kix:preflight`, `kix:title` and
`kix:next-up`. The copies match dotfiles as of 2026-10-03 (`b98d6e7`),
including `f183df6` (close deletes the shipped remote branch) and `b98d6e7`
(finding blocks as labelled bullets). Behavior is unchanged; only the
cross-references moved to the `kix:` namespace.

**Order matters.** kelvinst's kix plugin loads from the working tree of the
main kix-agents checkout. Do the dotfiles cleanup below only after the kix
branch has landed on kix-agents `main` and `/reload-plugins` shows the five
`kix:*` skills — otherwise the skills, `project-code` and the title hook
disappear in between. Until the cleanup, both copies are live: two SessionStart
hooks ask for a title (`title` and `kix:title`), and both `/close` and
`/kix:close` exist.

## Where each piece went

| dotfiles                                   | kix-agents                                                            |
| ------------------------------------------ | --------------------------------------------------------------------- |
| `claude/skills/close/SKILL.md`             | `claude-code/skills/close/SKILL.md`                                   |
| `claude/skills/ship/SKILL.md`              | `claude-code/skills/ship/SKILL.md`                                    |
| `claude/skills/preflight/SKILL.md`         | `claude-code/skills/preflight/SKILL.md`                               |
| `claude/skills/title/SKILL.md`             | `claude-code/skills/title/SKILL.md`                                   |
| `claude/skills/next-up/SKILL.md`           | `claude-code/skills/next-up/SKILL.md`                                 |
| `bin/project-code`                         | `claude-code/bin/project-code` (plugin `bin/`, on the Bash tool PATH) |
| `claude/hooks/title-first-prompt.sh`       | `claude-code/hooks/title-first-prompt.sh`, registered in `hooks.json` |
| `claude/hooks/allow-remote-control-off.sh` | `claude-code/hooks/allow-remote-control-off.sh`, in `hooks.json`      |
| `test/project-code.sh`                     | `scripts/test-project-code.sh` (`make test`)                          |
| `test/title-first-prompt.sh`               | `scripts/test-title-first-prompt.sh` (`make test`)                    |

Not moved, on purpose:

- `bin/orbit` — the aerospace wrapper; nothing in it touches these skills.
- `claude/CLAUDE.md` — a plugin cannot ship a CLAUDE.md, so the Session title
  rule stays in dotfiles, rewritten (below). "Asking questions" is a general
  rule (preflight cites it) and stays as is, including the `b98d6e7` edit.
- `docs/superpowers/specs/2026-09-30-session-naming-design.md` and
  `docs/superpowers/plans/2026-09-30-session-naming.md` — history of the closed
  `dot-mrr`; keep or delete as you like.

## Paths to delete in dotfiles

```
claude/skills/close/
claude/skills/ship/
claude/skills/preflight/
claude/skills/title/
claude/skills/next-up/
bin/project-code
claude/hooks/title-first-prompt.sh
claude/hooks/allow-remote-control-off.sh
test/project-code.sh
test/title-first-prompt.sh
```

And the installed copies in `$HOME`. `make install`'s backup step only moves
paths the repo still has (its targets are wildcards over `bin/`,
`claude/hooks/` and `claude/skills/`), so once the repo files are gone these
stay behind and shadow nothing but still load. Either run `make backup` before
deleting the repo files, or remove them by hand:

```
~/.claude/skills/close/
~/.claude/skills/ship/
~/.claude/skills/preflight/
~/.claude/skills/title/
~/.claude/skills/next-up/
~/.local/bin/project-code
~/.claude/hooks/title-first-prompt.sh
~/.claude/hooks/allow-remote-control-off.sh
```

`project-code set <code>` from a plain shell no longer has a PATH entry; run it
as `~/Developer/kix-agents/claude-code/bin/project-code set <code>` (or add an
alias in zshrc if wanted).

## Makefile entries to drop

None. `BIN_TARGETS`, `HOOK_TARGETS` and `SKILL_TARGETS` are wildcards, the
`install`, `clean` and `update` recipes loop over `./bin/*`, `./claude/hooks/*`
and `./claude/skills/*`, and `test` loops over `./test/*.sh` — deleting the
files above is enough. Check after the delete that `make test` still passes
(only `test/sync-monitors.sh` remains).

## `claude/settings.json` blocks to remove

The plugin's `claude-code/hooks/hooks.json` registers both hooks now. Drop from
`claude/settings.json` the whole `"PreToolUse"` entry whose matcher is
`mcp__ccd_session_mgmt__set_remote_control` (runs
`allow-remote-control-off.sh`), and the whole `"SessionStart"` entry with
matcher `startup` (runs `title-first-prompt.sh`). If those were the only
entries, remove the empty `"PreToolUse"` / `"SessionStart"` arrays too.

## `claude/CLAUDE.md` lines to rewrite

Only the Session title section. Replace:

```markdown
## Session title

- Run the `title` skill whenever the session's state changes: a tracker item
  gets filed, a design or plan gets approved, implementation starts. The
  `close` skill runs it itself for 📦 and 🏁.
```

with:

```markdown
## Session title

- Run the `kix:title` skill whenever the session's state changes: a tracker
  item gets filed, a design or plan gets approved, implementation starts. The
  `kix:close` skill runs it itself for 📦 and 🏁.
```

Nothing else in `claude/CLAUDE.md` names these skills. (The plugin's
SessionStart hook still says "later state changes follow the Session title rule
in CLAUDE.md" — it is this section.)

## Memories

Re-created in kix-agents, adapted (kelvinst chose "adapt" over verbatim):

- `no-prs-use-ship` → folded into the existing kix memory
  `no-prs-local-checks`, now naming `/kix:ship` and `kix:close`.
- `close-a-bd-issue-only-after-its-pr` → not re-created: it contradicts
  `no-prs-local-checks` (close when the work lands on main).
- `before-shipping-convention` → not re-created: kix-agents already has its own
  `after-ship-convention` (notes, "After this lands on main:").
- `pretooluse-hook-on-askuserquestion-must-not-return-permissio` → moved as is
  (dot-64n now named "dotfiles dot-64n"); it backs the keep-links-in-the-reply
  rule the skills follow. Forget it in dotfiles if nothing there needs it.

Left in dotfiles as unrelated: `english-only-in-dotfiles`,
`hammerspoon-hotkeys-and-raise`, `obsidian-cli-eval`.

On the dotfiles side: `kix:preflight` still reads each repo's own convention
(`bd memories after-ship`), so keep `before-shipping-convention` there if
dotfiles still wants its description-paragraph style. Rewrite `no-prs-use-ship`
to say `/kix:ship` and `kix:close`. Whether
`close-a-bd-issue-only-after-its-pr` survives is your call — it already
disagrees with `no-prs-use-ship`.

## Beads: old → new ids

50 beads moved: 47 on 2026-10-02 and 3 filed since (`dot-vgv`, `dot-tp5`,
`dot-91p`) on 2026-10-03; closed history stays in dotfiles. `dot-1vg`,
`dot-29q`, `dot-5aq` and `dot-kip.1` changed in dotfiles after the first copy
and were re-synced. `dot-5aq` and `dot-kip.1` are already closed in dotfiles;
their kix beads (`kxa-f93`, `kxa-lo0`) close when the kix branch lands, since
their work arrives with it. No deferred bead belongs to these skills (`dot-8lj`
stays in dotfiles — local autocommit config); `next-up` has no open bead
(`dot-1jb` is closed). Each new bead's notes name its old id. Parent and
dependency links between moved beads were recreated on the new ids; in-text
mentions of moved ids were rewritten to the new ids. Suggested on the dotfiles
side, once the kix branch has landed:
`bd close <old> --reason="moved to kix-agents as <new>"`.

| dotfiles     | kix-agents | Title                                                                                 |
| ------------ | ---------- | ------------------------------------------------------------------------------------- |
| `dot-1fk`    | `kxa-bhh`  | Fix small gaps in preflight/ship/close skills                                         |
| `dot-1vg`    | `kxa-tae`  | Offer to remove the session branch and worktree after close                           |
| `dot-4mu`    | `kxa-508`  | Surface before-merge task items at ship's Confirm step                                |
| `dot-4v7`    | `kxa-5l3`  | Split ship/close/preflight into stages, gates and actions                             |
| `dot-4v7.1`  | `kxa-102`  | Check library: split preflight into standalone checks with markers                    |
| `dot-4v7.2`  | `kxa-efc`  | Gate runner and /check over checkpoint config                                         |
| `dot-4v7.3`  | `kxa-2b2`  | Add land skill: fast-forward main through its entrance gate                           |
| `dot-4v7.4`  | `kxa-odx`  | Add archive skill for closing the session                                             |
| `dot-4v7.5`  | `kxa-7o8`  | Make close close the issue with a reason                                              |
| `dot-4v7.6`  | `kxa-dfo`  | Make ship deliver: before-shipping items, then close as shipped                       |
| `dot-4v7.7`  | `kxa-89c`  | Stage and gate display                                                                |
| `dot-4v7.8`  | `kxa-00b`  | Rename after-ship to before-shipping                                                  |
| `dot-4v7.9`  | `kxa-v9v`  | Run deterministic checkpoints after every turn                                        |
| `dot-4v7.10` | `kxa-a9i`  | Show new commits' diff inline with a labeled link in preflight/inspect                |
| `dot-4v7.11` | `kxa-h7t`  | Align title skill states with the dot-4v7 stages                                      |
| `dot-4v7.12` | `kxa-4sa`  | Add stage commands /file /design /plan /build                                         |
| `dot-5aq`    | `kxa-f93`  | close deletes the shipped remote branch on archive                                    |
| `dot-8ur`    | `kxa-p4u`  | Pin stg as Stingdom's project code                                                    |
| `dot-29q`    | `kxa-5zn`  | preflight: readable findings list, always printed right before Decide                 |
| `dot-62x`    | `kxa-25o`  | More trackers in preflight/ship/close                                                 |
| `dot-86s`    | `kxa-9d9`  | Support per-project custom checks in preflight                                        |
| `dot-bhx`    | `kxa-ymh`  | Persist preflight findings decisions across runs and sessions                         |
| `dot-bj2`    | `kxa-e0k`  | Delete the old refs/notes/review ref                                                  |
| `dot-c3v`    | `kxa-pa1`  | Show preflight as its own nested process in ship/close progress                       |
| `dot-c6n`    | `kxa-45i`  | Verify the **FIX:** label renders bold in the findings card                           |
| `dot-ct6`    | `kxa-98a`  | Support Linear as a tracker in preflight/ship/close                                   |
| `dot-cw7`    | `kxa-0mb`  | Drop the dead Neither bullet from close step 2a                                       |
| `dot-d8z`    | `kxa-wxr`  | Support GitHub Issues as a tracker in preflight/ship/close                            |
| `dot-e93`    | `kxa-43w`  | Give after-ship findings an outcome in preflight step 5                               |
| `dot-ehu`    | `kxa-6i5`  | ship: skip the Confirm question when the user already said they reviewed              |
| `dot-izs`    | `kxa-k9k`  | Investigate rewriting already-sent text in Claude replies (progress-bar style)        |
| `dot-kip`    | `kxa-6av`  | Preflight findings + progress output                                                  |
| `dot-kip.1`  | `kxa-lo0`  | Structured finding block before each one-by-one question                              |
| `dot-kns`    | `kxa-bni`  | preflight: drop 10.N sub-step numbers in Fixes, rename jobs to fixes                  |
| `dot-mbc`    | `kxa-59t`  | Evaluate keeping ReportFindings in preflight                                          |
| `dot-ph3`    | `kxa-a67`  | title/project-code: deferred review minors                                            |
| `dot-s52`    | `kxa-9so`  | Make preflight/ship/close deterministic and near-instant                              |
| `dot-s52.1`  | `kxa-cx0`  | Script preflight facts into one bin/ call                                             |
| `dot-s52.2`  | `kxa-6nb`  | Script tracker candidates for preflight check d                                       |
| `dot-s52.3`  | `kxa-8yn`  | Script ship's gate check                                                              |
| `dot-s52.4`  | `kxa-dm6`  | Find more preflight/ship/close checks to script                                       |
| `dot-s52.5`  | `kxa-ci5`  | Watermark preflight checks on the last run's time                                     |
| `dot-s52.6`  | `kxa-137`  | Instant preflight path when this session already checked HEAD                         |
| `dot-s52.7`  | `kxa-2b1`  | Skip the rebase when the branch already sits on the default branch                    |
| `dot-sv9`    | `kxa-5ym`  | Nudge /title from a PostToolUse hook on bd create and first code edit                 |
| `dot-w37`    | `kxa-nqv`  | Preflight tracker + task items                                                        |
| `dot-znp`    | `kxa-289`  | preflight/close: refuse to act on a branch this session doesn't own                   |
| `dot-vgv`    | `kxa-0eo`  | Delete the shipped remote branch in close's remote-control path                       |
| `dot-tp5`    | `kxa-13v`  | preflight Decide: always go one by one, drop the apply-all offer                      |
| `dot-91p`    | `kxa-93y`  | preflight Decide: batch one-by-one findings into multi-question AskUserQuestion calls |

Picked by: the epics `dot-4v7`, `dot-s52`, `dot-kip`, `dot-w37`, `dot-62x` with
every open child, `dot-1fk`, and `bd search` hits for close, ship, preflight
and title. Search hits left in dotfiles as unrelated: `dot-ffu.1` (scry close),
`dot-963.1` (triage local branches), `dot-d0w` (make install from an unshipped
branch). Also left: everything under `dot-u64` except `dot-sv9` (no parent) —
those are harness hooks, not these skills.

### Links left behind

These links pointed from a moved bead to a dotfiles bead that did not move;
they could not cross repos and were dropped (each moved bead's notes list its
own). Nothing to do unless you want a pointer on the dotfiles side:

| moved bead  | link                        |
| ----------- | --------------------------- |
| `dot-4v7`   | relates-to `dot-d0w` (open) |
| `dot-s52.7` | relates-to `dot-9jm` (open) |
| `dot-s52.2` | related `dot-0od`           |
| `dot-cw7`   | discovered-from `dot-gp8`   |
| `dot-e93`   | discovered-from `dot-gp8`   |
| `dot-4mu`   | discovered-from `dot-gp8`   |
| `dot-bj2`   | discovered-from `dot-ow3`   |
| `dot-bj2`   | blocked by `dot-a7j`        |
| `dot-1fk`   | discovered-from `dot-332`   |
| `dot-bhx`   | discovered-from `dot-332`   |
| `dot-mbc`   | discovered-from `dot-831`   |
| `dot-29q`   | blocked by `dot-vmt`        |
| `dot-8ur`   | discovered-from `dot-mrr`   |
| `dot-sv9`   | discovered-from `dot-mrr`   |
| `dot-ph3`   | discovered-from `dot-mrr`   |
| `dot-ct6`   | discovered-from `dot-9mq`   |
| `dot-d8z`   | discovered-from `dot-9mq`   |

The two open dotfiles beads that link into the moved set — `dot-9jm`
(relates-to `dot-s52.7`, now `kxa-2b1`) and `dot-d0w` (relates-to `dot-4v7`,
now `kxa-5l3`) — keep a dangling link once the old ids close; add a note naming
the kix id if useful.
