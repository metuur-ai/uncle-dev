---
sidebar_position: 1
---

# Product Path

For product managers and product owners. This path takes you from a rough idea to an approved, well-scoped specification — before any code is written.

## How you interact with Uncle Dev

You run **commands** (slash commands like `/uncle-dev-spec`) and **agents** (personas like `@uncle-po`). Those orchestrate the underlying **skills** for you — you rarely call a skill by name. The "Skills orchestrated" column below shows what runs under the hood, so you can see what each step actually does.

The one exception is a small set of *shaping skills* that run before any command exists to drive them. You trigger those by phrase.

## Before the spec: shaping skills

These conversational skills help you shape the work. There is no command for them yet — trigger them by phrase.

| Trigger | Skill | What it produces |
|---------|-------|------------------|
| "ideate" | `uncle-dev-idea-refine` | A sharper concept with the riskiest assumptions surfaced. |
| "grill me" | `uncle-dev-grill` | A PRD built from a structured interview. |
| "define our terms" | `uncle-dev-ubiquitous-language` | A glossary of canonical domain terms. |
| "map the features" | `uncle-dev-feature-map` | An inventory of what the product already does. |

## Your journey

Each row is a command or agent you run. It orchestrates the skills in the right-hand column.

| Stage | You run | Skills it orchestrates |
|-------|---------|------------------------|
| 1. Frame the requirement | Agent `@uncle-po` | Product-owner judgment: acceptance criteria, scope, boundaries. |
| 2. Write the spec | Command `/uncle-dev-spec` | `spec-driven-development`, runs a `pre-mortem`, then chains into `/uncle-dev-plan`. |
| 3. Stress-test the approach | Agent `@uncle-senior` (Challenge mode) | A structured verdict on the proposed design. |
| 4. Record the decisions | Command `/uncle-dev-acknowledge` | `acknowledge`, `documentation-and-adrs`. |
| 5. Validate delivery | Agent `@uncle-po` | Checks the finished work against the acceptance criteria from stage 1. |

## Worked example: a notification-preferences feature

You want users to control which notifications they receive.

1. **Shape it.** Trigger the `uncle-dev-idea-refine` skill (say "ideate"). You and the agent settle on a minimal first version.
2. **Pin requirements.** Trigger the `uncle-dev-grill` skill (say "grill me"). It interviews you one decision at a time and writes a PRD.
3. **Check existing behavior.** Trigger the `uncle-dev-feature-map` skill to confirm how notifications work today.
4. **Frame acceptance criteria.** Ask `@uncle-po` for criteria such as "a user can mute a category and stop its emails within one minute."
5. **Write the spec.** Run `/uncle-dev-spec`. It runs `spec-driven-development`, performs a `pre-mortem`, and writes `proposal.md` and `design.md` in `openspec/changes/`. You review and approve before any code.
6. **Record a decision.** Run `/uncle-dev-acknowledge` to capture "security alerts are never mutable," so the build phase enforces it.
7. **Hand off.** Approve the spec. A developer continues with the [Developer Path](developer.md).
8. **Validate.** When the work returns, ask `@uncle-po` to check it against the stage-4 criteria.

## Where to go next

- The agents you used: [Agent Guide](../03-agent-guide/available-agents.md).
- Prompt templates for these commands: [Prompts by phase](../05-reference/prompts-by-phase.md).
- The full list of commands and skills: [Commands and skills](../05-reference/commands-and-skills.md).
- What happens after approval: [Developer Path](developer.md).
