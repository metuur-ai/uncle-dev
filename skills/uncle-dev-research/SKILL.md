---
name: uncle-dev-research
description: Documents the codebase as it exists today by spawning parallel subagents to explore structure, patterns, and history, then writing a research document to .uncle-dev/research/. Use when starting work on an unfamiliar codebase, when you need to understand existing implementation before speccing a change, or when asked "how does X work?" about something in the repo.
---

# Codebase Research

## Overview

Comprehensive codebase documentation through parallel subagent exploration. This skill's only job is to describe what exists — not to evaluate it, improve it, or recommend changes.

**The documentarian mindset:** You are creating a technical map of the existing system. Document what exists, where it exists, how it works, and how components interact. Do not suggest improvements, perform root cause analysis, critique the implementation, or propose future enhancements unless the user explicitly asks for them.

When this skill is invoked, respond with:
```
I'm ready to research the codebase. What would you like me to investigate?
```
Then wait for the user's research question before proceeding.

## When to Use

- Starting work on an unfamiliar codebase or module
- Understanding existing implementation before writing a spec
- Answering "how does X work?" or "where is Y implemented?" questions
- Mapping component interactions and data flows
- Building shared context before a planning session

## When NOT to Use

- You need to suggest improvements → use `spec-driven-development` or `idea-refine`
- Something is broken → use `debugging-and-error-recovery`
- You need to document decisions made → use `documentation-and-adrs`
- You already understand the codebase well enough to start speccing → go directly to `spec-driven-development`

## Core Process

**Graphify availability check** — run once before Step 1:
```bash
[ -f graphify-out/graph.json ] && echo "graphify: ON" || echo "graphify: OFF — using standard search"
```
If OFF, skip all graphify sections below and proceed with the standard process.

### Step 1: Read directly mentioned files first

If the user references specific files (tickets, configs, docs), read them **fully** before spawning any subagents. Use the Read tool without limit or offset. Do this in the main context — not in a subagent — so you have full context before decomposing the research.

### Step 1.5: Graph-First Orientation

> Skip if availability check returned OFF.

Before decomposing the research question, run targeted graph queries to orient the investigation. This narrows Step 2 scope and pre-fills subagent prompts with relevant structural context.

```bash
# 1. Read architectural signals
# Read graphify-out/GRAPH_REPORT.md — note god nodes and community clusters related to the topic

# 2. If a specific concept name is known from Step 1 or the user's question:
graphify explain "<concept>"

# 3. If the question is open-ended:
graphify query "<research question>" --budget 1500

# 4. If two specific modules are mentioned:
graphify path "<module-A>" "<module-B>"
```

Use findings to:
- **Narrow Step 2 decomposition** — skip investigation areas the graph shows as unrelated to the topic
- **Pre-fill subagent context** — pass relevant graph nodes and relationships into each scout's prompt so they read the right files first
- **Detect god-node adjacency** — if the research topic touches a high-betweenness node, note it in the research plan (signals wider blast radius for a later spec or review)

If the graph returns empty or only AMBIGUOUS edges, proceed to Step 2 as if this step was skipped.

See `uncle-dev-graphify-aware-analysis` for command syntax, confidence interpretation, and fallback rules.

### Step 2: Decompose the research question

Break the user's query into composable investigation areas. For each area, identify:
- Which directories, files, or patterns are relevant
- What connections or interactions to document
- What the user is ultimately trying to understand

Create a brief research plan before spawning agents.

### Step 3: Spawn parallel subagents

Run multiple agents concurrently, each focused on a specific area. Two agent strategies:

**For full repository or unfamiliar codebase:** Spawn `uncle-dev-ag-repo-research-analyst` to produce a structured repo handoff document first, then spawn targeted scouts for specific questions. If the graph is ON, you may also spawn `uncle-dev-ag-graph-analyst` in background alongside the repo-research-analyst for multi-hop structural questions that would require many grep passes to answer manually.

**For targeted questions:** Spawn inline scout agents — one per investigation area — each with a focused read-only prompt. Each scout uses Glob, Grep, and Read tools to find and document what exists.

**For historical context:** Spawn a separate agent to search `.uncle-dev/learns/` for previously captured knowledge about the topic.

**Key instruction for all subagents:** "You are a documentarian, not an evaluator. Describe what exists. No recommendations, no critiques, no suggestions."

Do not write detailed prompts about *how* to search — the agents know their tools. Tell them *what* you are looking for.

### Step 4: Synthesize findings

Wait for **all** subagents to complete before synthesizing. Then:
- Treat live codebase findings as the primary source of truth
- Use `.uncle-dev/learns/` findings as supplementary historical context
- Connect findings across different components
- Include specific file paths and line numbers for reference
- Answer the user's specific question with concrete evidence

### Step 5: Write research document

Gather current git context (commit hash, branch, date) before writing. Save to `.uncle-dev/research/`:

**Filename:** `YYYY-MM-DD-[ticket]-description.md`
- With ticket: `2025-01-08-ENG-1478-parent-child-tracking.md`
- Without ticket: `2025-01-08-authentication-flow.md`

**Document structure:**
```markdown
---
date: [ISO timestamp with timezone]
git_commit: [current commit hash]
branch: [current branch]
repository: [repo name]
topic: "[user's question]"
tags: [research, codebase, relevant-component-names]
status: complete
---

# Research: [Topic]

**Date**: [date]
**Git Commit**: [hash]
**Branch**: [branch]

## Research Question
[Original user query]

## Summary
[High-level answer describing what was found]

## Detailed Findings

### [Component/Area 1]
- What exists: [description with file:line references]
- How it connects: [interactions with other components]
- Current implementation: [details without evaluation]

### [Component/Area 2]
...

## Code References
- `path/to/file.ts:123` — [what's there]
- `another/file.ts:45-67` — [what the code block does]

## Architecture Documentation
[Current patterns, conventions, and design implementations found]

## Historical Context
[Relevant insights from .uncle-dev/learns/ with file references]

## Open Questions
[Areas needing further investigation, if any]
```

### Step 6: Present findings

Present a concise summary to the user with key file references for easy navigation. Offer to answer follow-up questions.

### Step 7: Handle follow-up questions

Append follow-up research to the same document. Add a `## Follow-up Research [timestamp]` section and update the `date` field in frontmatter.

## Subagent Discipline

Every subagent prompt must include this instruction: **"Document what IS, not what SHOULD BE. No recommendations."**

Run subagents in background (`run_in_background: true`) when they are independent. Wait for all to complete before synthesizing — never write the research document with placeholder values.

## Common Rationalizations

| Rationalization | Reality |
|---|---|
| "I know this codebase well enough, I don't need to research" | Assumptions compound. A 15-minute research pass prevents hours of rework from wrong assumptions. |
| "I'll just start implementing and learn as I go" | You'll make architectural decisions without knowing what already exists. Research first, spec second. |
| "The research document takes too long to write" | The document is the deliverable. Without it, your findings evaporate when the session ends. |
| "I can just suggest improvements while I document" | The moment you switch from documentarian to evaluator, you stop seeing what exists and start seeing what you'd prefer. |

## Red Flags

- Writing the research document before all subagents complete (placeholders in the output)
- Subagents making recommendations instead of documenting what exists
- Skipping the `.uncle-dev/learns/` search (missing historical context that contradicts live findings)
- Research that covers code but misses documentation files (README, CLAUDE.md, AGENTS.md)
- Starting to spec or plan before the research question is fully answered

## Verification

After research is complete:

- [ ] Research document exists in `.uncle-dev/research/` with valid YAML frontmatter
- [ ] Document includes specific file:line references (not vague descriptions)
- [ ] Document contains no recommendations or improvement suggestions
- [ ] `.uncle-dev/learns/` was searched for historical context
- [ ] User's specific question is concretely answered in the Summary section
- [ ] Open questions are listed if areas remain uninvestigated
