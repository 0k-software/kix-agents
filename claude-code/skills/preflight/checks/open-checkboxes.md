# open-checkboxes

**Reads.** The `file:line` list in the row's detail: unchecked `- [ ]` items in
the Markdown files the branch (or the dirty tree) touched — _(Kingdone)_ every
note outside `Gates/`.

**Delta.** The list is already the delta: only Markdown touched since this
check's marker. Judge those items.

**Findings.** Category `checklist`.

**Moot findings.** Read `preflight-checks findings open-checkboxes` before you
start. When the delta settled one of them — fixed by hand, or the user said
"never mind" — resolve it: `preflight-checks resolve <id> fixed`, or
`preflight-checks resolve <id> discarded "obsolete: <why>"`. No other outcome.
Leave the rest open. `mark` takes only the new findings.

Judge each listed item. It is a finding when the file is marked done (a
completed quest or plan, a closed status, a "done" heading) or the item is
pending work the session left behind. Usual causes: it was cancelled, it was
deferred somewhere nobody linked, or it was done and not ticked.
