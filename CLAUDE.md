# agent-skills

This is the agent-skills project — a collection of production-grade engineering skills for AI coding agents.

## Project Structure

```
skills/       → Core skills (SKILL.md per directory, with colocated reference files)
agents/       → Reusable agent personas (uncle-dev-ag-code-reviewer, uncle-dev-ag-test-engineer, uncle-dev-ag-security-auditor)
hooks/        → Session lifecycle hooks
<!-- BEGIN GENERATED: commands -->
commands/ → Slash commands (31 total): /uncle-dev-acknowledge, /uncle-dev-big-idea, /uncle-dev-brownfield, /uncle-dev-build, /uncle-dev-changelog, /uncle-dev-code-simplify, /uncle-dev-custom-me, /uncle-dev-debt, /uncle-dev-design-docs, /uncle-dev-feature-map, /uncle-dev-knowledge-capture, /uncle-dev-knowledge-maintenance, /uncle-dev-mode, /uncle-dev-next-task, /uncle-dev-openspec-sync, /uncle-dev-overkill-detector, /uncle-dev-plan, /uncle-dev-pre-mortem, /uncle-dev-pro, /uncle-dev-proactive-memory, /uncle-dev-research, /uncle-dev-review, /uncle-dev-setup, /uncle-dev-ship, /uncle-dev-spec, /uncle-dev-spec-annotations, /uncle-dev-spec-graph, /uncle-dev-spec-scan, /uncle-dev-test, /uncle-dev-wrap, /uncle-senior
<!-- END GENERATED: commands -->
docs/         → Setup guides for different tools
scripts/      → Install scripts for Claude Code, Codex, and OpenCode
```

## Skills by Phase

<!-- BEGIN GENERATED: skills-by-phase -->
**Define:** uncle-dev-acknowledge, uncle-dev-design-architecture-docs, uncle-dev-grill, uncle-dev-idea-refine, uncle-dev-research, uncle-dev-spec-driven-development, uncle-dev-ubiquitous-language, uncle-dev-verbalized-sampling
**Brownfield:** uncle-dev-brownfield, uncle-dev-feature-map
**Evaluate:** uncle-senior
**Plan:** uncle-dev-planning-and-task-breakdown
**Build:** uncle-dev-api-and-interface-design, uncle-dev-context-engineering, uncle-dev-frontend-ui-engineering, uncle-dev-incremental-implementation, uncle-dev-source-driven-development, uncle-dev-spec-annotations, uncle-dev-test-driven-development
**Verify:** uncle-dev-browser-testing-with-devtools, uncle-dev-debug-error, uncle-dev-mutation-testing
**Review:** uncle-dev-code-review-and-quality, uncle-dev-dev-code-simplification, uncle-dev-performance-optimization, uncle-dev-security-and-hardening
**Ship:** uncle-dev-changelog, uncle-dev-ci-cd-and-automation, uncle-dev-deprecation-and-migration, uncle-dev-documentation-and-adrs, uncle-dev-git-workflow-and-versioning, uncle-dev-shipping-and-launch, uncle-dev-speech
**Capture:** uncle-dev-knowledge-capture
**Handoff:** uncle-dev-wrap
**Maintain:** uncle-dev-custom-me, uncle-dev-knowledge-maintenance
**Support:** uncle-dev-business-observability, uncle-dev-code-context, uncle-dev-graphify-aware-analysis, uncle-dev-initiative-map, uncle-dev-next-task, uncle-dev-over-engineering-audit, uncle-dev-pre-mortem, uncle-dev-setup-local, uncle-dev-using-agent-skills, uncle-dev-subagent-model-routing
<!-- END GENERATED: skills-by-phase -->

## Conventions

- Every skill lives in `skills/<name>/SKILL.md`
- YAML frontmatter with `name` and `description` fields
- Description starts with what the skill does (third person), followed by trigger conditions ("Use when...")
- Every skill has: Overview, When to Use, Process, Common Rationalizations, Red Flags, Verification
- Supporting reference files (checklists, patterns) live alongside their SKILL.md in the same skill directory
- Supporting files only created when content exceeds 100 lines
- Architecture intent flows HLD → LLD → EARS specs → tests → code. Code and tests reference durable behavior via `@spec` annotations. See `uncle-dev-design-architecture-docs` and `uncle-dev-spec-annotations`.
- **Two spec universes (separate tracks, no automated bridge):**
  - `docs/hld/`, `docs/lld/`, `docs/ears/` use `R-x.y` IDs — coverage is a **MANUAL CHECK** (no scanner validates these IDs against tests).
  - `docs/specs/<segment>-specs.md` with `SEG-AREA-NNN` IDs — coverage is **scanner-enforced** via `scan-spec-coherence.py` / `hooks/spec-coherence-guard.sh` (`[A-Z][A-Z0-9-]*-[0-9]+` regex). The scanner is not extended to accept `R-x.y` IDs.

## Commands

- `npm test` — Not applicable (this is a documentation project)
- Validate: Check that all SKILL.md files have valid YAML frontmatter with name and description
- `bash scripts/lint-skills.sh [path]` — lint SKILL.md files with nori-lint (report-only; `--enforce` to gate, `--deep` + `ANTHROPIC_API_KEY` for LLM rules; rule config in `scripts/nori-lint.config.json`; setup guide: `docs/originals/lint-skills-setup.md`)

## Boundaries

- Always: Follow the `docs/originals/skill-anatomy.md` format for new skills
- Always: Read project configuration through `scripts/uncle-dev-config.sh` (scalar or `--list` mode). No script, command, hook, or helper may open `.agents/uncle-dev-setup.yaml` directly. If the existing API doesn't expose a shape you need (e.g., iterating an array), extend `uncle-dev-config.sh` — never bypass it. This is the single source of truth for config semantics, validation, and future schema migrations. Audit guard: `grep -rn 'open.*setup\.yaml\|cat.*setup\.yaml\|yq.*setup\.yaml' scripts/ .claude/ hooks/` should return empty (only the helper itself reads the YAML).
- Never: Add skills that are vague advice instead of actionable processes
- Never: Duplicate content between skills — reference other skills instead

## Graphify — conditional for subagents

Every spawned agent or subagent MUST first check whether the graph exists:
```bash
[ -f graphify-out/graph.json ] && echo "graphify: ON" || echo "graphify: OFF"
```
If `graphify-out/graph.json` exists (ON):
- Architecture/structure question → `graphify query "<question>" --budget 1500`
- "How does X work?" → `graphify explain "<X>"`
- "How does X relate to Y?" → `graphify path "<X>" "<Y>"`
- Read `graphify-out/GRAPH_REPORT.md` for god nodes and community structure

If the graph does not exist (OFF), fall back to grep/Read/Glob directly — no error.

Applies to: inline scouts, repo-research-analyst, code reviewers, investigate sessions — every agent spawned in this repo.

<!-- uncle-dev -->
## uncle-dev

This project uses uncle-dev engineering skills for structured AI-assisted development.

### Skills by Phase

See the [Skills by Phase](#skills-by-phase) section above for the canonical phase table.

### Skill loading

When a command prints `SKILL: <ref>` lines, read each `<ref>` as the active skill — if `<ref>` is `uncle-dev:<name>`, use the bundled plugin skill; if it is a file path, read that file instead. When a command also prints `COMPANION: <path>` lines, read each companion file **after** the active skill and merge its `## Companion Additions` into your working context.

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
- `CLAUDE.md` is the single root instruction file for this project; `AGENTS.md` at project root is a stub pointer only (required for OpenCode/installer compatibility)

### OpenCode Integration

OpenCode uses a skill-driven execution model. When a task matches a skill, invoke it immediately — never implement directly if a skill applies.

Intent → Skill mapping:
- Feature / new functionality → `uncle-dev-spec-driven-development`, then `uncle-dev-incremental-implementation` + `uncle-dev-test-driven-development`
- Planning / breakdown → `uncle-dev-planning-and-task-breakdown`
- Bug / failure / unexpected behavior → `uncle-dev-debug-error`
- Code review → `uncle-dev-code-review-and-quality`
- Refactoring / simplification → `uncle-dev-dev-code-simplification`
- API or interface design → `uncle-dev-api-and-interface-design`
- UI work → `uncle-dev-frontend-ui-engineering`
- Design decision needing sign-off → `uncle-dev-acknowledge`
- Problem just solved → `uncle-dev-knowledge-capture`
- Architecture questions → `uncle-dev-research`

OpenCode lifecycle (OpenCode does not support slash commands — follow internally):
- DEFINE → `uncle-dev-spec-driven-development`
- PLAN → `uncle-dev-planning-and-task-breakdown`
- BUILD → `uncle-dev-next-task` then `uncle-dev-incremental-implementation` + `uncle-dev-test-driven-development`
- VERIFY → `uncle-dev-debug-error`
- REVIEW → `uncle-dev-code-review-and-quality`
- SHIP → `uncle-dev-shipping-and-launch`

### Uncle Dev Slash Commands (Claude Code / Codex)

When the user types any `/uncle-dev-*` command, invoke the corresponding skill immediately. Do not ask for clarification first.

<!-- BEGIN GENERATED: commands-table -->
| Command | Skill |
|---------|-------|
| /uncle-dev-acknowledge | uncle-dev-acknowledge |
| /uncle-dev-big-idea | uncle-dev-initiative-map |
| /uncle-dev-brownfield | uncle-dev-brownfield |
| /uncle-dev-build | uncle-dev-incremental-implementation + uncle-dev-test-driven-development |
| /uncle-dev-changelog | uncle-dev-changelog |
| /uncle-dev-code-simplify | uncle-dev-dev-code-simplification |
| /uncle-dev-custom-me | uncle-dev-custom-me |
| /uncle-dev-debt | uncle-dev-over-engineering-audit |
| /uncle-dev-design-docs | uncle-dev-design-architecture-docs |
| /uncle-dev-feature-map | uncle-dev-feature-map |
| /uncle-dev-knowledge-capture | uncle-dev-knowledge-capture |
| /uncle-dev-knowledge-maintenance | uncle-dev-knowledge-maintenance |
| /uncle-dev-mode | (session strictness — strict/balanced/fast) |
| /uncle-dev-next-task | uncle-dev-next-task |
| /uncle-dev-openspec-sync | (openspec tracker refresh) |
| /uncle-dev-overkill-detector | uncle-dev-over-engineering-audit |
| /uncle-dev-plan | uncle-dev-planning-and-task-breakdown |
| /uncle-dev-pre-mortem | uncle-dev-pre-mortem |
| /uncle-dev-pro | (senior-collaborator mode) |
| /uncle-dev-proactive-memory | uncle-dev-using-agent-skills |
| /uncle-dev-research | uncle-dev-research |
| /uncle-dev-review | uncle-dev-code-review-and-quality |
| /uncle-dev-setup | uncle-dev-setup-local |
| /uncle-dev-ship | uncle-dev-shipping-and-launch |
| /uncle-dev-spec | uncle-dev-spec-driven-development |
| /uncle-dev-spec-annotations | uncle-dev-spec-annotations |
| /uncle-dev-spec-graph | uncle-dev-spec-annotations |
| /uncle-dev-spec-scan | uncle-dev-spec-annotations |
| /uncle-dev-test | uncle-dev-test-driven-development |
| /uncle-dev-wrap | uncle-dev-wrap |
| /uncle-senior | uncle-senior |
<!-- END GENERATED: commands-table -->
<!-- /uncle-dev -->
