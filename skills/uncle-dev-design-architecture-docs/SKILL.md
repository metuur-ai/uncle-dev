> ## Documentation Index
> Fetch the complete documentation index at: https://agentskills.io/llms.txt
> Use this file to discover all available pages before exploring further.

---
name: uncle-dev-design-architecture-docs
description: Authors durable HLD and LLD documents that partition product intent into segments and feed EARS specs. Use when starting a new product, adding a new behavior segment, scoping segment boundaries, or when an LLD has drifted from its EARS specs.
---

# Design Architecture Docs (HLD / LLD)

## Overview

Architecture intent flows in one direction:

```
HLD ──▶ LLD ──▶ EARS specs ──▶ Tests ──▶ Code
```

This skill owns the upstream half — the HLD (product intent) and per-segment LLDs (system-level approach). The downstream half — EARS specs, tests, and code with `@spec` annotations — is owned by `uncle-dev-spec-annotations`.

A well-designed HLD/LLD pair makes the spec graph stable. A poorly-scoped one leaves segments fuzzy, prefixes overlapping, and EARS specs orphaned from intent.

## When to Use

- Starting a new product or service from scratch
- Adding a new behavior segment to an existing product (e.g., introducing `billing` alongside an existing `auth` segment)
- An LLD's behaviors no longer match its EARS specs (cascade drift)
- A segment has grown too large and needs to be split into sub-segments with compound prefixes
- Two segments are starting to share specs — boundaries need redrawing

**When NOT to use:** A single EARS spec needs to be added to an existing segment (just edit `docs/specs/<segment>-specs.md`), code-only refactors with no behavior change, or fixes to existing behavior.

## The Authorship Order

```
HLD                         (product intent — written first)
  │
  ▼
segment selection           (partition the HLD into product-behavior areas)
  │
  ▼
LLD per segment             (system-level approach for each segment)
  │
  ▼
EARS prefix per segment     (e.g. AUTH-* for the auth segment)
  │
  ▼
EARS specs                  (one durable behavior per spec, in docs/specs/<segment>-specs.md)
  │
  ▼
Tests with @spec
  │
  ▼
Code with @spec
```

The downstream half (EARS → Tests → Code) is owned by `uncle-dev-spec-annotations`. This skill owns the first three layers.

## Segment Selection Rules

A **segment** is one product-behavior area owned by one LLD. The segment is the unit of cascade — changes inside one segment move through that segment quickly; changes that cross segments must pause for confirmation.

### Choose by product intent, not file location

```
Good:
  auth = login, logout, sessions, auth errors
  billing = invoices, subscriptions, refunds
  search = query parsing, ranking, result rendering
  notifications = email, in-app, push delivery
  checkout = cart, payment, order confirmation

Weak:
  utils      ← describes file location, not behavior
  frontend   ← every UI file regardless of behavior
  backend    ← every server file regardless of behavior
  shared     ← grab-bag with no clear ownership
  misc       ← admission of failure to scope
```

A weak segment name is a signal that the segment hasn't been thought through. Push back on `utils`/`shared`/`misc` proposals — ask what product behavior the user is actually describing.

### Worked examples

See `resources/segment-examples.md` for full strong-vs-weak partitioning examples across realistic products.

### Boundary crossings

If a single change touches behavior in two segments, that's a boundary crossing. Pause and confirm before adding `@spec` annotations across the line, because:

- The two segments may have different owners
- The two segments may have unresolved design decisions
- A behavior that genuinely spans segments often signals the segments are wrong (e.g., should be merged, or there's a missing third segment that owns the boundary)

```
auth segment              billing segment
     │                          │
     ▼                          ▼
AUTH-* specs      ──×──▶  BILLING-* specs
        boundary crossing — pause and confirm
```

## Prefix Selection Rules

Each segment gets one stable prefix. The prefix is the segment's identity in code:

```
auth segment       → AUTH-*
billing segment    → BILLING-*
marketing site     → MKT-SITE-*
```

### Use compound prefixes for internal subdivisions

When a segment has genuinely separate internal areas (UI vs API vs persistence), use a compound prefix:

```
AUTH-UI-001        ← user-facing flows
AUTH-API-001       ← API/controller behavior
AUTH-SESSION-001   ← session lifecycle invariants
```

Don't compound prematurely. Start with a flat prefix; add compound segments only when a single segment legitimately needs sub-areas with their own concerns.

### Rules

- Prefixes are uppercase, dash-separated, end with the spec ID number (`AUTH-UI-001`)
- One prefix maps to one segment forever — never reuse a prefix for a different segment
- Two segments must not share a prefix
- A renamed segment keeps its old prefix (or gets a fresh prefix; old IDs are retired, never repurposed)

## HLD Template

See `resources/hld-template.md` for the canonical template. The HLD answers:

- What product is this?
- Who is it for?
- What are the durable principles (architectural commitments that won't change)?
- What segments compose it?
- What invariants cross segment boundaries?

The HLD is short. If it's longer than ~2 pages, you're probably writing an LLD or a PRD by mistake.

## LLD Template

See `resources/lld-template.md` for the canonical template. One LLD per segment. The LLD answers, for one segment:

- What behaviors does this segment own?
- What is the segment boundary? What does it explicitly NOT own?
- What are the key flows (user-visible or system-internal)?
- What is the EARS prefix for this segment?
- Where do the EARS specs live? (`docs/specs/<segment>-specs.md`)
- Where does the arrow doc live? (`docs/arrows/<segment>.md`)

The LLD is the place where system-level approach decisions belong. It is NOT the place for code-level details (that's per-feature design in OpenSpec change folders) and NOT the place for product narrative (that's the HLD).

## Cascade Rules

When intent changes, walk **down** the graph:

```
1. Update HLD or LLD (whichever changed)
2. Update affected EARS specs in docs/specs/<segment>-specs.md
3. Update tests with @spec annotations
4. Update code with @spec annotations
5. Run /uncle-dev-spec-scan to confirm coherence
6. Run /uncle-dev-spec-graph to refresh the graph artifact
```

When code changes first, walk **up** the graph:

```
1. Note the @spec ID(s) on the changed code
2. Read the matching EARS spec(s)
3. Confirm the spec still matches the LLD
4. Confirm the LLD still matches the HLD
5. If any layer is stale, update it before merging the code
```

If the code has no `@spec`, ask: "Is this implementing product behavior?"
- Yes → trace up to find the right segment, add the EARS spec, then the annotation
- No → no annotation needed (it's plumbing)

### Boundary-crossing changes

When a change crosses segment boundaries:

```
1. Pause. Surface the crossing to the human.
2. Confirm both segment owners are aware.
3. If the boundary is wrong, redraw it BEFORE annotating.
4. If the boundary is right, annotate each subsystem entry point in its own segment.
```

Never silently spread one behavior across two segment prefixes — that corrupts the graph and makes the cascade ambiguous.

## Common Rationalizations

| Rationalization | Reality |
|---|---|
| "We'll figure out segments later, after we have more code" | Segments shape the spec graph, which shapes how cascade works. Late segments mean a graph that has to be rebuilt and annotations that have to be rewritten. |
| "This `utils` module is fine as a segment" | `utils` is a file-location word, not a product-behavior word. Find the real behavior — likely it splits across two real segments and a true utility (which doesn't need a segment at all). |
| "Compound prefixes are over-engineering" | They're fine for small segments (`AUTH-*`). They become necessary when a single flat prefix can't distinguish UI from API from persistence concerns. Promote when needed. |
| "The HLD doesn't need to be written down — we all know the product" | The HLD is the anchor for cascade. If only one person knows the product intent, the cascade rule "update HLD first" silently breaks. |
| "Two segments sharing a prefix is fine if we keep them in sync" | They won't stay in sync. Shared prefix means corrupted segment ownership in the graph. |
| "I'll rename the segment but keep its old IDs alive" | Fine. IDs are immutable; segments are labels. The arrows index records the rename, the IDs keep meaning the same behavior. |

## Red Flags

- A single LLD spans unrelated behavior (e.g., one `system.md` LLD that owns auth, billing, and search)
- A segment named `utils`, `frontend`, `backend`, `misc`, or `shared`
- A prefix used by two different segments
- An LLD with no link to its EARS spec file or its arrow doc
- An EARS spec whose prefix doesn't match any registered segment in `docs/arrows/index.yaml`
- HLD changes landing without LLD/EARS/test/code follow-through
- Adding compound prefixes (`AUTH-UI-*`) before the simple prefix has felt cramped
- Reusing a deleted ID for new behavior

## Verification

Before the architecture is considered coherent:

- [ ] Every product behavior area has exactly one LLD in `docs/llds/`
- [ ] Every LLD links to its EARS spec file and its arrow doc
- [ ] Every spec file declares its segment prefix in the header
- [ ] Every segment in `docs/arrows/index.yaml` has a corresponding `docs/llds/<segment>.md` and `docs/specs/<segment>-specs.md`
- [ ] No two segments share a prefix
- [ ] No segment is named after a file location (`utils`, `frontend`, `backend`)
- [ ] The HLD lists every segment in `docs/arrows/index.yaml`
- [ ] Cross-segment invariants (if any) are stated in the HLD, not duplicated across LLDs

## Minimum Rules

If you adopt only the minimum:

1. One HLD per product, in `docs/high-level-design.md`
2. One LLD per behavior segment, in `docs/llds/<segment>.md`
3. Segments are named by product intent, not file location
4. Each segment owns one stable prefix
5. Cascade walks one direction at a time — down (intent first) or up (code first), never mixed
