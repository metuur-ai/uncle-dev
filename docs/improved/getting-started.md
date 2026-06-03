# Getting Started with agent-skills

agent-skills works with any AI coding agent that accepts Markdown instructions. This guide covers the universal approach. For tool-specific setup, see the dedicated guides.

This guide takes about 10 minutes. By the end, you will have installed the skill pack into a project and loaded your first skill into an agent.

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

This installs a local copy of the pack into `.agents/` inside your target project. You should now have these directories:

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

Copy the relevant `SKILL.md` content from `.agents/skills/` into your agent's rules file (`CLAUDE.md`, `.cursorrules`, or the equivalent for your tool). The agent now follows that skill's workflow when you give it a matching task.

### 4. Use the meta-skill for discovery

Load the `using-agent-skills` skill as well. It contains a flowchart that maps task types to the appropriate skill, so your agent can pick the right one for each task.

You have now completed the core setup: the pack is installed and your first skills are loaded into the agent.

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

Don't load all skills at once — it wastes context. Load only the skills relevant to the current task:

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
| `uncle-dev-ag-code-reviewer.md` | Five-axis code review |
| `uncle-dev-ag-test-engineer.md` | Test strategy and writing |
| `uncle-dev-ag-security-auditor.md` | Vulnerability detection |
| `uncle-lead.md` | Technical lead persona for architecture/design ownership |
| `uncle-po.md` | Product owner persona for requirements and acceptance criteria |
| `uncle-dev-ag-repo-research-analyst.md` | Structured repo exploration — spawned by the research skill |
| `uncle-dev-ag-graph-analyst.md` | Multi-hop semantic graph traversal — spawned by research and review skills when `graphify-out/graph.json` exists |

Load an agent definition when you need specialized review. The graph-analyst and repo-research-analyst are spawned automatically by orchestrating skills — you do not invoke them directly.

## Graphify-Enhanced Search (optional but recommended)

If you build a graphify knowledge graph for your project, uncle-dev skills automatically use semantic graph traversal instead of grep for architecture questions, impact analysis, and dependency mapping.

### Enable it once per project

```bash
# Install graphify CLI (requires Python 3.10+)
pip install graphifyy

# Build the initial graph (run from project root)
graphify .
# This creates graphify-out/graph.json, GRAPH_REPORT.md, and graph.html
```

Once `graphify-out/graph.json` exists, every uncle-dev skill checks for it at startup and activates graph-first search automatically. No configuration needed.

### Keep it current

```bash
# After significant code changes, rebuild incrementally (no LLM cost)
graphify update src/
```

### What you get

| Without graphify | With graphify |
|---|---|
| Grep finds text matches | `graphify explain` traverses semantic neighbors |
| Manual dependency mapping | `graphify path` traces dependency chains |
| Community guesswork | GRAPH_REPORT.md shows god nodes and clusters |
| Trial-and-error story boundaries | Hyperedges map named flows to story scope |

See `skills/uncle-dev-graphify-aware-analysis/SKILL.md` for the full protocol, confidence interpretation, and hyperedge decision rules.

## Using Commands

The `.claude/commands/` directory contains slash commands for Claude Code:

| Command | Skill Invoked |
|---------|---------------|
| `/uncle-dev-spec` | spec-driven-development |
| `/uncle-dev-plan` | planning-and-task-breakdown |
| `/uncle-dev-build` | incremental-implementation + test-driven-development |
| `/uncle-dev-test` | test-driven-development |
| `/uncle-dev-review` | code-review-and-quality |
| `/uncle-dev-ship` | shipping-and-launch |

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

The `/uncle-dev-spec` and `/uncle-dev-plan` commands use OpenSpec as the default shared workflow. Treat these artifacts as **living documents** while the work is in progress:

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

Legacy note: root-level `SPEC.md` and `tasks/uncle-dev-plan.md` / `tasks/todo.md` are no longer the default workflow. Use them only for migration or compatibility with older repos.

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
