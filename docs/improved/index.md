---
sidebar_position: 1
slug: /
---

# Uncle Dev Documentation

Uncle Dev is a collection of engineering skills that make AI coding agents follow a disciplined, spec-driven workflow. This page is the entry point to the documentation.

New here? Follow the [recommended path](#recommended-path). Already know what you need? Use the [documentation map](#documentation-map) or jump to the [skill and command reference](reference/skills-and-commands.md).

## Documentation map

The docs are grouped into four areas so you can find things without reading everything.

```text
docs/
├── Getting Started     → understand, install, run your first workflow
│   ├── What is Uncle Dev?
│   ├── Installation
│   └── First workflow
├── Concepts            → why it works the way it does
│   ├── SDD and OpenSpec
│   ├── The .devlocal directory
│   ├── Spec annotations, explained
│   ├── Acknowledge: design-decision notes
│   └── Next-task selection
├── Guides              → step-by-step tasks
│   ├── Idea to deploy
│   ├── Tool Setup
│   │   ├── Copilot
│   │   ├── Cursor
│   │   ├── Gemini CLI
│   │   ├── OpenCode
│   │   └── Windsurf
│   ├── Implement spec annotations
│   └── Spec annotations on a brownfield codebase
├── Reference           → look up the details
│   ├── Skills and commands
│   ├── Prompts by phase
│   ├── Prompts by skill
│   └── Skill anatomy
└── All in one page     → the full documentation on a single page
```

## Recommended path

Follow these in order the first time. Each step links to one document.

1. **Understand the idea** — [What is Uncle Dev?](getting-started/what-is-uncle-dev.md) explains the problem it solves and why it works.
2. **Install it** — [Installation](getting-started/installation.md) sets up Uncle Dev in your AI coding tool.
3. **Run your first workflow** — [First workflow](getting-started/first-workflow.md) walks you through using skills end to end.
4. **Learn the lifecycle** — [Idea to deploy](guides/idea-to-deploy.md) shows how a feature moves through every phase.
5. **Keep the references handy** — [Skills and commands](reference/skills-and-commands.md), [Prompts by phase](reference/prompts-by-phase.md), and [Prompts by skill](reference/prompts-by-skill.md).

## Browse by area

The documentation follows the [Diátaxis](https://diataxis.fr/) framework. Pick the area that matches what you are trying to do.

### Getting Started — learn by doing

| Document | What you do |
|----------|-------------|
| [What is Uncle Dev?](getting-started/what-is-uncle-dev.md) | Understand the problem it solves and how spec-driven development fixes it. |
| [Installation](getting-started/installation.md) | Install Uncle Dev in Claude Code, Codex, Cursor, OpenCode, Copilot, Gemini CLI, or Graphify. |
| [First workflow](getting-started/first-workflow.md) | Set up and run your first Uncle Dev workflow from start to finish. |

### Concepts — understand the ideas

| Document | What it explains |
|----------|------------------|
| [SDD and OpenSpec](concepts/sdd-and-openspec.md) | Why spec-driven development and the OpenSpec directory model retain context. |
| [The `.devlocal` directory](concepts/devlocal-directory.md) | Why the agent needs a disposable, gitignored scratchpad. |
| [Spec annotations, explained](concepts/spec-annotations-explained.md) | How `@spec` links intent to code and back. |
| [Acknowledge: design-decision notes](concepts/acknowledge-decisions.md) | How decision notes are captured, routed, and used as a build gate. |
| [Next-task selection](concepts/next-task-selection.md) | How the next-task skill picks and parallelizes work safely. |

### Guides — accomplish a task

| Document | Task |
|----------|------|
| [Idea to deploy](guides/idea-to-deploy.md) | Take a feature through every lifecycle phase. |
| [Copilot setup](guides/tool-setup/copilot.md) | Configure Uncle Dev personas for GitHub Copilot. |
| [Cursor setup](guides/tool-setup/cursor.md) | Configure Uncle Dev rules for Cursor. |
| [Gemini CLI setup](guides/tool-setup/gemini-cli.md) | Install and configure skills for Gemini CLI. |
| [OpenCode setup](guides/tool-setup/opencode.md) | Configure the agent-driven workflow for OpenCode. |
| [Windsurf setup](guides/tool-setup/windsurf.md) | Configure Uncle Dev rules for Windsurf. |
| [Implement spec annotations](guides/implement-spec-annotations.md) | Add `@spec` annotation tracing to a repository. |
| [Spec annotations on a brownfield codebase](guides/spec-annotations-brownfield.md) | Apply `@spec` annotations to existing code. |

### Reference — look up the details

| Document | What it lists |
|----------|---------------|
| [Skills and commands](reference/skills-and-commands.md) | Every skill and command, grouped by phase. Start here to find what to use. |
| [Prompts by phase](reference/prompts-by-phase.md) | Copy-paste prompt templates for each lifecycle command. |
| [Prompts by skill](reference/prompts-by-skill.md) | Copy-paste prompt templates for individual skills. |
| [Skill anatomy](reference/skill-anatomy.md) | The `SKILL.md` file format and conventions for authoring skills. |

## All in one page

[Uncle Dev: complete documentation](all-in-one.md) combines the core concepts, install steps, and prompt templates into a single page for offline reading or quick search.
