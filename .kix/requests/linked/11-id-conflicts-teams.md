---
id: 11
linked_to: 14
created_by: kelvin.stinghen@me.com
created_at: 2026-05-05T14:01:43Z
updated_at: 2026-05-05T15:01:28Z
---

# ID conflicts when multiple people allocate IDs in parallel

The current ID allocator reads `.kix/.state/next-id` and increments it. In a
team setting this collides: if I create a Request locally and don't push, and
someone else also creates one on their branch, both end up with the same ID. We
need a strategy that survives parallel work across branches and people.
