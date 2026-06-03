---
sidebar_position: 2
---

# Developer Path

For engineers. This path takes you from an approved spec to shipped, reviewed code — building one verified slice at a time. It picks up where the [Product Path](product.md) ends, but you can start at any stage that fits your task.

## How you interact with Uncle Dev

You run **commands** and **agents**. They orchestrate the underlying **skills** for you — you do not call skills by name. The "Skills and agents it orchestrates" column shows what each command runs under the hood, drawn from the commands themselves.

## Your journey

| Stage | You run | Skills and agents it orchestrates |
|-------|---------|-----------------------------------|
| 1. Understand the codebase | `/uncle-dev-research` | `uncle-dev-research`, which spawns the `repo-research-analyst` and `graph-analyst` subagents. |
| 2. Settle the architecture | Agent `@uncle-lead` | Architecture decisions, API contracts, boundary and migration calls. |
| 3. Define the change | `/uncle-dev-spec` | `spec-driven-development`, runs a `pre-mortem`, chains into `/uncle-dev-plan`. |
| 4. Break it down | `/uncle-dev-plan` | `planning-and-task-breakdown`. |
| 5. Build a slice | `/uncle-dev-build` | `incremental-implementation`, `test-driven-development`, `debug-error` (and `frontend-ui-engineering` or `api-and-interface-design` by area). |
| 6. Prove it works | `/uncle-dev-test` | `test-driven-development`, `browser-testing-with-devtools`. |
| 7. Review before merge | `/uncle-dev-review` | `code-review-and-quality`, plus the `code-reviewer`, `security-auditor`, and `review-synthesizer` agents (the auditor applies `security-and-hardening`). |
| 8. Simplify | `/uncle-dev-code-simplify` | `dev-code-simplification`. |
| 9. Ship | `/uncle-dev-ship` | `shipping-and-launch`. |
| 10. Capture what you learned | `/uncle-dev-knowledge-capture` | `knowledge-capture`. |
| 11. Hand off | `/uncle-dev-wrap` | `wrap`. |

Not sure which stage is next? Run `/uncle-dev-next-task` — it reads your spec and tasks and routes you into the right command.

## Worked example: add OAuth login to an unfamiliar app

You inherited a codebase and need to add Google OAuth login.

1. **Understand it.** Run `/uncle-dev-research`. It runs the research skill, which spawns parallel subagents to map the auth flow, routes, and conventions into a research document.
2. **Settle architecture.** Ask `@uncle-lead` where OAuth fits — token storage, session model, and the boundary between auth and the rest of the app.
3. **Define the change.** Run `/uncle-dev-spec`. It runs `spec-driven-development` and a `pre-mortem`, producing the proposal and design.
4. **Plan.** Run `/uncle-dev-plan`. It runs `planning-and-task-breakdown` to split the design into atomic tasks.
5. **Build.** Run `/uncle-dev-build`. It runs `incremental-implementation` and `test-driven-development` as you implement the callback route one thin slice at a time.
6. **Test.** Run `/uncle-dev-test` to cover the slice, mocking the provider and testing an expired code.
7. **Debug.** A redirect loop appears. The build and test commands invoke `debug-error` to reproduce, localize, and fix the root cause.
8. **Review.** Run `/uncle-dev-review`. It runs `code-review-and-quality` and spawns the `code-reviewer` and `security-auditor` agents; `review-synthesizer` merges their findings into one verdict.
9. **Simplify.** Run `/uncle-dev-code-simplify` to reduce complexity in the new module without changing behavior.
10. **Ship.** Run `/uncle-dev-ship`. It runs `shipping-and-launch` to reconcile the spec, confirm the pipeline passes, and prepare deployment.
11. **Capture.** Run `/uncle-dev-knowledge-capture` to document the redirect-loop root cause in `.uncle-dev/learns/`.

## Where to go next

- The agents you used: [Agent Guide](../03-agent-guide/available-agents.md).
- Prompt templates for these commands: [Prompts by phase](../05-reference/prompts-by-phase.md) and [Prompts by skill](../05-reference/prompts-by-skill.md).
- The full list of commands and skills: [Commands and skills](../05-reference/commands-and-skills.md).
- If you hit a snag: [Troubleshooting](../02-user-guide/troubleshooting.md).
