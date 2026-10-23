# post-landing-steps

**Reads.** The diff, the conversation, the touched files and the task.

**Delta.** The new commits or dirty tree in the row's detail, and the
conversation since the `conversation since <ts>` in the row's detail: the
turns, automated events and AskUserQuestion answers after that time. When the
row's status is `unknown` (no transcript to read), find the line
`🛫 preflight check started here · <run>` in your context and review everything
below it; no such line (the context was compacted) → review the whole session
and say so.

**Findings.** Category `after-ship`.

**Moot findings.** Read `preflight-checks findings post-landing-steps` before
you start. When the delta settled one of them — fixed by hand, or the user said
"never mind" — resolve it: `preflight-checks resolve <id> fixed`, or
`preflight-checks resolve <id> discarded "obsolete: <why>"`. No other outcome.
Leave the rest open. `mark` takes only the new findings.

A closed task means nothing is left to do: the work is in use, or — for a task
other tasks depend on — ready for them to start. From the diff, the
conversation and the touched files, list what still has to happen **after** the
branch lands on `<default>` before that is true: data migrations, database
schema migrations, configuration changes on a machine or a service, a deploy,
an install or reinstall (`make install`, a skill, a plugin), a secret or env
var to set, a restart, a manual check in the real app. Only what cannot be done
before the ship — anything doable now is an `unraised-follow-ups` finding with
the fix "do it now".

Each is a finding (`category: after-ship`) whose suggested fix is to write it
down in the current task, never to do it: preflight's "Note in the task" job.
Skip what the task already says. `kix:close` reads the task before marking it
done, so what the task says is still pending keeps it open. _(Neither)_ there
is no tracker: the finding's fix is a ⚠️ line in the run's closing ⚠️ block.
