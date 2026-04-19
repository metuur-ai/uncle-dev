---
name: uncle-dev-knowledge-capture
description: Captures recently solved problems as searchable documentation in .uncle-dev/learns/, compounding team knowledge over time. Coordinates parallel subagents to research context, extract solutions, find related docs, and assemble one structured file. Use when a problem has just been solved, when you hear "that worked", "it's fixed", "working now", or "problem solved", or when the user runs /uncle-dev-knowledge-capture or wants to document a recent debugging session.
---

# Knowledge Capture

## Overview

Each documented solution compounds team knowledge. The first time you solve a problem takes research.
Document it, and the next occurrence takes minutes. This skill coordinates parallel subagents to
capture the solution while context is fresh, then writes one structured file into `.uncle-dev/learns/`.

## When to Use

**Use when:**
- A problem has just been solved and verified working
- You hear "that worked", "it's fixed", "working now", or "problem solved"
- The user runs `/uncle-dev-knowledge-capture`
- A debugging session concluded with a working fix

**NOT for:**
- Problems still being actively debugged
- Trivial fixes (typos, obvious one-liner errors)
- Architectural decisions — use `documentation-and-adrs` for those
- Documenting features proactively before any problem occurred

## Core Process

### Step 0: Mode Selection

Present the user with two options using the platform's blocking question tool (`AskUserQuestion`
in Claude Code, `request_user_input` in Codex, `ask_user` in Gemini). Wait for the user's choice
before proceeding. Do NOT pre-select a mode.

```
1. Full (recommended) — parallel subagents research context, cross-reference existing docs, and
   surface prior session history. Produces the richest documentation and catches duplicates.

2. Lightweight — single-pass documentation. Faster and token-efficient. Skips duplicate detection
   and cross-references. Best for simple fixes or sessions nearing context limits.
```

If the user chooses **Full**, ask one follow-up question: whether to search session history for
relevant prior context. If yes, dispatch the Session Historian in Step 2. If no, skip it.

### Step 1: Auto Memory Scan (Full mode only)

Before launching subagents, check the "user's auto-memory" block in your system prompt for entries
relevant to the problem being documented. If Claude Code is not the platform or the block is absent,
skip this step.

If relevant entries are found, prepare a labeled excerpt:

```
## Supplementary notes from auto memory
Treat as additional context, not primary evidence. Conversation history and codebase findings
take priority. If memory notes contradict the conversation, note the contradiction.

[relevant entries here]
```

Pass this excerpt to the Context Analyzer and Solution Extractor in Step 2. Tag any memory-sourced
content that ends up in the final doc with "(auto memory [claude])".

### Step 2: Research

**Full mode — dispatch in parallel (background):**

#### Context Analyzer
- Reads conversation history to identify the problem and its context
- Reads `solution-schema.yaml` in this skill directory for enum validation and track classification
- Determines the track (bug or knowledge) from the `problem_type`
- Uses the Category Mapping table in the **Specific Techniques** section to map `problem_type` to a
  `.uncle-dev/learns/` subdirectory
- Suggests a filename: `[sanitized-problem-slug]-[date].md`
- Incorporates auto memory excerpts if provided by the orchestrator
- Returns: YAML frontmatter skeleton (with `category:` field), category directory path, filename, track
- Does not invent enum values or categories from memory — reads the schema file

#### Solution Extractor
- Reads `solution-schema.yaml` in this skill directory for track classification
- Adapts output based on track:
  - **Bug track:** Problem, Symptoms, What Didn't Work, Solution, Why This Works, Prevention
  - **Knowledge track:** Context, Guidance, Why This Matters, When to Apply, Examples
- Incorporates auto memory excerpts if provided; tags memory-sourced content "(auto memory [claude])"
- Returns: structured content sections with code examples

#### Related Docs Finder
- Searches `.uncle-dev/learns/` for related documentation using grep-first filtering (see Specific Techniques)
- Assesses overlap with the new doc across five dimensions: problem statement, root cause, solution
  approach, referenced files, prevention rules
- Scores overlap: **High** (4-5 dimensions), **Moderate** (2-3), **Low** (0-1)
- Returns: related links, overlap score, matched dimensions, stale candidate flags

**Then dispatch in foreground (after background agents launch, only if user opted in):**

#### Session Historian
Dispatched as `compound-engineering:research:session-historian` on mid-tier model.
Searches prior sessions in `~/.claude/projects/`, `~/.codex/sessions/`, `~/.cursor/projects/`.

Include in the dispatch prompt:
- A specific description of the problem (error messages, module names, what broke and how it was fixed)
- Current git branch and working directory
- "Only surface findings directly relevant to this specific problem. Ignore unrelated work."
- Output format: What was tried before / What didn't work / Key decisions / Related context

**Lightweight mode:** The orchestrator performs all research in a single sequential pass (no
subagents). Reads `solution-schema.yaml`, classifies the problem using the Category Mapping table,
extracts solution from conversation history. Incorporates any relevant auto memory as supplementary
context. Does not search `.uncle-dev/learns/` for duplicates.

### Step 3: Assembly

**WAIT for all Step 2 subagents to complete before proceeding.**

The orchestrator performs all steps below. Subagents return text data only — they MUST NOT write files.

1. **Check overlap assessment** from Related Docs Finder:

   | Overlap | Action |
   |---------|--------|
   | **High** (4-5 dimensions) | Update the existing doc. Preserve its path. Add `last_updated: YYYY-MM-DD` to frontmatter. |
   | **Moderate** (2-3) | Create new doc. Flag for `uncle-dev-knowledge-maintenance` review. |
   | **Low / none** | Create new doc normally. |

   When updating: preserve path and structure; update solution, code examples, prevention tips, stale
   references. Do not change the title unless the problem framing materially shifted.

2. **Incorporate session history** (if available): fold failed attempts into **What Didn't Work** (bug)
   or **Context** (knowledge). Tag session-sourced content with "(session history)".

3. **Assemble** from collected pieces using the Resolution Templates in the **Specific Techniques** section.

4. **Validate** YAML frontmatter against `solution-schema.yaml` — all required fields present, enum
   values match exactly.

5. **Create directory** if needed: `mkdir -p .uncle-dev/learns/[category]/`

6. **Write one file:** `.uncle-dev/learns/[category]/[filename].md` (new) or the existing doc (update).

### Step 4: Selective Maintenance Check

After writing, decide whether to invoke `uncle-dev-knowledge-maintenance`:

**Invoke when:**
- A related learning recommends an approach the new fix now contradicts
- The new fix clearly supersedes an older documented solution
- Work involved a refactor, migration, rename, or dependency upgrade
- Related Docs Finder surfaced high-confidence stale candidates
- Related Docs Finder reported moderate overlap (potential consolidation)

**Skip when:**
- No related docs were found
- Related docs remain consistent with the new learning
- Context is tight (recommend `/uncle-dev-knowledge-maintenance <scope>` as the next step instead)

When invoking, pass the narrowest useful scope argument:
- `/uncle-dev-knowledge-maintenance plugin-versioning` — specific file or topic
- `/uncle-dev-knowledge-maintenance payments` — module name
- `/uncle-dev-knowledge-maintenance performance-issues` — category directory

### Step 5: Discoverability Check

Read and follow `discoverability-check.md` in this skill directory.

In lightweight mode, skip the consent step (step 4c) and output a one-liner tip instead.

### Step 6: Specialized Reviews (Full mode, optional)

Based on problem type, optionally invoke:
- `performance_issue` → `compound-engineering:review:performance-oracle`
- `security_issue` → `compound-engineering:review:security-sentinel`
- `database_issue` → `compound-engineering:review:data-integrity-guardian`
- Any issue with code snippets in more than two sections → `compound-engineering:review:code-simplicity-reviewer`, plus stack reviewer: Rails → `kieran-rails-reviewer`, Python → `kieran-python-reviewer`, TypeScript → `kieran-typescript-reviewer`

Skip in lightweight mode.

## Specific Techniques

### Category Mapping

Map `problem_type` to the target `.uncle-dev/learns/` subdirectory:

| `problem_type` | Directory |
|---|---|
| `build_error` | `build-errors/` |
| `test_failure` | `test-failures/` |
| `runtime_error` | `runtime-errors/` |
| `performance_issue` | `performance-issues/` |
| `database_issue` | `database-issues/` |
| `security_issue` | `security-issues/` |
| `ui_bug` | `ui-bugs/` |
| `integration_issue` | `integration-issues/` |
| `logic_error` | `logic-errors/` |
| `developer_experience` | `developer-experience/` |
| `workflow_issue` | `workflow-issues/` |
| `best_practice` | `best-practices/` |
| `documentation_gap` | `documentation-gaps/` |

### Resolution Templates

Use the template matching the track when assembling the final doc.

**Bug Track** (`build_error`, `test_failure`, `runtime_error`, `performance_issue`, `database_issue`, `security_issue`, `ui_bug`, `integration_issue`, `logic_error`):

```markdown
---
title: [Clear problem title]
date: [YYYY-MM-DD]
category: [.uncle-dev/learns subdirectory]
module: [Module or area]
problem_type: [schema enum]
component: [schema enum]
symptoms:
  - [Observable symptom 1]
root_cause: [schema enum]
resolution_type: [schema enum]
severity: [schema enum]
tags: [keyword-one, keyword-two]
---

# [Clear problem title]

## Problem
[1-2 sentence description of the issue and user-visible impact]

## Symptoms
- [Observable symptom or error]

## What Didn't Work
- [Attempted fix and why it failed]

## Solution
[The fix that worked, including code snippets when useful]

## Why This Works
[Root cause explanation and why the fix addresses it]

## Prevention
- [Concrete practice, test, or guardrail]

## Related Issues
- [Related docs or issues, if any]
```

**Knowledge Track** (`best_practice`, `documentation_gap`, `workflow_issue`, `developer_experience`):

```markdown
---
title: [Clear, descriptive title]
date: [YYYY-MM-DD]
category: [.uncle-dev/learns subdirectory]
module: [Module or area]
problem_type: [schema enum]
component: [schema enum]
severity: [schema enum]
applies_when:
  - [Condition where this applies]
tags: [keyword-one, keyword-two]
---

# [Clear, descriptive title]

## Context
[What situation, gap, or friction prompted this guidance]

## Guidance
[The practice, pattern, or recommendation with code examples when useful]

## Why This Matters
[Rationale and impact of following or not following this guidance]

## When to Apply
- [Conditions or situations where this applies]

## Examples
[Concrete before/after or usage examples showing the practice in action]

## Related
- [Related docs or issues, if any]
```

### Related Docs Finder: Search Strategy

Use grep-first filtering to avoid reading files unnecessarily:

1. Extract keywords from problem context (module names, technical terms, error messages)
2. If category is clear, narrow search to `.uncle-dev/learns/<category>/`
3. Run parallel grep searches, case-insensitive, targeting frontmatter fields:
   - `title:.*<keyword>`
   - `tags:.*(<keyword1>|<keyword2>)`
   - `module:.*<module name>`
   - `component:.*<component>`
4. If >25 candidates: re-run with more specific patterns. If <3: broaden to full content search
5. Read only frontmatter (first 30 lines) of candidate files to score relevance
6. Fully read only strong/moderate matches
7. For GitHub issues: `gh issue list --search "<keywords>" --state all --limit 5`

## Common Rationalizations

| Rationalization | Reality |
|---|---|
| "The fix is obvious, I'll document it later" | Context decays within hours. Failed attempts and root cause are only fully known right now. Later means never. |
| "This was too simple to document" | Simple fixes recur. Without a doc, the next occurrence costs the same 30 minutes. With one, it costs 2 minutes. |
| "I'll use lightweight to save time" | Lightweight is for context exhaustion, not preference. Full mode finds duplicates and prevents creating a second doc that covers the same problem. |
| "Subagents should write intermediate files for me to review" | Subagents return text to the orchestrator. One final file is written. Intermediate files are noise. |
| "I should run knowledge-maintenance first" | Capture the new learning first. Maintenance is a targeted follow-up, not a prerequisite. |
| "Agents will find .uncle-dev/learns/ on their own" | Agents in fresh sessions only discover knowledge stores that instruction files surface. The discoverability check takes seconds. |

## Red Flags

- Subagents write intermediate `.md` files (`context-analysis.md`, `solution-draft.md`) instead of returning text to the orchestrator
- Assembly runs in parallel with research instead of waiting for all Step 2 results
- Multiple solution docs created in one run instead of one (or one update to an existing doc)
- Skill invoked while the problem is still actively being debugged
- Lightweight mode selected without the user choosing it
- Discoverability Check skipped

## Verification

- [ ] One file at `.uncle-dev/learns/[category]/[filename].md` — or one existing file updated with `last_updated`
- [ ] YAML frontmatter validates against `solution-schema.yaml` — all required fields present, enum values correct
- [ ] If overlap was High: existing doc was updated, not a new file created
- [ ] If overlap was Moderate: `uncle-dev-knowledge-maintenance` was invoked or recommended with a specific scope hint
- [ ] Discoverability Check ran and either passed or produced a confirmed edit to the instruction file
- [ ] In Full mode: user was offered Full vs Lightweight choice before any processing began
