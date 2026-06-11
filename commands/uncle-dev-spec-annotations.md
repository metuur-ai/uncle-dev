---
description: Connect durable product behavior to specs, tests, and code via @spec annotations — add, verify, or audit spec traceability links
---

## Working Principles

1. **Think Before Coding** — Before adding any `@spec` annotation, confirm the target spec ID exists and is stable. Don't invent IDs.
2. **Simplicity First** — Annotate only what implements a durable product behavior. Skip formatting changes, config edits, and one-shot scripts.
3. **Surgical Changes** — Touch only the lines that need annotations. Don't refactor surrounding code.
4. **Goal-Driven Execution** — Success means every behavior entry point cites a real, resolvable spec ID.

## Skill

Use the `uncle-dev-spec-annotations` skill.

$ARGUMENTS
