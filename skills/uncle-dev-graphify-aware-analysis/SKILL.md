---
name: uncle-dev-graphify-aware-analysis
description: Shared protocol for querying the graphify semantic knowledge graph inside uncle-dev skills. Not invoked directly — referenced by research, spec, planning, debug, and review skills when graphify-out/graph.json is present. Defines availability check, command patterns, confidence interpretation, and fallback rules.
---

# Graphify-Aware Analysis Protocol

## Overview

Graphify builds a semantic knowledge graph from a codebase. Nodes represent concepts (modules, functions, patterns, docs). Edges carry typed relations — `calls`, `implements`, `references`, `conceptually_related_to`, `shares_data_with`, `semantically_similar_to`, `rationale_for` — and confidence levels. Hyperedges capture multi-node concepts not expressible as pairwise edges.

This protocol defines how uncle-dev skills interact with that graph: when to query it, which commands to use, how to interpret results, and when to fall back to grep/Read.

## Project-Level Availability Check

Every skill that uses graphify runs this check **once, at the start of the skill invocation**, before any step:

```bash
[ -f graphify-out/graph.json ] && echo "graphify: ON" || echo "graphify: OFF — using standard search"
```

- **ON** → graphify steps are active throughout the skill run
- **OFF** → skip every graphify section; proceed with the skill's standard grep/Glob/Read process

If `graph.json` exists but `graphify-out/GRAPH_REPORT.md` is missing, run `graphify update .` once before querying — the report is generated during the build and is required for architectural signal reading.

Do not repeat the check per-step. The result set at skill start applies to the entire session.

## Command Reference

### `graphify explain "<node>"`

Plain-language explanation of one concept node plus all its direct neighbors in every direction.

**When to use:** You have a specific concept name and want to understand its full structural neighborhood — what it calls, what calls it, what it shares data with, what it implements.

```bash
graphify explain "AuthMiddleware"
graphify explain "PaymentService"
```

### `graphify path "A" "B"`

Shortest path through the graph between two known concept nodes. Reveals the dependency chain connecting them.

**When to use:** Tracing how module A reaches module B; validating an assumed dependency; finding cross-layer coupling.

```bash
graphify path "UserService" "BillingController"
graphify path "failing-ui-component" "suspected-api-module"
```

### `graphify query "<natural language question>"`

BFS traversal starting from semantically matched nodes. Best for open-ended questions when you don't have exact node names.

**Flags:**
- `--dfs` — depth-first; better when you want to go deep into one branch rather than broad
- `--budget N` — cap output tokens (default 2000; use `--budget 500` for a spot-check, `--budget 1500` for research contexts)

**When to use:** You have a question but not a specific node name; impact analysis; finding "what else touches this area."

```bash
graphify query "how does payment processing connect to order fulfillment" --budget 1500
graphify query "what depends on SessionManager"
graphify query "concepts similar to UserAuthHandler"
```

### `graphify update <path>`

Incremental rebuild of the graph from code changes. AST-only; no LLM call required.

**When to use:** After significant code changes in the current session when the graph may be stale.

```bash
graphify update src/
graphify update .
```

## Reading GRAPH_REPORT.md

Before any targeted query, read `graphify-out/GRAPH_REPORT.md` for architectural signals:

| Section | What it contains | How to use it |
|---|---|---|
| **God nodes** | Highest-betweenness nodes — architectural chokepoints | Any change touching a god node has outsized blast radius; flag it early in planning and review |
| **Community structure** | Logical clusters of related concepts | Use clusters to scope "what else is affected?" and to identify natural story boundaries |
| **Surprising connections** | Semantically linked nodes in different layers | Signals hidden coupling the author may not know about |
| **Suggested questions** | Questions the graph's own structure surfaced | Starting points for research and review traversal |

## Confidence Level Decision Table

Every graph edge carries a confidence level. Use it to decide how much to trust the finding before acting.

| Confidence | Score | Meaning | Action |
|---|---|---|---|
| `EXTRACTED` | 1.0 | Explicit in source code — direct AST relationship | Treat as ground truth; no secondary verification needed |
| `INFERRED` | 0.6–0.9 | Derived by semantic analysis; reasonable but not explicit | Verify with grep/Read before using as basis for a story, bug fix, or review block |
| `AMBIGUOUS` | 0.1–0.3 | Weak signal; uncertain relationship | Ignore during debugging; flag as hypothesis in review; never block a PR on this alone |

Never file a bug, scope a story, or block a merge on AMBIGUOUS edges alone.

## Augments vs Replaces

| Situation | Action |
|---|---|
| `graphify-out/graph.json` not found | Skip all graphify steps; use standard grep/Read |
| Graph found, query returns empty | Fall back to grep/Read; treat as no signal for this area |
| Graph found, result has only AMBIGUOUS edges | Confirm with grep/Read before acting |
| Graph found, result has EXTRACTED edges | Trust and act; no secondary check required |
| Graph found, node name not in graph | Run `graphify query` with a description instead of the exact name |
| Graph found, GRAPH_REPORT.md missing | Run `graphify update .` once, then query |

## Hyperedges: When to Use Them

Hyperedges are different from pairwise edges. A pairwise edge says "A calls B". A hyperedge says "A, B, C, D all participate in the checkout flow" — it captures **named group membership**, not a bilateral relationship.

They are stored in `graphify-out/graph.json` under the `hyperedges` array. The CLI (`query`, `explain`, `path`) does **not** traverse them — you must read `graph.json` directly.

```bash
# Find all hyperedges containing a specific module
python3 -c "
import json
g = json.load(open('graphify-out/graph.json'))
module = 'PaymentService'
matches = [h for h in g.get('hyperedges', []) if module in h['nodes']]
for h in matches:
    print(h['label'], '->', h['nodes'])
"
```

### Use hyperedges when:

| Question | Why hyperedges help |
|---|---|
| **"Which named flow does this module belong to?"** | A hyperedge labels the flow and lists all its co-participants — impossible to derive from pairwise traversal |
| **Planning story boundaries** | Hyperedges often map directly to story-sized named concepts (e.g. "user onboarding flow" = exact story scope) |
| **Debug: module has few pairwise neighbors but feels central** | It may belong to a cross-cutting hyperedge (event pipeline, caching layer) that pairwise edges don't surface |
| **Spec: "what exactly participates in this feature?"** | Hyperedge membership gives a precise list; `graphify query` gives a fuzzy BFS neighborhood |

### Do NOT use hyperedges when:

| Question | Use instead |
|---|---|
| **"How does A reach B?"** — dependency direction matters | `graphify path "A" "B"` — hyperedges are undirected group membership, not directed call chains |
| **"What calls X?"** — caller lookup | `graphify query "what calls X"` — that's a pairwise `calls` edge question |
| **Quick spot-check during research** | CLI query — reading and parsing `graph.json` is heavier; not worth it for orientation queries |
| **Code-only corpus with no docs or papers** | Hyperedges are sparse in code-only graphs; the extraction LLM produces fewer group-level concepts without prose context. Check `len(g['hyperedges'])` first — if < 5, skip |
| **You need confidence scores on relationships** | Pairwise edges carry per-edge confidence; hyperedges carry a single score for the whole group |

### Density check before using hyperedges

Before reading hyperedges in any skill, check whether the graph has enough to be useful:

```bash
python3 -c "
import json
g = json.load(open('graphify-out/graph.json'))
n = len(g.get('hyperedges', []))
print(f'hyperedges: {n}')
print('use hyperedges: ' + ('yes' if n >= 5 else 'no — too sparse, use CLI queries instead'))
"
```

If the count is < 5, fall back to `graphify query` and community structure from GRAPH_REPORT.md.

## Anti-Patterns

- Running graphify on every subagent prompt — expensive; only the orchestrating skill or the `uncle-dev-ag-graph-analyst` subagent should run queries
- Treating INFERRED edges as confirmed facts without source verification
- Skipping GRAPH_REPORT.md god-node check before reviewing a large change
- Running only one query and treating it as complete coverage — triangulate with 2–3 targeted queries for important decisions
- Forgetting to fall back to grep/Read when graph returns no signal

## When to Spawn uncle-dev-ag-graph-analyst

For multi-hop traversal needs (more than 2–3 queries, cross-community analysis, or impact scoping across many modules), spawn the `uncle-dev-ag-graph-analyst` subagent rather than running queries inline. Pass it the question and any known focus nodes. It will run up to 5 targeted queries, annotate confidence levels, and return a structured handoff.

Spawn it in background alongside other parallel agents; wait for its result before synthesizing.
