# agent-skills

This is the agent-skills project — a collection of production-grade engineering skills for AI coding agents.

## Project Structure

```
skills/       → Core skills (SKILL.md per directory, with colocated reference files)
agents/       → Reusable agent personas (uncle-dev-ag-code-reviewer, uncle-dev-ag-test-engineer, uncle-dev-ag-security-auditor)
hooks/        → Session lifecycle hooks
commands/ → Slash commands (/uncle-dev-research, /uncle-dev-spec, /uncle-dev-plan, /uncle-dev-build, /uncle-dev-test, /uncle-dev-review, /uncle-dev-code-simplify, /uncle-dev-ship, /uncle-dev-proactive-memory, /uncle-dev-acknowledge, /uncle-dev-next-task, /uncle-dev-design-docs, /uncle-dev-spec-scan, /uncle-dev-spec-graph, /uncle-dev-wrap, /uncle-dev-feature-map, /uncle-dev-brownfield, /uncle-dev-changelog, /uncle-senior)
docs/         → Setup guides for different tools
scripts/      → Install scripts for Claude Code, Codex, and OpenCode
```

## Skills by Phase

**Define:** uncle-dev-research, uncle-dev-idea-refine, uncle-dev-grill, uncle-dev-verbalized-sampling, uncle-dev-ubiquitous-language, uncle-dev-spec-driven-development, uncle-dev-design-architecture-docs, uncle-dev-acknowledge
**Brownfield:** uncle-dev-feature-map, uncle-dev-brownfield
**Evaluate:** uncle-senior
**Plan:** uncle-dev-planning-and-task-breakdown
**Build:** uncle-dev-incremental-implementation, uncle-dev-test-driven-development, uncle-dev-spec-annotations, uncle-dev-context-engineering, uncle-dev-source-driven-development, uncle-dev-frontend-ui-engineering, uncle-dev-api-and-interface-design
**Verify:** uncle-dev-browser-testing-with-devtools, uncle-dev-debug-error, uncle-dev-mutation-testing
**Review:** uncle-dev-code-review-and-quality, uncle-dev-dev-code-simplification, uncle-dev-security-and-hardening, uncle-dev-performance-optimization
**Ship:** uncle-dev-git-workflow-and-versioning, uncle-dev-ci-cd-and-automation, uncle-dev-deprecation-and-migration, uncle-dev-documentation-and-adrs, uncle-dev-speech, uncle-dev-changelog, uncle-dev-shipping-and-launch
**Capture:** uncle-dev-knowledge-capture
**Handoff:** uncle-dev-wrap
**Maintain:** uncle-dev-knowledge-maintenance, uncle-dev-custom-me

## Conventions

- Every skill lives in `skills/<name>/SKILL.md`
- YAML frontmatter with `name` and `description` fields
- Description starts with what the skill does (third person), followed by trigger conditions ("Use when...")
- Every skill has: Overview, When to Use, Process, Common Rationalizations, Red Flags, Verification
- Supporting reference files (checklists, patterns) live alongside their SKILL.md in the same skill directory
- Supporting files only created when content exceeds 100 lines
- Architecture intent flows HLD → LLD → EARS specs → tests → code. Code and tests reference durable behavior via `@spec` annotations. See `uncle-dev-design-architecture-docs` and `uncle-dev-spec-annotations`.

## Commands

- `npm test` — Not applicable (this is a documentation project)
- Validate: Check that all SKILL.md files have valid YAML frontmatter with name and description
- `bash scripts/lint-skills.sh [path]` — lint SKILL.md files with nori-lint (report-only; `--enforce` to gate, `--deep` + `ANTHROPIC_API_KEY` for LLM rules; rule config in `scripts/nori-lint.config.json`; setup guide: `docs/originals/lint-skills-setup.md`)

## Boundaries

- Always: Follow the skill-anatomy.md format for new skills
- Always: Read project configuration through `scripts/uncle-dev-config.sh` (scalar or `--list` mode). No script, command, hook, or helper may open `.agents/uncle-dev-setup.yaml` directly. If the existing API doesn't expose a shape you need (e.g., iterating an array), extend `uncle-dev-config.sh` — never bypass it. This is the single source of truth for config semantics, validation, and future schema migrations. Audit guard: `grep -rn 'open.*setup\.yaml\|cat.*setup\.yaml\|yq.*setup\.yaml' scripts/ .claude/ hooks/` should return empty (only the helper itself reads the YAML).
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

<!-- uncle-dev -->
## uncle-dev

This project uses uncle-dev engineering skills for structured AI-assisted development.

### Skills by Phase
**Define:** uncle-dev-research, uncle-dev-idea-refine, uncle-dev-grill, uncle-dev-verbalized-sampling, uncle-dev-ubiquitous-language, uncle-dev-spec-driven-development, uncle-dev-design-architecture-docs, uncle-dev-acknowledge
**Brownfield:** uncle-dev-feature-map, uncle-dev-brownfield
**Plan:** uncle-dev-planning-and-task-breakdown
**Build:** uncle-dev-incremental-implementation, uncle-dev-test-driven-development, uncle-dev-spec-annotations, uncle-dev-context-engineering, uncle-dev-frontend-ui-engineering, uncle-dev-api-and-interface-design
**Verify:** uncle-dev-browser-testing-with-devtools, uncle-dev-debug-error, uncle-dev-mutation-testing
**Review:** uncle-dev-code-review-and-quality, uncle-dev-security-and-hardening, uncle-dev-performance-optimization
**Ship:** uncle-dev-git-workflow-and-versioning, uncle-dev-shipping-and-launch, uncle-dev-documentation-and-adrs, uncle-dev-speech, uncle-dev-changelog
**Capture:** uncle-dev-knowledge-capture
**Handoff:** uncle-dev-wrap
**Maintain:** uncle-dev-knowledge-maintenance, uncle-dev-custom-me

### Conventions
- Architecture flows HLD → LLD → EARS specs → tests → code
- Code and tests reference durable behavior via `@spec` annotations
- OpenSpec artifacts tracked in `openspec/changes/<change-id>/` (proposal, design, tasks, execution, handoff)
- Personal scratchpad in `.devlocal/<user>/` (gitignored, not shared)
- Team learnings captured in `.uncle-dev/learns/`

### Workflow rules
- Run `/uncle-dev-spec` before any non-trivial feature
- Run `/uncle-dev-plan` after spec, before coding
- Check `.agents/uncle-dev-setup.yaml` for project-specific overrides and sdd_mode

### Code Context (always enforced)
- Before editing any file, check if its directory has an `AGENTS.md` — if so, read it first
- If no `AGENTS.md` exists in a source directory, create one before editing (template: `skills/uncle-dev-context-engineering/agents-md-guide.md`)
- After adding, moving, or deleting source directories, update the affected `AGENTS.md` files in the same turn
- Respect architecture boundaries defined in `AGENTS.md` — never import across them without explicit justification
- CLAUDE.md and AGENTS.md must not coexist at project root — choose one
<!-- /uncle-dev -->
