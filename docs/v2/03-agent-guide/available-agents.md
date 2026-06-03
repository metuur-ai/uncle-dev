---
sidebar_position: 1
---

# Available Agents

Uncle Dev ships a set of **agents** — reusable personas the AI adopts for a specific job. Agents differ from skills: a skill is a workflow for a phase (spec, test, review), while an agent is a *role* you summon to think or critique from one point of view.

Agents fall into two groups: **personas you invoke** directly, and **specialist subagents** that orchestrating skills spawn for you.

## Personas you invoke

Summon these when you want a specific perspective. Invoke a persona by name (for example, `@uncle-lead`), or ask your agent to use it (for example, "Use the code-reviewer agent").

| Agent | Role | Use it when |
|-------|------|-------------|
| `uncle-po` | Product Owner | Framing a feature, writing acceptance criteria, refining scope, or checking that delivered work meets the requirements. |
| `uncle-lead` | Technical Lead | A change needs architecture design, API contracts, package boundaries, a migration strategy, or technical risk assessment. |
| `uncle-senior` | Senior principal engineer | You want a verdict on a proposed approach, or a thinking partner. Runs in two modes (see below). |
| `code-reviewer` | Senior code reviewer | Reviewing a change before merge across five dimensions: correctness, readability, architecture, security, and performance. |
| `security-auditor` | Security engineer | You need vulnerability detection, threat modeling, or hardening recommendations on a change. |
| `test-engineer` | QA engineer | Designing a test suite, writing tests for existing code, or evaluating test quality and coverage. |

### uncle-senior modes

`uncle-senior` runs in one of two modes. The matching command is `/uncle-senior [--duck]`.

| Mode | What it does |
|------|--------------|
| Challenge (default) | Structured analysis of a proposed approach, ending in a clear verdict. Use when a design feels heavier than the problem, a new abstraction is being introduced, or constraints have not been verified. |
| Duck | A rubber-duck conversation that leads you to your own insight. Use when you are stuck and need a thinking partner. |

## Specialist subagents

These are **not invoked directly**. Orchestrating skills spawn them, run them in parallel, and fold their results back into the main task. You will see their output as part of a larger workflow.

| Subagent | Role | Spawned by |
|----------|------|------------|
| `repo-research-analyst` | Analyzes repository structure, patterns, conventions, and docs into a structured handoff. | Research workflows on an unfamiliar codebase. |
| `graph-analyst` | Runs multi-query semantic graph traversal with graphify and returns annotated findings with confidence levels. | Research and review workflows when `graphify-out/graph.json` exists. |
| `review-synthesizer` | Merges findings from parallel review agents into a single verdict, a deduplicated issue list, and a PR summary. | The review workflow, after parallel reviewers finish. |

## How agents relate to skills

- **Skills** drive the lifecycle (`/uncle-dev-spec`, `/uncle-dev-build`, `/uncle-dev-review`). See the [commands and skills reference](../05-reference/commands-and-skills.md).
- **Agents** are personas those skills — or you — call on for a focused judgment. The review skill, for example, leans on `code-reviewer`, `security-auditor`, and `review-synthesizer`.

If you are choosing what to run, start from a skill or command. Reach for an agent persona when you want one specific lens on the work.
