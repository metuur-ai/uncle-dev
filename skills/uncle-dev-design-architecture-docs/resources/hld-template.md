# {{Product Name}} — High-Level Design

[One paragraph describing what this product is, who it serves, and what value it delivers. This is the durable anchor — every LLD, EARS spec, and `@spec` annotation traces back here.]

---

## Vision

[2–3 sentences. What does this product become at maturity? What does it explicitly NOT become?]

## Principles

Durable architectural commitments. These should change rarely; when they change, every LLD downstream may need to change too.

- **[Principle name]**: [One-line statement, e.g. "Sessions are scoped per-user and never long-lived."]
- **[Principle name]**: [One-line statement]
- **[Principle name]**: [One-line statement]

## Segments

The product is partitioned into product-behavior segments. Each segment has its own LLD. The full segment registry is `docs/arrows/index.yaml`; this list mirrors it.

| Segment | Prefix | LLD | Owns |
|---|---|---|---|
| auth | `AUTH-*` | [docs/llds/auth.md](llds/auth.md) | Login, logout, session creation, auth errors |
| billing | `BILLING-*` | [docs/llds/billing.md](llds/billing.md) | Invoices, subscriptions, refunds |
| [...] | | | |

## Cross-Segment Invariants

Behaviors that MUST hold across all segments. These are stated once, here, not duplicated in each LLD.

- **[Invariant]**: [e.g. "All user-facing errors must be safe — never expose stack traces, SQL, or internal IDs."]
- **[Invariant]**: [e.g. "All write operations must be idempotent under retry."]

## Out of Scope

Behaviors this product explicitly does NOT own. List them so future contributors don't assume the product should grow into these areas.

- [e.g. "Identity federation with third-party SSO providers"]
- [e.g. "Long-lived API tokens (we use short-lived sessions only)"]

---

<!--
HLD authorship notes (delete when filling in):

- The HLD is short. If it's longer than ~2 pages, you're writing an LLD or PRD by mistake.
- Every segment listed here MUST have a corresponding entry in docs/arrows/index.yaml,
  a docs/llds/<segment>.md, and a docs/specs/<segment>-specs.md.
- Cross-segment invariants live ONLY here. If a "shared" rule appears in two LLDs, lift it up.
- This document is the cascade anchor: when intent changes, walk down from here.
-->
