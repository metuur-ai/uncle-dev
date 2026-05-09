# agent-skills

This is the agent-skills project — a collection of production-grade engineering skills for AI coding agents.

## Project Structure

```
skills/       → Core skills (SKILL.md per directory, with colocated reference files)
agents/       → Reusable agent personas (uncle-dev-ag-code-reviewer, uncle-dev-ag-test-engineer, uncle-dev-ag-security-auditor)
hooks/        → Session lifecycle hooks
.claude/commands/ → Slash commands (/uncle-dev-research, /uncle-dev-spec, /uncle-dev-plan, /uncle-dev-build, /uncle-dev-test, /uncle-dev-review, /uncle-dev-code-simplify, /uncle-dev-ship, /uncle-dev-proactive-memory, /uncle-dev-acknowledge, /uncle-dev-next-task)
docs/         → Setup guides for different tools
scripts/      → Install scripts for Claude Code, Codex, and OpenCode
```

## Skills by Phase

**Define:** uncle-dev-research, uncle-dev-spec-driven-development, uncle-dev-acknowledge
**Plan:** uncle-dev-planning-and-task-breakdown
**Build:** uncle-dev-incremental-implementation, uncle-dev-test-driven-development, uncle-dev-context-engineering, uncle-dev-source-driven-development, uncle-dev-frontend-ui-engineering, uncle-dev-api-and-interface-design
**Verify:** uncle-dev-browser-testing-with-devtools, uncle-dev-debug-error
**Review:** uncle-dev-code-review-and-quality, uncle-dev-dev-code-simplification, uncle-dev-security-and-hardening, uncle-dev-performance-optimization
**Ship:** uncle-dev-git-workflow-and-versioning, uncle-dev-ci-cd-and-automation, uncle-dev-deprecation-and-migration, uncle-dev-documentation-and-adrs, uncle-dev-shipping-and-launch
**Capture:** uncle-dev-knowledge-capture
**Maintain:** uncle-dev-knowledge-maintenance

## Conventions

- Every skill lives in `skills/<name>/SKILL.md`
- YAML frontmatter with `name` and `description` fields
- Description starts with what the skill does (third person), followed by trigger conditions ("Use when...")
- Every skill has: Overview, When to Use, Process, Common Rationalizations, Red Flags, Verification
- Supporting reference files (checklists, patterns) live alongside their SKILL.md in the same skill directory
- Supporting files only created when content exceeds 100 lines

## Commands

- `npm test` — Not applicable (this is a documentation project)
- Validate: Check that all SKILL.md files have valid YAML frontmatter with name and description

## Boundaries

- Always: Follow the skill-anatomy.md format for new skills
- Never: Add skills that are vague advice instead of actionable processes
- Never: Duplicate content between skills — reference other skills instead

## Graphify — mandatory for subagents

This project has a live knowledge graph at `graphify-out/graph.json`.

Every spawned agent or subagent MUST check and use it before grep/Glob/Read:
```bash
[ -f graphify-out/graph.json ] && echo "graphify: ON" || echo "graphify: OFF"
```
If ON:
- Architecture/structure question → `graphify query "<question>" --budget 1500`
- "How does X work?" → `graphify explain "<X>"`
- "How does X relate to Y?" → `graphify path "<X>" "<Y>"`
- Read `graphify-out/GRAPH_REPORT.md` for god nodes and community structure

Only fall back to grep/Read/Glob if graphify returns empty.

Applies to: inline scouts, repo-research-analyst, code reviewers, investigate sessions — every agent spawned in this repo.
