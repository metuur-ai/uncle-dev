---
description: Review and refresh docs/solutions/ for accuracy — update stale references, consolidate overlapping docs, replace outdated guidance, delete obsolete learnings
---

## Working Principles

1. **Think Before Coding** — Gather evidence before classifying any doc. Do not ask the user to make decisions before you have investigated the candidate artifacts.
2. **Simplicity First** — Apply the lightest intervention that restores accuracy. Fix a path, not the whole doc. Consolidate when two docs say the same thing, not when they merely share a topic.
3. **Surgical Changes** — Touch only what has drifted. Do not improve wording, add sections, or refactor docs that are still accurate.
4. **Goal-Driven Execution** — Every doc in scope ends with an explicit classification (Keep/Update/Consolidate/Replace/Delete/Stale) and a full report. No doc is silently skipped.

---

Invoke the agent-skills:uncle-dev-knowledge-maintenance skill.

Pass a scope argument when possible to narrow the review:

```
/knowledge-maintenance payments          # review docs related to the payments module
/knowledge-maintenance performance-issues  # review docs in the performance-issues category
/knowledge-maintenance auth-token-expiry   # review a specific learning by filename
/knowledge-maintenance mode:autofix        # unattended run — applies all unambiguous actions
```

Without a scope argument, the skill reviews all of `docs/solutions/`. For large knowledge stores,
a scope argument is strongly recommended to keep the session focused.

After execution, a full report is printed classifying every artifact reviewed. Run the discoverability
check after the report. Offer to commit the changes.
