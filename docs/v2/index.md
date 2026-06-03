---
sidebar_position: 9
---

# Documentation Map

The complete list of pages, for when you want to see everything at once. If you are new, start at the [introduction](intro.md) instead.

## Documentation map

The docs are grouped into five areas so you can find things without reading everything. Planned areas are listed in the [roadmap](roadmap.md).

```text
docs/
├── 01-getting-started/   → understand, install, run your first task
│   ├── What is Uncle Dev?
│   ├── Installation
│   ├── First task
│   └── Common workflows
├── 02-user-guide/        → concepts and per-tool setup
│   ├── Concepts (overview)
│   │   ├── SDD and OpenSpec
│   │   ├── The .devlocal directory
│   │   ├── Spec annotations
│   │   ├── Acknowledge: design-decision notes
│   │   └── Next-task selection
│   └── Tool Setup
│       ├── Copilot · Cursor · Gemini CLI · OpenCode · Windsurf
├── 03-agent-guide/       → personas and specialist subagents
│   └── Available agents
├── 04-customization/     → extend Uncle Dev
│   ├── Authoring skills
│   ├── Implement spec annotations
│   └── Spec annotations on a brownfield codebase
├── 05-reference/         → look up the details
│   ├── Commands and skills
│   ├── Prompts by phase
│   └── Prompts by skill
├── all-in-one.md         → the full documentation on a single page
└── roadmap.md            → planned sections (agent guide, architecture, examples, FAQ…)
```

## Recommended path

Follow these in order the first time. Each step links to one document.

1. **Understand the idea** — [What is Uncle Dev?](01-getting-started/what-is-uncle-dev.md) explains the problem it solves and why it works.
2. **Install it** — [Installation](01-getting-started/installation.md) sets up Uncle Dev in your AI coding tool.
3. **Run your first task** — [First task](01-getting-started/first-task.md) walks you through using skills end to end.
4. **See common workflows** — [Common workflows](01-getting-started/common-workflows.md) shows how a feature moves through every phase.
5. **Keep the references handy** — [Commands and skills](05-reference/commands-and-skills.md), [Prompts by phase](05-reference/prompts-by-phase.md), and [Prompts by skill](05-reference/prompts-by-skill.md).

## Browse by area

### Getting Started

| Document | What you do |
|----------|-------------|
| [What is Uncle Dev?](01-getting-started/what-is-uncle-dev.md) | Understand the problem it solves and how spec-driven development fixes it. |
| [Installation](01-getting-started/installation.md) | Install Uncle Dev in Claude Code, Codex, Cursor, OpenCode, Copilot, Gemini CLI, or Graphify. |
| [First task](01-getting-started/first-task.md) | Set up and run your first Uncle Dev workflow from start to finish. |
| [Common workflows](01-getting-started/common-workflows.md) | Take a feature through every lifecycle phase. |

### User Guide

| Document | What it covers |
|----------|----------------|
| [Concepts](02-user-guide/concepts.md) | Overview of the conceptual docs below. |
| [SDD and OpenSpec](02-user-guide/sdd-and-openspec.md) | Why spec-driven development and the OpenSpec model retain context. |
| [The `.devlocal` directory](02-user-guide/devlocal-directory.md) | Why the agent needs a disposable, gitignored scratchpad. |
| [Spec annotations](02-user-guide/spec-annotations.md) | How `@spec` links intent to code and back. |
| [Acknowledge: design-decision notes](02-user-guide/acknowledge-decisions.md) | How decision notes are captured, routed, and gated. |
| [Next-task selection](02-user-guide/next-task-selection.md) | How the next-task skill picks and parallelizes work. |
| [Tool setup](02-user-guide/tool-setup/copilot.md) | Per-tool configuration (Copilot, Cursor, Gemini CLI, OpenCode, Windsurf). |

### Agent Guide

| Document | What it covers |
|----------|----------------|
| [Available agents](03-agent-guide/available-agents.md) | The personas you invoke (uncle-po, uncle-lead, uncle-senior, code-reviewer, security-auditor, test-engineer) and the specialist subagents that orchestrating skills spawn. |

### Customization

| Document | What you do |
|----------|-------------|
| [Authoring skills](04-customization/authoring-skills.md) | Write a new skill using the `SKILL.md` format and conventions. |
| [Implement spec annotations](04-customization/implement-spec-annotations.md) | Add `@spec` annotation tracing to a repository. |
| [Spec annotations on a brownfield codebase](04-customization/spec-annotations-brownfield.md) | Apply `@spec` annotations to existing code. |

### Reference

| Document | What it lists |
|----------|---------------|
| [Commands and skills](05-reference/commands-and-skills.md) | Every skill and command, grouped by phase. |
| [Prompts by phase](05-reference/prompts-by-phase.md) | Copy-paste prompt templates for each lifecycle command. |
| [Prompts by skill](05-reference/prompts-by-skill.md) | Copy-paste prompt templates for individual skills. |

## All in one page

[Uncle Dev: complete documentation](all-in-one.md) combines the core concepts, install steps, and prompt templates into a single page for offline reading or quick search.
