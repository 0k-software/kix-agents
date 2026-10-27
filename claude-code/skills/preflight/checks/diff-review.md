# diff-review

**Reads.** The range in the data — this check's last marker head to HEAD, or
the whole branch (`<base>...HEAD`) on a first run or after a rebase — plus any
uncommitted change. It reviews any diff: code, notes, docs.

**Delta.** Only that range: after a Fix job, just the fix commits.

**Findings.** Whatever the `code-review` skill reports, with the category it
gave each finding.

Run the `code-review` skill at level `medium` on the range. Keep its findings
for the batch, and from there for preflight's report.
