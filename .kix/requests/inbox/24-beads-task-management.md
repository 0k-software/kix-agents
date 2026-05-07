---
id: 24
linked_to: null
created_by: noreply@anthropic.com
created_at: 2026-05-07T10:34:39Z
updated_at: 2026-05-07T10:34:39Z
---

# Replace Kix file-based task storage with beads

Take out the Kix skills in the repository that manage tasks via custom files,
and use the `beads` tool as the task management system instead. Beads would
define and track Requests, Pitches, and tasks, and we would use the IDs that
beads allocates rather than our own counter.

The spec of a Pitch, or of each task, could still live as a spec file in the
repository — but everything around defining and processing a Request (which is
not a heavy artifact) should move to beads.
