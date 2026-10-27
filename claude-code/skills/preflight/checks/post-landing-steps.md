# post-landing-steps

**Reads.** The diff, the conversation, the touched files and the task (its
notes in the data). Mechanical: list what you find, don't deliberate.

**Delta.** New commits other than Fix commits, the bead's own updates, and the
prompts since the marker.

**Findings.** Category `after-ship`. A closed task means nothing is left to do:
the work is in use, or — for a task other tasks depend on — ready for them to
start. List what still has to happen **after** the branch lands on `<default>`
before that is true: data migrations, database schema migrations, configuration
changes on a machine or a service, a deploy, an install or reinstall
(`make install`, a skill, a plugin), a secret or env var to set, a restart, a
manual check in the real app. Only what cannot be done before the ship —
anything doable now is an `unraised-follow-ups` finding with the fix "do it
now".

Each finding's suggested fix is to write it down in the current task, never to
do it: preflight's "Note in the task" job. Skip what the task already says.
`kix:close` reads the task before marking it done, so what the task says is
still pending keeps it open. _(Neither)_ there is no tracker: the finding's fix
is a ⚠️ line in the run's closing ⚠️ block.
