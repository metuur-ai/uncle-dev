# Research: intent-layer skill content vs. uncle-dev context engineering skills

**Date:** 2026-05-28  
**Source skill:** `/Users/javierbenavides/Downloads/skills-main/context-engineering/intent-layer/`  
**Target skills:** `skills/uncle-dev-context-engineering/SKILL.md`, `skills/uncle-dev-code-context/SKILL.md`

---

## What the intent-layer skill is

A concrete, operational skill for setting up hierarchical `AGENTS.md` context files in codebases. It covers detection, measurement, setup, and maintenance of a layered documentation hierarchy. Authored by Railly Hugo / Crafter Station, built on Tyler Brandt's "The Intent Layer" concept.

**Files:**
- `SKILL.md` — main workflow (6 steps: detect → measure → decide → execute → maintain)
- `references/templates.md` — root and child node templates
- `references/node-examples.md` — before/after compression examples
- `references/capture-protocol.md` — SME interview questions for knowledge capture
- `scripts/detect_state.sh` — returns `none | partial | complete` for a given repo path
- `scripts/analyze_structure.sh` — finds semantic boundaries (directories with distinct responsibilities)
- `scripts/estimate_tokens.sh` — measures token count per directory

---

## What uncle-dev context skills currently cover

### `uncle-dev-context-engineering` (`SKILL.md:1-291`)

Strategic/conceptual skill. Covers:
- 5-level context hierarchy (rules files → specs → source files → error output → conversation)
- Context packing strategies: Brain Dump, Selective Include, Hierarchical Summary
- MCP integrations table
- Confusion management patterns (conflict surfacing, missing requirement protocol)
- Anti-patterns table (context starvation, context flooding, stale context, missing examples)
- Common rationalizations and red flags

Does NOT cover: how to create AGENTS.md nodes, when to create them, how to measure directories, how to capture knowledge from an SME into a node.

### `uncle-dev-code-context` (`SKILL.md:1-60`)

Operational enforcement skill. Covers:
- Mandatory workflow: read AGENTS.md before editing, update after structural changes
- Stop conditions for when to halt and fix context first
- Execution checklist (4 items)

Does NOT cover: criteria for when to create a new AGENTS.md, what to put in one, how to measure whether one is needed.

---

## What intent-layer has that uncle-dev lacks

### 1. Measurement tooling and token thresholds

`estimate_tokens.sh` + the measurement table in `templates.md:50-63`:

| Directory tokens | Action |
|---|---|
| <20k | No node needed |
| 20–64k | Create 2–3k token node |
| >64k | Split into multiple child nodes |

`uncle-dev-code-context:27` says "if AGENTS.md does not exist and the directory contains source files, create documentation context first" — but gives no criterion for when a node is warranted. The token-threshold table fills this gap.

### 2. The detect/analyze workflow

`detect_state.sh` returns `none | partial | complete` before any work begins. This maps directly to a routing decision: first-time setup vs. maintenance. Neither uncle-dev skill has a state detection step.

### 3. Only-one-root-file constraint

`SKILL.md:16`: "CLAUDE.md and AGENTS.md should NOT coexist at project root." This is an explicit invariant not present in any uncle-dev skill.

### 4. Child node template with concrete sections

`templates.md:21-51` specifies these sections for every child AGENTS.md:
- **Purpose** (owns / does NOT own)
- **Entry Points** (primary API surface, CLI commands)
- **Contracts & Invariants** (what must go through which module)
- **Patterns** (numbered steps for common tasks)
- **Anti-patterns** (from real experience, not hypothetical)
- **Related Context** (relative paths to sibling AGENTS.md nodes)

`uncle-dev-context-engineering:43-77` shows a CLAUDE.md template with tech stack + commands + conventions + boundaries — oriented toward project-wide rules, not subsystem-local context.

### 5. Capture protocol (SME interview questions)

`capture-protocol.md` provides 12 questions across 5 categories (Purpose & Scope, Entry Points, Contracts & Invariants, Patterns, Anti-patterns + Pitfalls). Also defines leaf-first capture order and parent-node summarization rules.

No equivalent exists in uncle-dev. `uncle-dev-knowledge-capture` exists but focuses on lessons-learned, not live documentation extraction.

### 6. Node quality checklist

`capture-protocol.md:55-63`:
- < 4k tokens per node
- Purpose statement in first 2 lines
- Contracts are explicit (not "handle carefully")
- Anti-patterns from real experience, not hypothetical
- Downlinks use relative paths
- No duplication with ancestor nodes

`uncle-dev-code-context:49-54` has a 4-item checklist but no quality constraints on the content of the node itself.

### 7. Compression examples with before/after

`node-examples.md:72-113`: shows a ~800-token node compressed to ~250 tokens. Demonstrates that verbose prose ("The User Service is a microservice responsible for...") should be replaced with compressed, assumption-heavy format.

No equivalent exists in uncle-dev. The current skills show templates but not how to compress an over-verbose node.

### 8. Downlink navigation pattern

`node-examples.md:116-121` and `templates.md:44-47`: child nodes must include **Related Context** pointers using relative paths to sibling/parent AGENTS.md nodes. This creates a traversable graph of context files.

`uncle-dev-code-context` reads AGENTS.md but doesn't enforce or produce downlinks.

---

## What uncle-dev has that intent-layer does not

- Full 5-level context hierarchy (intent-layer only covers Level 1: rules files)
- Session-level context management (switching tasks, compacting conversations)
- MCP integrations
- Confusion management patterns for ambiguous requirements
- Anti-patterns at the conversation/session level
- Connection to the broader uncle-dev skill pipeline (spec → plan → build)

---

## Structural mapping

| Concept | intent-layer location | uncle-dev location |
|---|---|---|
| Rules file template | `templates.md:4-17` (root node) | `SKILL.md:43-77` (CLAUDE.md template) |
| Child node template | `templates.md:21-51` | missing |
| Token measurement | `scripts/estimate_tokens.sh`, `templates.md:50-63` | missing |
| State detection | `scripts/detect_state.sh` | missing |
| SME capture protocol | `capture-protocol.md` | missing |
| Node quality checklist | `capture-protocol.md:55-63` | partial (`uncle-dev-code-context:49-54`) |
| Pre-edit read enforcement | missing | `uncle-dev-code-context:18-27` |
| Compression examples | `node-examples.md:72-113` | missing |
| Downlink pattern | `node-examples.md:116-121` | missing |
| One-root constraint | `SKILL.md:16` | missing |

---

## Specific improvement areas in uncle-dev skills

### A. `uncle-dev-code-context` — add creation criteria

Currently says "create documentation context first" without saying when or what to put in it. The token-threshold table (lines 50-63 in intent-layer `templates.md`) and the child node template (lines 21-51) directly fill this.

**Location:** `skills/uncle-dev-code-context/SKILL.md:26-28`

### B. `uncle-dev-code-context` — add node quality checklist items

The 4-item execution checklist at `SKILL.md:49-54` could be extended with the 6 node quality checks from `capture-protocol.md:55-63`.

### C. `uncle-dev-context-engineering` — add Intent Layer Setup section

The skill covers what to put in a CLAUDE.md but has no section for hierarchical setup. A new section between "Level 1: Rules Files" and "Level 2: Specs" could describe the detect → measure → decide → execute workflow.

**Location:** between `SKILL.md:38` and `SKILL.md:82`

### D. `uncle-dev-context-engineering` — add one-root constraint

The explicit invariant "CLAUDE.md and AGENTS.md must not coexist at root" is not in either skill. Should be added to the Rules Files section.

### E. New supporting reference file for `uncle-dev-code-context`

The capture protocol questions + compression example + node template combined are ~150 lines — above the 100-line threshold for creating a reference file. Could be `skills/uncle-dev-code-context/agents-md-guide.md`.

---

## Raw file references

| File | Key lines | Content |
|---|---|---|
| intent-layer `SKILL.md` | 16 | one-root constraint |
| intent-layer `SKILL.md` | 26-46 | 6-step workflow |
| intent-layer `SKILL.md` | 49-58 | when to create child nodes table |
| intent-layer `templates.md` | 4-17 | root context template |
| intent-layer `templates.md` | 21-51 | child node template |
| intent-layer `templates.md` | 50-63 | token thresholds table |
| intent-layer `node-examples.md` | 72-113 | compression before/after |
| intent-layer `node-examples.md` | 116-121 | 5 key principles |
| intent-layer `capture-protocol.md` | 1-43 | capture order + SME questions |
| intent-layer `capture-protocol.md` | 55-63 | quality checklist |
| uncle-dev-context-engineering `SKILL.md` | 38-80 | Level 1 rules files section |
| uncle-dev-code-context `SKILL.md` | 26-28 | "create context first" (no criteria) |
| uncle-dev-code-context `SKILL.md` | 49-54 | execution checklist |
