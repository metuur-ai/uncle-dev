# How to Use agent-skills with Gemini CLI

## Prerequisites

Before you begin, ensure you have:

- Gemini CLI installed
- `git` installed (for the local-clone install option)
- A target project where you want to install the skills

## Option 1: Install as Skills (Recommended)

Gemini CLI has a native skills system that auto-discovers `SKILL.md` files in `.gemini/skills/` or `.agents/skills/` directories. Each skill activates on demand when it matches your task.

Choose one install method:

**Install directly from the repository:**

```bash
gemini skills install https://github.com/addyosmani/agent-skills.git --path skills
```

**Install from a local clone:**

```bash
git clone https://github.com/addyosmani/agent-skills.git
cd agent-skills
./scripts/install-plugin.sh gemini /path/to/your-project
```

The installer copies all skills into `.gemini/skills/`, which Gemini CLI auto-discovers for that workspace. For a user-level install, point the script at your home directory instead.

Gemini CLI injects skill names and descriptions into the prompt automatically. When it recognizes a matching task, it asks permission to activate the skill before loading its full instructions.

## Option 2: Load skills through GEMINI.md (Persistent Context)

To load skills as persistent project context instead of on-demand activation, add them to your project's `GEMINI.md`:

```bash
# Create GEMINI.md with core skills as persistent context
cat /path/to/agent-skills/skills/uncle-dev-incremental-implementation/SKILL.md > GEMINI.md
echo -e "\n---\n" >> GEMINI.md
cat /path/to/agent-skills/skills/uncle-dev-code-review-and-quality/SKILL.md >> GEMINI.md
```

You can also modularize by importing from separate files:

```markdown
# Project Instructions

@skills/uncle-dev-test-driven-development/SKILL.md
@skills/uncle-dev-incremental-implementation/SKILL.md
```

Use `/memory show` to verify loaded context, and `/memory reload` to refresh after changes.

> **Skills vs GEMINI.md:** Skills are on-demand expertise that activate only when relevant, keeping your context window clean. GEMINI.md provides persistent context loaded for every prompt. Use skills for phase-specific workflows and GEMINI.md for always-on project conventions.

## Verify it worked

Confirm the installation:

1. Run `/skills list`. The installed uncle-dev skills should appear in the list.
2. If you used GEMINI.md, run `/memory show` to confirm the skill content is loaded as context.

## Recommended Configuration

### Always-On (GEMINI.md)

Add these as persistent context for every session:

- `incremental-implementation` — Build in small verifiable slices
- `code-review-and-quality` — Five-axis review

### On-Demand (Skills)

Install these as skills so they activate only when relevant:

- `test-driven-development` — Activates when implementing logic or fixing bugs
- `spec-driven-development` — Activates when starting a new project or feature
- `frontend-ui-engineering` — Activates when building UI
- `security-and-hardening` — Activates during security reviews
- `performance-optimization` — Activates during performance work

## Advanced Configuration

### MCP Integration

Many skills in this pack use [Model Context Protocol (MCP)](https://modelcontextprotocol.io/) tools to interact with the environment. For example:

- `browser-testing-with-devtools` uses the `chrome-devtools` MCP extension.
- `performance-optimization` can benefit from performance-related MCP tools.

To enable these, ensure you have the relevant MCP extensions installed in your Gemini CLI configuration (`~/.gemini/config.json`).

### Session Hooks

Gemini CLI supports session lifecycle hooks. You can use these to automatically inject context or run validation scripts at the start of a session.

To replicate the `agent-skills` experience from other tools, you can configure a `SessionStart` hook that reminds you of the available skills or loads a meta-skill.

### Explicit Context Loading

You can explicitly load any skill into your current session by referencing it with the `@` symbol in your prompt:

```markdown
Use the @skills/uncle-dev-test-driven-development/SKILL.md skill to implement this fix.
```

This is useful when you want to ensure a specific workflow is followed without waiting for auto-discovery.

## Usage Tips

1. **Prefer skills over GEMINI.md** — Skills activate on demand and keep your context window focused. Only put skills in GEMINI.md if you want them always loaded.
2. **Skill descriptions matter** — Each SKILL.md has a `description` field in its frontmatter that tells agents when to activate it. The descriptions in this repo are optimized for auto-discovery across all supported tools (Claude Code, Gemini CLI, etc.) by clearly stating both *what* the skill does and *when* it should be triggered.
3. **Use agents for review** — Copy `agents/uncle-dev-ag-code-reviewer.md` content when requesting structured code reviews.
4. **Combine with references** — Reference checklists from `references/` when working on specific quality areas like testing or performance.
