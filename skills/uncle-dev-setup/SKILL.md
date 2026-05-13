---
name: uncle-dev-setup
description: Wires uncle-dev fully into a target project for Claude Code, Codex, and/or OpenCode. Installs the plugin for each detected tool, scaffolds required directories, writes the project config file, injects hooks into .claude/settings.json (Claude Code only), and adds uncle-dev rules to CLAUDE.md or AGENTS.md. Use when setting up uncle-dev in a new or existing project, when hooks are not firing, or when the session does not load the Skill Discovery flowchart on start.
---

# Uncle Dev Project Setup

## Overview

The install scripts (`install-claude.sh`, `install-codex.sh`, `install-opencode.sh`) copy plugin files globally but do not configure any target project. This skill closes that gap: it detects which AI coding tools are active, runs the correct install for each, and wires uncle-dev into the current project directory — hooks, rules, directories, and config — so every subsequent session is fully equipped.

Supported tools: **Claude Code**, **Codex**, **OpenCode**. All three can be configured in a single run.

## When to Use

- Starting a new project and want uncle-dev workflows from day one
- Joining an existing project that lacks uncle-dev configuration
- Claude Code sessions start without the Skill Discovery flowchart (SessionStart hook not firing)
- Commits bypass quality checks (pre-commit-guard not active)
- CLAUDE.md / AGENTS.md does not contain uncle-dev rules

## When NOT to Use

- The project is the uncle-dev repository itself — do not run setup inside `agent-skills/`
- uncle-dev is already fully configured — check Step 1 before re-running
- You are using Cursor, Windsurf, or GitHub Copilot — see `docs/cursor-setup.md`, `docs/windsurf-setup.md`, `docs/copilot-setup.md`

## Core Process

### Step 1 — Detect active tools

Run all detection checks and record results:

```bash
# Claude Code
[ -d ~/.claude/plugins ] && echo "claude-code: detected" || echo "claude-code: not found"

# Codex
[ -f ~/.agents/plugins/marketplace.json ] || [ -d ~/plugins ] \
  && echo "codex: detected" || echo "codex: not found"

# OpenCode
[ -d ~/.config/opencode ] || [ -f AGENTS.md ] \
  && echo "opencode: detected" || echo "opencode: not found"
```

Also check existing project config and state:

```bash
[ -f .agents/uncle-dev-setup.yaml ] && echo "config: EXISTS (will preserve)" || echo "config: MISSING"
[ -f .claude/settings.json ]        && echo ".claude/settings.json: EXISTS" || echo "MISSING"
[ -f CLAUDE.md ]                    && echo "CLAUDE.md: EXISTS" || echo "MISSING"
[ -f AGENTS.md ]                    && echo "AGENTS.md: EXISTS" || echo "MISSING"
```

Record which tools are detected. Proceed with setup for all detected tools. If none are found, report and stop.

---

### Step 2 — Install uncle-dev plugin (per tool)

Locate the `agent-skills` repository root. Check common locations:

```bash
# Try environment variable first
echo "${UNCLE_DEV_ROOT:-not-set}"

# Then common locations
ls ~/others/ai-agents/production-grade-agent-skills 2>/dev/null && echo "found at ~/others/ai-agents/production-grade-agent-skills"
ls ~/agent-skills 2>/dev/null && echo "found at ~/agent-skills"
ls ./agent-skills 2>/dev/null && echo "found at ./agent-skills"
```

Record the path as `AGENT_SKILLS_ROOT`. If not found, guide the user to clone it or use the marketplace install path.

#### Claude Code

Check if already installed:
```bash
jq '.plugins | has("uncle-dev-agent-skills@uncle-dev-agent-skills")' \
  ~/.claude/plugins/installed_plugins.json 2>/dev/null || echo "false"
```

If not installed:
- With local clone: `bash "${AGENT_SKILLS_ROOT}/scripts/install-claude.sh"`
- Without clone: `/plugin install uncle-dev@uncle-dev-agent-skills`

Re-verify:
```bash
jq '.plugins | has("uncle-dev-agent-skills@uncle-dev-agent-skills")' \
  ~/.claude/plugins/installed_plugins.json
# must return: true
```

#### Codex

Check if already installed:
```bash
[ -f ~/plugins/uncle-dev/.codex-plugin/plugin.json ] && echo "installed" || echo "not-installed"
# or for local scope:
[ -f plugins/uncle-dev/.codex-plugin/plugin.json ] && echo "installed (local)" || echo "not-installed (local)"
```

If not installed:
- User scope: `bash "${AGENT_SKILLS_ROOT}/scripts/install-codex.sh"`
- Local scope: `bash "${AGENT_SKILLS_ROOT}/scripts/install-codex.sh --scope local ."`

The script handles marketplace registration in `.agents/plugins/marketplace.json` automatically.

#### OpenCode

Check if already installed:
```bash
[ -f ~/.config/opencode/AGENTS.md ] && echo "global installed" || echo "not installed globally"
[ -f AGENTS.md ] && echo "local AGENTS.md exists" || echo "no local AGENTS.md"
[ -d .opencode/skills ] && echo "local skills installed" || echo "no local skills"
```

If not installed:
- Global: `bash "${AGENT_SKILLS_ROOT}/scripts/install-opencode.sh --scope global"`
- Local: `bash "${AGENT_SKILLS_ROOT}/scripts/install-opencode.sh --scope local ."`

---

### Step 3 — Scaffold directories and write project config

Create required directories (all tools):

```bash
mkdir -p openspec/specs openspec/changes .uncle-dev/learns .devlocal .agents
```

Write `.agents/uncle-dev-setup.yaml` from the colocated template (`uncle-dev-setup.template.yaml`), substituting:
- `project.name` ← `$(basename $(pwd))`
- `setup_date` ← today's date (YYYY-MM-DD)
- `tool.active` ← list of detected tools from Step 1 (e.g., `[claude-code, codex]`)
- `tool.agent_skills_root` ← the `AGENT_SKILLS_ROOT` path found in Step 2

If `.agents/uncle-dev-setup.yaml` already exists, read it first and preserve fields that are already customized. Only update `tool.*` fields.

---

### Step 4 — Wire hooks (Claude Code only)

Skip this step if Claude Code was not detected in Step 1.

Read `.agents/uncle-dev-setup.yaml` `hooks.*` toggles. Read the existing `.claude/settings.json` (create `{}` if missing). Merge only hooks whose `command` string is not already present — never duplicate.

Full hook set (include only those whose toggle is `true`):

```json
{
  "hooks": {
    "SessionStart": [
      {
        "hooks": [
          { "type": "command", "command": "bash ${CLAUDE_PLUGIN_ROOT}/hooks/session-start.sh" }
        ]
      }
    ],
    "PreToolUse": [
      {
        "matcher": "Edit|Write",
        "hooks": [
          { "type": "command", "command": "bash ${CLAUDE_PLUGIN_ROOT}/hooks/check-agents-md.sh" },
          { "type": "command", "command": "bash ${CLAUDE_PLUGIN_ROOT}/hooks/openspec-guard.sh" },
          { "type": "command", "command": "bash ${CLAUDE_PLUGIN_ROOT}/hooks/spec-coherence-guard.sh" }
        ]
      },
      {
        "matcher": "Bash",
        "hooks": [
          { "type": "command", "command": "bash ${CLAUDE_PLUGIN_ROOT}/hooks/pre-commit-guard.sh" },
          { "type": "command", "command": "bash ${CLAUDE_PLUGIN_ROOT}/hooks/destructive-command-guard.sh" },
          { "type": "command", "command": "bash ${CLAUDE_PLUGIN_ROOT}/hooks/spec-coherence-guard.sh" }
        ]
      }
    ],
    "PostToolUse": [
      {
        "matcher": "Bash",
        "hooks": [
          { "type": "command", "command": "bash ${CLAUDE_PLUGIN_ROOT}/hooks/knowledge-capture-nudge.sh" }
        ]
      }
    ]
  }
}
```

Hook-to-toggle mapping:
| Hook command | Toggle |
|---|---|
| `session-start.sh` | `hooks.session_start` |
| `pre-commit-guard.sh` | `hooks.pre_commit` |
| `spec-coherence-guard.sh` | `hooks.spec_coherence` |
| `openspec-guard.sh` | `hooks.openspec_guard` |
| `destructive-command-guard.sh` | `hooks.destructive_command_guard` |
| `knowledge-capture-nudge.sh` | `hooks.knowledge_capture_nudge` |

Codex and OpenCode do not have a hook system — the install scripts handle all configuration for those tools.

---

### Step 5 — Inject rules (tool-specific)

#### Claude Code — inject CLAUDE.md rules block

Check if `CLAUDE.md` already contains `<!-- uncle-dev -->`. If yes, skip.

If `CLAUDE.md` does not exist, create it. Then append:

```markdown
<!-- uncle-dev -->
## uncle-dev

This project uses uncle-dev engineering skills for structured AI-assisted development.

### Skills by Phase
**Define:** uncle-dev-research, uncle-dev-spec-driven-development, uncle-dev-design-architecture-docs, uncle-dev-acknowledge
**Plan:** uncle-dev-planning-and-task-breakdown
**Build:** uncle-dev-incremental-implementation, uncle-dev-test-driven-development, uncle-dev-spec-annotations, uncle-dev-context-engineering, uncle-dev-frontend-ui-engineering, uncle-dev-api-and-interface-design
**Verify:** uncle-dev-browser-testing-with-devtools, uncle-dev-debug-error
**Review:** uncle-dev-code-review-and-quality, uncle-dev-security-and-hardening, uncle-dev-performance-optimization
**Ship:** uncle-dev-git-workflow-and-versioning, uncle-dev-shipping-and-launch, uncle-dev-documentation-and-adrs
**Capture:** uncle-dev-knowledge-capture
**Maintain:** uncle-dev-knowledge-maintenance

### Conventions
- Architecture flows HLD → LLD → EARS specs → tests → code
- Code and tests reference durable behavior via `@spec` annotations
- OpenSpec artifacts tracked in `openspec/changes/<change-id>/` (proposal, design, tasks, execution, handoff)
- Personal scratchpad in `.devlocal/<user>/` (gitignored, not shared)
- Team learnings captured in `.uncle-dev/learns/`
- Companion skills defined in `.agents/uncle-dev-setup.yaml` under `skills.companions`

### Workflow rules
- Run `/uncle-dev-spec` before any non-trivial feature (`preferences.sdd_required: true`)
- Run `/uncle-dev-plan` after spec, before coding
- Check `.agents/uncle-dev-setup.yaml` for project-specific skill overrides and companion skills
<!-- /uncle-dev -->
```

#### OpenCode — check AGENTS.md

`install-opencode.sh` already writes `AGENTS.md`. Verify it was created:

```bash
[ -f AGENTS.md ] && echo "AGENTS.md: OK" || echo "AGENTS.md: MISSING — re-run install-opencode.sh"
```

If the project has a local `AGENTS.md` but it does not reference `/uncle-dev-setup`, append the command entry:

```markdown
| /uncle-dev-setup | uncle-dev-setup |
```

to the appropriate command table in AGENTS.md.

#### Codex — no rules injection needed

`install-codex.sh` registers the plugin in `.agents/plugins/marketplace.json`. Codex discovers skills from the plugin bundle. No additional rules file is required.

---

### Step 6 — Gitignore and verification

Add `.devlocal/` to `.gitignore` (all tools):

```bash
grep -qxF '.devlocal/' .gitignore 2>/dev/null || echo '.devlocal/' >> .gitignore
```

Print the verification summary, marking each item per detected tool:

```
uncle-dev setup complete
─────────────────────────────────────────────
Common (all tools)
 [✓/✗] openspec/           exists
 [✓/✗] .uncle-dev/learns/  exists
 [✓/✗] .devlocal/          exists
 [✓/✗] .agents/            exists
 [✓/✗] .agents/uncle-dev-setup.yaml  written
 [✓/✗] .gitignore          contains .devlocal/

Claude Code
 [✓/✗/—] Plugin in installed_plugins.json
 [✓/✗/—] .claude/settings.json  contains uncle-dev hooks
 [✓/✗/—] CLAUDE.md              contains <!-- uncle-dev --> block

Codex
 [✓/✗/—] Plugin bundle in plugins/uncle-dev/ (or ~/plugins/uncle-dev/)
 [✓/✗/—] .agents/plugins/marketplace.json  contains uncle-dev entry

OpenCode
 [✓/✗/—] AGENTS.md              exists and references uncle-dev skills
 [✓/✗/—] .opencode/skills/      populated (or ~/.config/opencode/skills/)

─────────────────────────────────────────────
Next steps:
  1. Open .agents/uncle-dev-setup.yaml — set project.type, language, framework
  2. Claude Code: restart to activate hooks
  3. Codex: verify with `codex plugin list`
  4. OpenCode: verify AGENTS.md is loaded in your session
```

---

## Common Rationalizations

| Rationalization | Reality |
|---|---|
| "install-claude.sh already set everything up" | The install script copies plugin files globally — it never writes to your project's `.claude/settings.json`, CLAUDE.md, or directory structure |
| "I only need one tool, skip the others" | The skill checks what is installed and skips tools that aren't detected — no manual skipping needed |
| "Codex doesn't need hooks, so setup is pointless for it" | The shared directories (`openspec/`, `.uncle-dev/`) and `.agents/uncle-dev-setup.yaml` config apply to all tools regardless of hooks |
| "AGENTS.md is already there from the repo" | The project AGENTS.md (if it exists) may be a generic placeholder — this step ensures the `/uncle-dev-setup` command entry is registered |
| "The hooks are optional — the skill still works" | Without hooks, commits bypass quality checks, the session never loads the Skill Discovery flowchart, and spec coherence is never enforced |
| "I'll add the CLAUDE.md rules manually later" | Without the rules block, the agent starts each session with no awareness of uncle-dev workflows and will skip the SDD gate |

## Red Flags

- Session starts without the Skill Discovery flowchart being printed (Claude Code: SessionStart hook not wired)
- Commits go through with placeholder messages or console.log left in staged files (pre-commit-guard missing)
- CLAUDE.md exists but has no `<!-- uncle-dev -->` block (Step 5 Claude Code section was skipped)
- AGENTS.md exists but has no uncle-dev command table (Step 5 OpenCode section was skipped)
- `.agents/uncle-dev-setup.yaml` is absent (Step 3 was skipped, project config unknown)
- `tool.active` in config is empty (Step 1 detection failed, setup ran without a known target)
- Codex cannot find uncle-dev skills (plugin not registered in marketplace.json)
- `.devlocal/` is tracked in git (Step 6 gitignore step was skipped)

## Verification

- [ ] `.agents/uncle-dev-setup.yaml` exists and `tool.active` lists the correct tools
- [ ] `openspec/`, `.uncle-dev/learns/`, `.devlocal/`, `.agents/` all exist
- [ ] `git check-ignore .devlocal/` returns `.devlocal/`

**Claude Code:**
- [ ] `jq '.plugins | has("uncle-dev-agent-skills@uncle-dev-agent-skills")' ~/.claude/plugins/installed_plugins.json` returns `true`
- [ ] `.claude/settings.json` contains `session-start.sh` in a SessionStart hook
- [ ] `CLAUDE.md` contains `<!-- uncle-dev -->` and `<!-- /uncle-dev -->`
- [ ] Restart Claude Code in the project — session prints the Skill Discovery flowchart
- [ ] Run `git commit -m "x"` — `pre-commit-guard.sh` blocks it

**Codex:**
- [ ] `plugins/uncle-dev/.codex-plugin/plugin.json` exists (local) or `~/plugins/uncle-dev/` exists (user)
- [ ] `.agents/plugins/marketplace.json` contains an uncle-dev entry

**OpenCode:**
- [ ] `AGENTS.md` exists at project root or `~/.config/opencode/AGENTS.md` exists
- [ ] `.opencode/skills/` is populated (local) or `~/.config/opencode/skills/` (global)
- [ ] Verify with: `opencode agent list` or check that `/uncle-dev-spec` is recognized in a session
