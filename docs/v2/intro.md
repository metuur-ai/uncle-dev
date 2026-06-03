---
sidebar_position: 1
slug: /
---

# Uncle Dev

**Make your AI coding agent work like a disciplined senior engineer — spec first, test as it goes, review before commit.**

Left alone, AI coding agents take the shortest path: they skip the spec, guess the architecture, skip the tests, and hand you a large block of unreviewed code. Uncle Dev is a pack of engineering skills that overrides that behavior at every phase, so the agent plans before it builds and verifies before it ships.

## See it in action

Ask a vanilla agent to "build a login page" and it immediately writes HTML, CSS, and database queries — guessing the edge cases as it goes.

With Uncle Dev, the same agent works the way a senior engineer would:

```text
  DEFINE          PLAN          BUILD         VERIFY        REVIEW         SHIP
 ┌──────┐     ┌──────────┐   ┌──────┐     ┌──────┐     ┌──────┐     ┌──────┐
 │ Spec │ ──▶ │  Break   │ ─▶│ Code │ ──▶ │ Test │ ──▶ │  QA  │ ──▶ │  Go  │
 │ first│     │ into     │   │ one  │     │ &    │     │ gate │     │ live │
 │      │     │ tasks    │   │ slice│     │ debug│     │      │     │      │
 └──────┘     └──────────┘   └──────┘     └──────┘     └──────┘     └──────┘
  /spec         /plan         /build       /test        /review      /ship
```

It writes a spec and waits for your approval, breaks the work into tasks, builds one tested slice at a time, then reviews its own diff before committing.

## Start here

**→ [Install Uncle Dev](01-getting-started/installation.md)** — set it up in your tool in a few minutes.

Works with Claude Code, Codex, Cursor, OpenCode, GitHub Copilot, and Gemini CLI.

## Choose your path

- **New to Uncle Dev?** Read [What is Uncle Dev?](01-getting-started/what-is-uncle-dev.md) for the idea behind it.
- **Ready to build?** Follow [your first task](01-getting-started/first-task.md) end to end.
- **Looking something up?** Open the [commands and skills reference](05-reference/commands-and-skills.md).

## What's inside

- **[Getting Started](01-getting-started/what-is-uncle-dev.md)** — understand it, install it, run your first task.
- **[User Guide](02-user-guide/concepts.md)** — the concepts behind it and per-tool setup.
- **[Agent Guide](03-agent-guide/available-agents.md)** — the agent personas and specialist subagents, and when to use each.
- **[Customization](04-customization/authoring-skills.md)** — author your own skills and wire in spec annotations.
- **[Reference](05-reference/commands-and-skills.md)** — every skill, command, and prompt template.
