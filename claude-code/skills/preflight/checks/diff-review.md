# diff-review

**Reads.** The range in the data — this check's last marker head to HEAD, or
the whole branch (`<base>...HEAD`) on a first run or after a rebase — plus any
uncommitted change. It reviews any diff: code, notes, docs.

**Delta.** Only that range: after a Fix job, just the fix commits.

**Findings.** Whatever the `code-review` skill reports, with the category it
gave each finding.

Run the `code-review` skill at level `medium` on the range. It reports through
its own ReportFindings call; take the findings from that call's input for the
batch, and from there for preflight's report. When a Fixes job later fixes one
of them, code-review's own rule calls ReportFindings again with outcomes: let
it — that call is code-review's; preflight makes no card of its own.
