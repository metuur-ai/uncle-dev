---
name: uncle-dev-ubiquitous-language
description: >
  Builds and maintains a DDD-style ubiquitous language — a glossary of canonical domain
  terms — by scanning the codebase and/or the current conversation, flagging ambiguities
  and synonyms, and writing them to docs/ubiquitous-language.md. Use when starting a new
  domain, when the agent and user keep talking past each other, when terms drift or the
  same word means two things, before writing a spec or PRD, or when the user mentions
  "domain model", "DDD", "glossary", "terminology", or "ubiquitous language".
---
## Overview

A ubiquitous language is a single, shared vocabulary for the domain — used identically in conversation, specs, PRDs, and code. Without it, the human and the AI talk past each other: the same word means two things, two words mean the same thing, and the agent generates verbose code that drifts from the intended model. This skill extracts that vocabulary into a maintained `docs/ubiquitous-language.md`, then feeds it into planning so every downstream artifact speaks the same language.

Why this matters more with AI: an agent has no implicit shared context with you. It will happily invent "account" for what you call "customer" and "user" interchangeably. A canonical glossary, loaded as context during specs and planning, makes the agent think in your terms and produces code that aligns with the model you planned.

## Modes

Pick based on what exists:

| Mode | Source | Use when |
|---|---|---|
| Codebase-scan | Existing source code | A codebase exists; you want terms grounded in what's already built |
| Conversation | The active discussion | Greenfield, or refining terms mid-design before code exists |

Run both when refining an existing system from a new discussion — scan first, then layer in conversation terms.

## Process

### 1. Choose the output location

Default: `docs/ubiquitous-language.md`. If the project has no `docs/` tree (common in OpenSpec projects), use `.uncle-dev/ubiquitous-language.md`. If a glossary file already exists, read it first and update in place — never silently overwrite curated terms.

### 2. Gather candidate terms

Codebase-scan mode — prefer the cheapest high-signal source first:

```bash
# If a graphify knowledge graph exists, god nodes + communities ARE your domain terms:
[ -f graphify-out/graph.json ] && echo "graphify: ON" || echo "graphify: OFF"
# ON  → read graphify-out/GRAPH_REPORT.md (god nodes = central domain entities;
#       communities = subdomains), and: graphify query "core domain entities and their relationships"
# OFF → ripgrep for recurring domain nouns/verbs:
#       entity/model names, service names, enum/state values, event names, aggregate roots
rg -o '\b[A-Z][a-zA-Z]+(Service|Repository|Aggregate|Event|Command|Status|State)\b' --no-filename -t ts -t js | sort | uniq -c | sort -rn | head -40
```

Cluster the survivors by subdomain (e.g. `Order lifecycle`, `Billing`, `Identity`). Skip framework/infra names that carry no domain meaning.

Conversation mode — extract domain-relevant nouns, verbs, and concepts from the active discussion.

### 3. Identify problems

- Ambiguity: one word, two concepts (e.g. "account" = both Customer and User)
- Synonyms: two words, one concept (e.g. "buyer" / "client" / "customer")
- Vague/overloaded terms: words that mean nothing precise

### 4. Propose a canonical glossary (be opinionated)

When several words exist for one concept, pick the best one and list the rest as aliases to avoid. Write the file using the format below.

### 5. Validate → fix → re-validate

After writing, confirm against the Verification checklist. If a term is still ambiguous or a synonym remains unresolved, fix the entry and re-check. Do not declare done until every flagged ambiguity has a recommendation.

## Output Format

```md
# Ubiquitous Language

## Order lifecycle

| Term        | Definition                                              | Aliases to avoid      |
| ----------- | ------------------------------------------------------- | --------------------- |
| **Order**   | A customer's request to purchase one or more items      | Purchase, transaction |
| **Invoice** | A request for payment sent to a customer after delivery | Bill, payment request |

## People

| Term         | Definition                                  | Aliases to avoid       |
| ------------ | ------------------------------------------- | ---------------------- |
| **Customer** | A person or organization that places orders | Client, buyer, account |
| **User**     | An authentication identity in the system    | Login, account         |

## Relationships

- An **Invoice** belongs to exactly one **Customer**
- An **Order** produces one or more **Invoices**

## Example dialogue

> **Dev:** "When a **Customer** places an **Order**, do we create the **Invoice** immediately?"
> **Domain expert:** "No — an **Invoice** is only generated once a **Fulfillment** is confirmed. A single **Order** can produce multiple **Invoices** if items ship in separate **Shipments**."
> **Dev:** "So if a **Shipment** is cancelled before dispatch, no **Invoice** exists for it?"
> **Domain expert:** "Exactly. The **Invoice** lifecycle is tied to the **Fulfillment**, not the **Order**."

## Flagged ambiguities

- "account" was used to mean both **Customer** and **User** — distinct concepts: a **Customer** places orders, a **User** is an authentication identity that may or may not represent a Customer.
```

## Feeding the glossary downstream (the point of doing this)

A glossary nobody reads is dead weight. Wire it in:

- Spec / PRD: before writing, load `docs/ubiquitous-language.md` and use its canonical terms throughout. `uncle-dev-spec-driven-development` and the PRD flow read it when present.
- Planning: `uncle-dev-planning-and-task-breakdown` checks tasks against the glossary and flags any new term not yet defined.
- Review: code review may flag identifiers that contradict the glossary (a `Buyer` class where the canon is `Customer`).

## Rules

- Be opinionated. One canonical term per concept; everything else is an alias to avoid.
- Flag conflicts explicitly. Every ambiguous term gets a "Flagged ambiguities" entry with a recommendation.
- Keep definitions tight. One sentence. Define what it IS, not what it does.
- Domain terms only. Skip generic programming concepts unless they carry domain-specific meaning.
- Group into tables by subdomain/lifecycle/actor when natural clusters emerge; one table is fine for a single cohesive domain.
- Always write an example dialogue (3–5 exchanges) showing the terms used precisely and clarifying boundaries between related concepts.

## Common Rationalizations

| Rationalization | Reality |
|---|---|
| "We all know what an order is" | You do; the agent doesn't, and your synonyms drift. The whole point is removing the implicit shared context the AI lacks. |
| "The code names already document the terms" | Code names mix domain and infrastructure, and contradict each other across modules. A canon resolves the conflict. |
| "It's just a glossary, skip the dialogue" | The dialogue is where boundaries between adjacent terms (Order vs Invoice vs Fulfillment) become precise. Tables alone hide overlaps. |
| "We'll align terminology later" | Every spec and PR written before alignment bakes in the wrong words, multiplying the rename cost. Align before the first spec. |

## Red Flags

- The same word appears with two meanings in spec, code, or conversation, and no ambiguity is flagged
- The glossary exists but no spec or PRD references it
- New domain terms appear in code that aren't in the glossary
- Definitions describe behavior ("Order processes payments") instead of identity ("Order is a customer's request to purchase")
- Aliases-to-avoid column is empty when synonyms demonstrably exist in the codebase

## Verification

After running the skill, confirm:

- [ ] `docs/ubiquitous-language.md` (or `.uncle-dev/` fallback) exists and is grouped by subdomain
- [ ] Every concept has exactly one canonical term; synonyms are listed as aliases to avoid
- [ ] Every ambiguity found is in "Flagged ambiguities" with a concrete recommendation
- [ ] An example dialogue demonstrates the terms used precisely
- [ ] The terms appear (and conflicting synonyms do not) in the most recent spec/PRD
- [ ] If a glossary already existed, it was updated in place, not overwritten

## Re-running

When invoked again:

1. Read the existing glossary file
2. Incorporate new terms from subsequent code or discussion
3. Update definitions if understanding evolved
4. Re-flag any new ambiguities
5. Rewrite the example dialogue to include the new terms
