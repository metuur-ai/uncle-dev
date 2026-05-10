# Segment Partitioning Examples

Strong vs weak segment selection across realistic products. Use these as patterns when you're scoping a new product or splitting/merging segments in an existing one.

## Why this matters

A segment is the unit of cascade in the spec graph. Strong segments make cascade fast and changes localized. Weak segments make every change cross boundaries and corrupt the graph over time.

The test for a good segment name: can a stakeholder who doesn't know the codebase tell you what behavior is in the segment from its name alone?

```
Good (passes the test):
  "auth" → login, logout, sessions, auth errors. Easy to guess.
  "billing" → invoices, subscriptions, refunds. Easy to guess.

Weak (fails the test):
  "utils" → ??? could be anything.
  "frontend" → too broad; what behavior?
  "shared" → admission of failure to scope.
```

---

## Example 1: SaaS web app

### Strong partition

| Segment | Prefix | Owns |
|---|---|---|
| `auth` | `AUTH-*` | Login, logout, session creation, auth errors |
| `accounts` | `ACCT-*` | Account creation, profile updates, account deletion |
| `billing` | `BILLING-*` | Plan selection, invoices, payment methods, refunds |
| `notifications` | `NOTIF-*` | Email, in-app, push delivery |
| `admin` | `ADMIN-*` | Internal admin tools, impersonation, support overrides |

Each segment is a product-behavior area a non-engineer can describe.

### Weak partition (anti-pattern)

| Segment | Why it's weak |
|---|---|
| `frontend` | "Every UI file." Says nothing about behavior. |
| `backend` | "Every server file." Same problem. |
| `services` | Implementation detail (microservices?), not user-facing behavior. |
| `shared` | The grab-bag. Whatever doesn't fit anywhere else lands here. |

The weak partition forces every cross-cutting change (e.g. login affecting both UI and API) to cross segment boundaries — every login change is a "boundary crossing" with no real meaning, because the segments don't reflect actual product structure.

---

## Example 2: E-commerce

### Strong partition

| Segment | Prefix | Owns |
|---|---|---|
| `catalog` | `CAT-*` | Product listing, search, browse, faceted filters |
| `cart` | `CART-*` | Add to cart, update quantities, persist cart across sessions |
| `checkout` | `CHK-*` | Address entry, payment selection, order placement |
| `orders` | `ORDER-*` | Order status, history, cancellations, returns |
| `inventory` | `INV-*` | Stock levels, reservations, restock workflows |

Note: `inventory` is a separate segment from `catalog` because they have different owners (operations vs merchandising) and different change frequencies.

### Borderline call: should `cart` and `checkout` merge?

They COULD merge into a single `purchase` segment. The right call depends on:
- Do they have the same owner? (If yes, lean toward merging.)
- Do they evolve at the same rate? (If yes, lean toward merging.)
- Is the cart used outside checkout? (If yes — wishlist, "save for later" — keep separate.)

When in doubt, start separate. Merging two segments later is easy (rename one, retire its prefix). Splitting one segment later is hard (you have to renumber IDs).

---

## Example 3: Marketing site + product app

### Strong partition

| Segment | Prefix | Owns |
|---|---|---|
| `mkt-site` | `MKT-SITE-*` | Public marketing pages, lead capture, blog |
| `auth` | `AUTH-*` | (App segment) login/logout |
| `dashboard` | `DASH-*` | (App segment) post-login user dashboard |

Note the compound prefix `MKT-SITE-*`. The marketing site is one product-behavior area (public marketing presence) but it's so different from the product app that it benefits from a long, distinguishing prefix.

### Anti-pattern: one big "frontend" segment

Putting marketing pages and the product app under one `frontend` segment forces every change to ask "is this a marketing change or a product change?" — but the segment name doesn't help you answer that. The split is in your head, not the graph.

---

## Example 4: Internal platform / API

### Strong partition

| Segment | Prefix | Owns |
|---|---|---|
| `ingest` | `INGEST-*` | Inbound event/data ingestion APIs |
| `pipeline` | `PIPE-*` | Stream processing, enrichment, routing |
| `egress` | `EGRESS-*` | Outbound API publishing, webhooks, exports |
| `admin-api` | `ADM-API-*` | Internal control-plane APIs |

For internal platforms, segments often map to data flow stages. Each stage has different owners, SLAs, and failure modes — perfect segment boundaries.

---

## When to split a segment (compound prefixes)

A segment grows large enough that one flat prefix becomes ambiguous. Promote to compound prefixes:

```
Before:
  auth segment, prefix AUTH-*
    AUTH-001 (UI login behavior)
    AUTH-002 (API endpoint behavior)
    AUTH-003 (session storage invariant)
    ...
    AUTH-073 (??? hard to find related behaviors)

After:
  auth segment, compound prefixes:
    AUTH-UI-*       (user-facing flows)
    AUTH-API-*      (controller / endpoint contracts)
    AUTH-SESSION-*  (session lifecycle invariants)
```

Old IDs (`AUTH-001`..`AUTH-073`) keep their meaning. New IDs use the compound prefix. The segment is still `auth`; the prefix is now a family.

**Don't** split a segment into multiple segments unless they have genuinely different owners or change-rates. Compound prefixes within one segment are usually enough.

## When to merge two segments

If you find yourself constantly making "boundary crossing" changes between segments A and B with no real owner difference, the segments are wrong. Merge them, retire one prefix, and document the rename in `docs/arrows/index.yaml`.

```
Before:
  cart-frontend segment    → CART-FE-*
  cart-backend segment     → CART-BE-*

  Every cart change crosses the boundary. There's no real "frontend cart owner"
  and "backend cart owner" — same team, same release cadence, same concerns.

After:
  cart segment             → CART-*
  CART-FE-001 retired (replaced by CART-001)
  CART-BE-001 retired (replaced by CART-002)
```

## Summary

| Heuristic | Strong segment | Weak segment |
|---|---|---|
| Stakeholder test | Non-engineer can describe it | Only an engineer knows what's in it |
| Boundary | Product-behavior area | File location |
| Owner | One team / one owner | Shared / no owner |
| Change rate | Coherent within segment | Independent of segment name |
| Prefix | Stable, distinct | Reused or arbitrary |
| Cascade | Local within segment | Crosses boundaries on every change |
