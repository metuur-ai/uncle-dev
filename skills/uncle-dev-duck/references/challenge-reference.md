# Challenge Mode Reference

Supporting detail for the uncle-senior Challenge process. Load this when you need examples, tables, or lookup material during a challenge session.

## Contents

1. [Constraint Classification Guide](#constraint-classification-guide)
2. [Scale Failure Patterns](#scale-failure-patterns)
3. [Reusability Killers](#reusability-killers)
4. [Common Rationalizations](#common-rationalizations)
5. [Red Flags](#red-flags)

---

## Constraint Classification Guide

| Type | Definition | Signal | Action |
|---|---|---|---|
| **Real** | External forcing function — legal, SLA, existing contract, hardware limit | "Cannot be changed without external approval" | Accept as a constraint |
| **Assumed** | Internal choice framed as a constraint | "We have to use X" without a verified reason | Challenge before accepting |
| **Speculative** | Solving a future problem that doesn't exist yet | "We might need to…" | Remove from scope entirely |

**Examples:**

```
Real:        "The mobile SDK only supports HTTP/1.1."
Real:        "GDPR requires data to stay in the EU region."
Assumed:     "We have to use a message queue because we might have high volume."
Assumed:     "We need an abstraction layer so we can swap databases later."
Speculative: "We need multi-tenancy in case we sell to enterprises."
Speculative: "The plugin architecture will let other teams extend this."
```

**How to challenge assumed constraints:**
- "Who decided this was a requirement?"
- "What happens if we don't do it this way?"
- "Is there a ticket, spec, or contract that requires this?"
- "When was this constraint last verified?"

---

## Scale Failure Patterns

| Pattern | Fails at | Better alternative |
|---|---|---|
| N+1 queries in a loop | Data volume × request rate | Batch fetch, JOIN, or cache |
| Global mutable state | Concurrent team contributions | Scoped, encapsulated state |
| Monolithic shared utility | Team coordination overhead | Single owner, defined API surface |
| Schema with no pagination | Data volume growth | Mandatory pagination at design time |
| Single-threaded sync pipeline | Load growth | Async, queue-backed, or parallelizable |
| Hard-coded config in shared code | Multiple deployment environments | Injected config, env vars |
| In-memory cache in stateless service | Horizontal scaling | Distributed cache (Redis, Memcached) |
| Synchronous fan-out to N services | N grows, latency multiplies | Async event, let consumers pull |

**Scale probe questions:**
- "At 10x traffic, what's the first thing that falls over?"
- "At 10x data, what query becomes unacceptably slow?"
- "At 10x team size, what becomes impossible to coordinate?"
- "Who owns this at scale? Is that person on the team?"

---

## Reusability Killers

A design scores Low reusability when any of these are true:

- **Domain assumptions in generic names** — a `UserEventBus` is not reusable; a `UserEventBus` named `EventBus` that secretly assumes users is worse
- **Caller context required** — the utility needs to know who is calling it to behave correctly
- **Side effects in pure utilities** — logging, analytics calls, or state mutations buried in what looks like a helper function
- **Tight data model coupling** — the utility directly references a specific schema (`user.profile.settings.theme`) instead of accepting a value
- **Framework lock-in** — an abstraction that only works with one ORM, router, or rendering engine
- **Configuration that grows** — if the config object has 5 fields today and will have 15 in 6 months, the abstraction is absorbing complexity it shouldn't own

**When Low reusability is acceptable:**
One-off solutions are fine if the team isn't positioning it as a reusable building block. The problem is when a design is sold as reusable but scores Low — that's the gap to flag.

---

## Common Rationalizations

| What you'll hear | The honest challenge |
|---|---|
| "We might need this later" | Build for what exists now. Add the extension when the second real use case arrives, not the first imagined one. |
| "This makes it more flexible" | Flexibility without a current consumer is complexity. Who uses this flexibility today? |
| "Everyone does it this way" | Industry convention is not a requirement. Why does *this* problem need this pattern? |
| "The existing code does something similar" | Similarity isn't identity. Is generalizing worth the cost now, or when a second real case arrives? |
| "We need to scale to X" | Is X a verified business requirement with a deadline, or an assumption? What's the evidence? |
| "It's cleaner this way" | Cleaner for whom? For the author who knows the context, or for the engineer reading it cold in a year? |
| "This is the right architecture" | Architecture is a means. What specific problem does this solve better than the simpler alternative? |
| "We already started down this path" | Sunk cost. The question is whether continuing costs less than stopping. |

---

## Red Flags

Stop and re-examine the approach when you see:

- A design that can't be described in two sentences without a diagram
- A new abstraction introduced for a single use case
- A solution addressing tomorrow's scale before today's requirements are validated
- Generic names (`Manager`, `Handler`, `Service`, `Processor`, `Controller`) hiding domain-specific logic
- Configuration objects with 5+ fields where only 2 are populated in any given context
- "Pluggable" or "extensible" architectures where the number of plugins is exactly one
- Code solving a coordination problem that should be solved with team clarity
- A layer of indirection whose only effect is to add a layer of indirection
- Three abstractions stacked to do what one function could do
- "Future-proofing" that the team has no roadmap item for
