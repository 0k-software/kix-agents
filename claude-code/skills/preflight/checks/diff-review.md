# diff-review

**Reads.** The code the branch changed: the range `<from>`..HEAD, where
`<from>` is the `from` fact (this check's last marker head) — or the whole
branch, `<base>...HEAD` against the default branch, when `from` reads `-` —
plus any uncommitted change. It reviews any diff: code, notes, docs.

**Delta.** The row's detail says what moved: `new commits since <short>`,
`rebased since <short>` (the old head is gone, so review the whole branch),
`dirty tree`. Review only that.

**Findings.** Whatever the `code-review` skill reports, with the category it
gave each finding.

**Moot findings.** Read `preflight-checks findings diff-review` before you
start. When the delta settled one of them — fixed by hand, or the user said
"never mind" — resolve it: `preflight-checks resolve <id> fixed`, or
`preflight-checks resolve <id> discarded "obsolete: <why>"`. No other outcome.
Leave the rest open. `mark` takes only the new findings.

Run the `code-review` skill at level `medium` on the range above. Keep its
findings for `mark`, and from there for preflight's report.
