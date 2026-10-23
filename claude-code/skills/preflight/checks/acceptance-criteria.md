# acceptance-criteria

**Reads.** The branch's bead: `bd show <bead>`, its design and its acceptance
criteria, against the diff and the session.

**Delta.** The row's detail says what moved: `new commits since <short>`,
`rebased since <short>`, `dirty tree`, or `<id> updated` when the bead itself
changed. Re-judge the items the delta could have changed.

**Findings.** Category `acceptance`: each design item and acceptance criterion
that the diff and the session do not deliver, or deliver only in part. Say
which item it is and what is missing.

**Moot findings.** Read `preflight-checks findings acceptance-criteria` before
you start. When the delta settled one of them — fixed by hand, or the user said
"never mind" — resolve it: `preflight-checks resolve <id> fixed`, or
`preflight-checks resolve <id> discarded "obsolete: <why>"`. No other outcome.
Leave the rest open. `mark` takes only the new findings.

Mark the check with `preflight-checks mark acceptance-criteria --bead <id>`,
where `<id>` is the branch's bead, so the script records it and a later update
to the bead makes the check stale. Find it the way preflight finds the current
work: an id in the branch name, the issue claimed or worked on in this session,
or one the conversation names.

No bead, or a bead with neither a design nor acceptance criteria → print
`⏭️ <n>/<total> Acceptance criteria — no design or acceptance on the bead` and
`mark` with `[]` and no `--bead`.
