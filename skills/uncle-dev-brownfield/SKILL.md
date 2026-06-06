---
name: uncle-dev-brownfield
description: Reverse-engineers LLD documents, EARS specs, and @spec annotations from an existing feature map. Runs a 5-agent swarm (segment mapper, behavior extractor, EARS writer, LLD synthesizer, source anchor) and writes docs/ artifacts that bring a brownfield codebase into the uncle-dev spec-driven workflow. Use when you have a feature map and want to establish the spec baseline for existing code before writing any new features.
---

# uncle-dev-brownfield

## Overview

Takes the output of `uncle-dev-feature-map` and reverse-engineers the full uncle-dev spec infrastructure for an existing codebase: segment boundaries, LLD documents, EARS specs with stable IDs, and `@spec` annotations on implemented entry points. The result is a brownfield codebase that behaves like a greenfield one — every implemented behavior is named, bounded, and traceable.

## When to Use

**Use when:**
- You have a feature map (from `uncle-dev-feature-map`) and want to spec what already exists
- Joining a brownfield codebase that has no LLDs, no EARS specs, and no `@spec` annotations
- A team is adopting the uncle-dev workflow mid-project and needs to establish a spec baseline
- You want to run `/uncle-dev-spec-scan` but the scanner has nothing to check yet

**Use AFTER** `uncle-dev-feature-map` — this skill consumes a feature map, it does not produce one. If no feature map exists, stop and run that skill first.

**When NOT to use:**
- You are speccing a net-new feature → use `uncle-dev-spec-driven-development`
- You need to understand how something is implemented → use `uncle-dev-research`
- The feature map doesn't yet exist → use `uncle-dev-feature-map` first

## Prerequisites

- A feature map saved at `.uncle-dev/feature-maps/*.md` with `### [Domain: …]` headers and feature tables
- `docs/arrows/index.yaml` may or may not exist; the skill creates or extends it
- `docs/llds/` and `docs/specs/` may or may not exist; the skill creates or extends them

## Process

### Step 0: Locate the feature map

Resolve the feature map path in order:
1. Use the path in `$ARGUMENTS` if provided
2. Pick the most recent file under `.uncle-dev/feature-maps/`
3. If none exists, stop and offer to run `/uncle-dev-feature-map`

Confirm the file has `### [Domain: …]` headers and `Feature | User Action | Backend Entry | Frontend Entry | Notes` tables before proceeding.

### Step 1: Dispatch the 5-agent swarm (parallel)

All five agents run **in a single message** — each reads the same feature map and outputs only (no file writes):

| Agent | Responsibility | Output |
|---|---|---|
| **Segment & Boundary Mapper** | Domain headers → segment names + prefixes; reconcile with existing `docs/arrows/index.yaml` | Segment table (REUSE/NEW), boundary-crossing list |
| **Behavior Extractor** | Every feature row → behavior candidates (happy-path + constraint); mines API-only, orphaned UI, open questions | Numbered behavior list by domain with evidence tags |
| **EARS Writer + ID Assigner** | One EARS line per behavior; assigns `SEGMENT-AREA-NNN` IDs; sets `[x]`/`[ ]`/`[D]` status | Ready-to-paste spec file content per segment |
| **LLD Synthesizer** | One LLD per segment from feature rows; follows `lld-template.md` if present | Fenced markdown blocks, one per `docs/llds/<segment>.md` |
| **Source Anchor + Annotation Generator** | Resolves backend/frontend entry points; emits diff-ready `@spec` comments; uses graphify if available | Per-file patch list; gaps flagged as NOT FOUND |

### Step 2: Reconcile in cascade order

After all five return:
1. **Lock segments + prefixes** from Agent 1 — surface boundary crossings to the user before writing anything
2. **Align IDs and LLDs** — apply Agent 1's final names to Agent 3's IDs and Agent 4's LLDs; resolve collisions
3. **Write docs, top-down** (confirm before overwriting existing files):
   - `docs/llds/<segment>.md`
   - `docs/specs/<segment>-specs.md` (with prefix header)
   - `docs/arrows/<segment>.md` + register in `docs/arrows/index.yaml` (status `PROPOSED`)
4. **Apply `@spec` annotations** from Agent 5 — only for `[x]` (implemented) specs; leave gaps untouched

### Step 3: Verify

```bash
/uncle-dev-spec-scan    # expect exit 0 — no ORPHAN, no MISSING TEST
/uncle-dev-spec-graph   # refresh docs/arrows/spec-graph.* with new state
```

Surface anything the scanner flags.

## Common Rationalizations

| Rationalization | Reality |
|---|---|
| "I can write specs directly from the code without the feature map" | The feature map forces product-language naming. Without it, IDs end up named after controllers, not user actions. |
| "I'll do segments and specs in one pass" | Segment boundaries must be locked before IDs are assigned — IDs that embed wrong prefixes create permanent debt. |
| "I'll write `@spec` for everything, including gaps" | Annotating gaps (`[ ]`/`[D]` specs) to code implies they're implemented. Only `[x]` specs get annotations. |
| "Existing `docs/` files don't need to be checked first" | Re-using an existing prefix for a new segment, or overwriting an existing LLD, creates silent conflicts. Always reconcile. |
| "I can run the agents sequentially to keep things simpler" | Sequential agents double the wall-clock time. All five agents read the same input — there is no dependency between them. |

## Red Flags

- Segment names that are file-location words (`frontend`, `backend`, `utils`, `shared`)
- Compound prefixes (`AUTH-UI-*`) added without verifying the domain truly mixes concerns
- `@spec` annotations placed on `[ ]` or `[D]` specs (implies unimplemented behavior is implemented)
- IDs assigned before segment names are locked (prefix drift)
- `docs/arrows/index.yaml` not updated — new segments must be registered, even as `PROPOSED`
- Boundary-crossing features silently split across two prefixes without user confirmation

## Verification

- [ ] Feature map confirmed to have `### [Domain: …]` headers and table structure
- [ ] Segment names are product-intent words, not file-location words
- [ ] Prefixes are registered in `docs/arrows/index.yaml` (REUSE or PROPOSED)
- [ ] All boundary-crossing features confirmed with the user before ID assignment
- [ ] `docs/llds/<segment>.md` exists for every segment
- [ ] `docs/specs/<segment>-specs.md` exists with a `prefix: SEGMENT-*` header
- [ ] `@spec` annotations applied only to `[x]` (implemented) specs
- [ ] `/uncle-dev-spec-scan` exits clean after writing
- [ ] `/uncle-dev-spec-graph` refreshed
