# Getting Started with agent-skills

agent-skills works with any AI coding agent that accepts Markdown instructions. This guide covers the universal approach. For tool-specific setup, see the dedicated guides.

## How Skills Work

Each skill is a Markdown file (`SKILL.md`) that describes a specific engineering workflow. When loaded into an agent's context, the agent follows the workflow — including verification steps, anti-patterns to avoid, and exit criteria.

**Skills are not reference docs.** They're step-by-step processes the agent follows.

## Quick Start (Any Agent)

### 1. Clone the repository

```bash
git clone https://github.com/addyosmani/agent-skills.git
cd agent-skills
./scripts/install-plugin.sh getting-started /path/to/your-project
```

This installs a generic local copy of the pack into `.agents/` inside your target project:

- `.agents/skills/`
- `.agents/agents/`
- `.agents/references/`

### 2. Choose a skill

Browse the `skills/` directory. Each subdirectory contains a `SKILL.md` with:
- **When to use** — triggers that indicate this skill applies
- **Process** — step-by-step workflow
- **Verification** — how to confirm the work is done
- **Common rationalizations** — excuses the agent might use to skip steps
- **Red flags** — signs the skill is being violated

### 3. Load the skill into your agent

Copy the relevant `SKILL.md` content from `.agents/skills/` into your agent's system prompt, rules file, or conversation. The most common approaches:

**System prompt:** Paste the skill content at the start of the session.

**Rules file:** Add skill content to your project's rules file (CLAUDE.md, .cursorrules, etc.).

**Conversation:** Reference the skill when giving instructions: "Follow the test-driven-development process for this change."

### 4. Use the meta-skill for discovery

Start with the `using-agent-skills` skill loaded. It contains a flowchart that maps task types to the appropriate skill.

## Recommended Setup

### Minimal (Start here)

Load three essential skills into your rules file:

1. **spec-driven-development** — For defining what to build
2. **test-driven-development** — For proving it works
3. **code-review-and-quality** — For verifying quality before merge

These three cover the most critical quality gaps in AI-assisted development.

### Full Lifecycle

For comprehensive coverage, load skills by phase:

```
Starting a project:  spec-driven-development → planning-and-task-breakdown
During development:  incremental-implementation + test-driven-development
Before merge:        code-review-and-quality + security-and-hardening
Before deploy:       shipping-and-launch
```

### Context-Aware Loading

Don't load all skills at once — it wastes context. Load skills relevant to the current task:

- Working on UI? Load `frontend-ui-engineering`
- Debugging? Load `debugging-and-error-recovery`
- Setting up CI? Load `ci-cd-and-automation`

## Skill Anatomy

Every skill follows the same structure:

```
YAML frontmatter (name, description)
├── Overview — What this skill does
├── When to Use — Triggers and conditions
├── Core Process — Step-by-step workflow
├── Examples — Code samples and patterns
├── Common Rationalizations — Excuses and rebuttals
├── Red Flags — Signs the skill is being violated
└── Verification — Exit criteria checklist
```

See [skill-anatomy.md](skill-anatomy.md) for the full specification.

## Using Agents

The `agents/` directory contains pre-configured agent personas:

| Agent | Purpose |
|-------|---------|
| `code-reviewer.md` | Five-axis code review |
| `test-engineer.md` | Test strategy and writing |
| `security-auditor.md` | Vulnerability detection |

Load an agent definition when you need specialized review. For example, ask your coding agent to "review this change using the code-reviewer agent persona" and provide the agent definition.

## Using Commands

The `.claude/commands/` directory contains slash commands for Claude Code:

| Command | Skill Invoked |
|---------|---------------|
| `/spec` | spec-driven-development |
| `/plan` | planning-and-task-breakdown |
| `/build` | incremental-implementation + test-driven-development |
| `/test` | test-driven-development |
| `/review` | code-review-and-quality |
| `/ship` | shipping-and-launch |

For DEFINE and PLAN, the canonical workflow now uses OpenSpec:

```bash
openspec change create <change-id>
openspec artifact add <change-id> execution.md
openspec artifact add <change-id> handoff.md
```

## Using References

The `references/` directory contains supplementary checklists:

| Reference | Use With |
|-----------|----------|
| `testing-patterns.md` | test-driven-development |
| `performance-checklist.md` | performance-optimization |
| `security-checklist.md` | security-and-hardening |
| `accessibility-checklist.md` | frontend-ui-engineering |

Load a reference when you need detailed patterns beyond what the skill covers.

## Spec and task artifacts

The `/spec` and `/plan` commands use OpenSpec as the default shared workflow. Treat these artifacts as **living documents** while the work is in progress:

- `openspec/specs/` — current project truth tracked in git
- `openspec/changes/<change-id>/proposal.md` — objective, scope, success criteria, boundaries
- `openspec/changes/<change-id>/design.md` — architecture, constraints, commands, testing approach
- `openspec/changes/<change-id>/tasks.md` — shared story-level breakdown
- `openspec/changes/<change-id>/execution.md` — shared sequencing, dependencies, blockers
- `openspec/changes/<change-id>/handoff.md` — QA guidance and validation steps
- `.devlocal/<user>/<story-id>/scratchpad.md` — private technical breakdown, ignored by git

Operational rules:

- Keep shared coordination and design truth in `openspec/`
- Promote team-impacting discoveries from `.devlocal/` into `tasks.md`, `execution.md`, or `design.md`
- Treat anything left in `.devlocal/` after the story is merged as disposable

Legacy note: root-level `SPEC.md` and `tasks/plan.md` / `tasks/todo.md` are no longer the default workflow. Use them only for migration or compatibility with older repos.

Working rules:

- Keep `openspec/` artifacts in version control during development so the human and the agent have a shared source of truth.
- Update them when scope, sequencing, or technical decisions change.
- Keep `.devlocal/` ignored. It is personal workspace, not shared truth.

## Tips

1. **Start with spec-driven-development** for any non-trivial work
2. **Always load test-driven-development** when writing code
3. **Don't skip verification steps** — they're the whole point
4. **Load skills selectively** — more context isn't always better
5. **Use the agents for review** — different perspectives catch different issues
