---
id: 22
title: Abort fix-pr skill when APR has pending review
type: request
linked_to: null
created_by: noreply@anthropic.com
created_at: 2026-05-06T14:31:15Z
updated_at: 2026-05-06T14:31:15Z
---

If someone calls the fix-pr skill on top of an APR that has any pending review,
it should abort and inform the user.
