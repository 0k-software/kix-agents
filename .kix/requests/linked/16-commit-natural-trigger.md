---
id: 16
linked_to: 17
created_by: kelvin.stinghen@me.com
created_at: 2026-05-05T15:06:03Z
updated_at: 2026-05-05T15:07:06Z
---

# Natural-language "commit" should trigger the Kix commit skill

When I say "commit" or "commit this" without typing `/kix:commit`, Claude
should still route through the Kix commit flow. Suspicion: defining these as
slash commands doesn't support natural-language triggering — they should be
skills instead, so intent alone activates them.
