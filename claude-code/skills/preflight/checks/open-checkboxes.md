# open-checkboxes

**Reads.** The candidates in the data: unchecked `- [ ]` items in the Markdown
files changed since this check's marker (committed or not) — _(Kingdone)_ every
note outside `Gates/`.

**Delta.** The candidates are already the delta.

**Findings.** Category `checklist`. A candidate is a finding when the file is
marked done (a completed quest or plan, a closed status, a "done" heading) or
the item is pending work the session left behind — cancelled, deferred
somewhere nobody linked, or done and not ticked. Drop the rest: a template,
prose that only looks like a checkbox, a plan step for later work.
