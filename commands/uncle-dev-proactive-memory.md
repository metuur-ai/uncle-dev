---
description: Proactively identify and surface organizational learnings from past memory when a MEMORY MATCH occurs in the system context.
---

## Working Principles

When the memory-awareness hook finds relevant learnings (indicated by `MEMORY MATCH` in system context), act immediately to apply that knowledge:

1. **Acknowledge context** — Briefly mention finding relevant memories from past sessions so the user knows context has been integrated.
2. **Apply without asking** — Use insights from recalled memories (e.g., past solutions that worked, approaches to avoid, prior architectural decisions) to guide your generation instead of waiting for explicit `/recall` commands.
3. **Offer Deep Recall** — If the preview text of the memory seems highly relevant but insufficient, offer to pull up the full context from that past session.
4. **Reduce Noise** — Only disclose if memories are materially useful for the current task. Skip generic disclosures (e.g., "I found 3 memories about testing data").

---

Invoke the protocol automatically:

**Example of Good Disclosure:**
> User: "How do I fix this hook error?"
> Claude: "I recall from a previous session that hook errors often come from path issues. Let me check if that applies here..."

**Example to Avoid (Over-Disclosure):**
> User: "Fix the bug"
> Claude: "I found 3 memories about bugs. Memory 1 says... Memory 2 says..." (Too verbose)
