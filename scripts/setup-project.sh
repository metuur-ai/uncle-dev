#!/usr/bin/env bash
# setup-project.sh — wire uncle-dev into a target project
#
# Usage:
#   bash setup-project.sh           # first-time setup
#   bash setup-project.sh --update  # re-ask all preference questions
#
# What this script handles (equivalent to /uncle-dev-setup Steps 1, 3, 4, 5, 6):
#   1. Detect active tools (Claude Code / Codex / OpenCode)
#   2. Ask preference questions (sdd_mode, spec_annotations, graphify)
#   3. Create required directories and write .agents/uncle-dev-setup.yaml
#   4. Clean .claude/settings.json (remove any bad ${CLAUDE_PLUGIN_ROOT} hooks)
#   5. Inject <!-- uncle-dev --> block into CLAUDE.md (Claude Code only)
#   6. Add .devlocal/ to .gitignore
#   7. Print verification summary
#
# Plugin installation (Step 2 of the skill) is separate:
#   bash /path/to/agent-skills/scripts/install-claude.sh

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"
PROJECT_ROOT="$(pwd)"
TODAY="$(date +%Y-%m-%d)"
PROJECT_NAME="$(basename "${PROJECT_ROOT}")"

# ── flags ─────────────────────────────────────────────────────────────────────

UPDATE_MODE=0
for arg in "$@"; do
  case "${arg}" in
    --update|-u) UPDATE_MODE=1 ;;
    --help|-h)
      echo "Usage: bash setup-project.sh [--update]"
      echo "  (no flag)  First-time setup. Skips preference questions if config exists."
      echo "  --update   Re-ask all preference questions and overwrite existing config."
      exit 0 ;;
    *) echo "Unknown flag: ${arg}" >&2; exit 1 ;;
  esac
done

# ── utilities ─────────────────────────────────────────────────────────────────

log()  { echo "  $*"; }
ok()   { echo "  ✓ $*"; }
warn() { echo "  ⚠ $*"; }
fail() { echo "Error: $*" >&2; exit 1; }

ask() {
  # ask PROMPT DEFAULT → prints answer on stdout
  local prompt="$1" default="$2"
  printf "  %s [%s]: " "${prompt}" "${default}" >&2
  local answer
  read -r answer
  echo "${answer:-${default}}"
}

ask_yn() {
  # ask_yn PROMPT DEFAULT(y|n) → prints "true" or "false" on stdout
  local prompt="$1" default="$2"
  local display
  [[ "${default}" == "y" ]] && display="Y/n" || display="y/N"
  printf "  %s [%s]: " "${prompt}" "${display}" >&2
  local answer
  read -r answer
  answer="${answer:-${default}}"
  answer="$(echo "${answer}" | tr '[:upper:]' '[:lower:]')"
  [[ "${answer}" == "y" ]] && echo "true" || echo "false"
}

require_jq() {
  command -v jq >/dev/null 2>&1 || fail "jq is required. Install: brew install jq"
}

# ── step 1: detect tools ──────────────────────────────────────────────────────

echo ""
echo "uncle-dev project setup"
echo "────────────────────────────────────────────"
echo "Project: ${PROJECT_ROOT}"
echo ""

TOOL_CLAUDE=0
TOOL_CODEX=0
TOOL_OPENCODE=0

[[ -d "${HOME}/.claude/plugins" ]] && TOOL_CLAUDE=1
([[ -f "${HOME}/.agents/plugins/marketplace.json" ]] || [[ -d "${HOME}/plugins" ]]) && TOOL_CODEX=1
([[ -d "${HOME}/.config/opencode" ]] || [[ -f "${PROJECT_ROOT}/AGENTS.md" ]]) && TOOL_OPENCODE=1

ACTIVE_TOOLS=()
[[ "${TOOL_CLAUDE}" -eq 1 ]] && ACTIVE_TOOLS+=("claude-code")
[[ "${TOOL_CODEX}" -eq 1 ]]  && ACTIVE_TOOLS+=("codex")
[[ "${TOOL_OPENCODE}" -eq 1 ]] && ACTIVE_TOOLS+=("opencode")

echo "Detected tools:"
[[ "${TOOL_CLAUDE}"   -eq 1 ]] && ok "Claude Code" || log "- Claude Code (not found)"
[[ "${TOOL_CODEX}"    -eq 1 ]] && ok "Codex"       || log "- Codex (not found)"
[[ "${TOOL_OPENCODE}" -eq 1 ]] && ok "OpenCode"    || log "- OpenCode (not found)"

[[ ${#ACTIVE_TOOLS[@]} -eq 0 ]] && fail "No supported AI tools detected. Install Claude Code, Codex, or OpenCode first."

ACTIVE_TOOLS_YAML="$(printf '[%s]' "$(IFS=', '; echo "${ACTIVE_TOOLS[*]}")")"

# ── step 2: preferences ───────────────────────────────────────────────────────

CONFIG_FILE="${PROJECT_ROOT}/.agents/uncle-dev-setup.yaml"

# If config already exists, skip preference questions and only update tool.* fields
if [[ "${UPDATE_MODE}" -eq 1 ]]; then
  echo ""
  echo "Update mode — re-asking all preference questions."
  SKIP_PREFS=0
elif [[ -f "${CONFIG_FILE}" ]]; then
  warn ".agents/uncle-dev-setup.yaml already exists — preserving preferences, updating tool fields only"
  warn "Run with --update to reconfigure preferences."
  SKIP_PREFS=1
else
  SKIP_PREFS=0
fi

if [[ "${SKIP_PREFS}" -eq 0 ]]; then
  echo ""
  echo "Preferences (press Enter to accept default):"
  echo ""

  echo "  SDD mode — how should /uncle-dev-spec start?"
  echo "    openspec  → scaffold OpenSpec change first (default)"
  echo "    lid-ears  → elicit requirements via LID EARS first"
  SDD_MODE="$(ask "sdd_mode" "openspec")"
  [[ "${SDD_MODE}" == "openspec" || "${SDD_MODE}" == "lid-ears" ]] \
    || { warn "Unknown sdd_mode '${SDD_MODE}', defaulting to openspec"; SDD_MODE="openspec"; }

  echo ""
  SPEC_ANNOTATIONS="$(ask_yn "Require @spec IDs linking code to specs?" "y")"

  echo ""
  GRAPHIFY="$(ask_yn "Have you run 'graphify .' on this project?" "n")"
else
  # Read existing values (best-effort via grep, no yq dependency)
  SDD_MODE="$(grep 'sdd_mode:' "${CONFIG_FILE}" 2>/dev/null | awk -F'"' '{print $2}' || echo "openspec")"
  SPEC_ANNOTATIONS="$(grep 'spec_annotations:' "${CONFIG_FILE}" 2>/dev/null | awk '{print $2}' || echo "true")"
  GRAPHIFY="$(grep 'graphify:' "${CONFIG_FILE}" 2>/dev/null | awk '{print $2}' || echo "false")"
fi

# ── step 3: create directories and write config ───────────────────────────────

echo ""
echo "Scaffolding project directories..."

mkdir -p \
  "${PROJECT_ROOT}/openspec/specs" \
  "${PROJECT_ROOT}/openspec/changes" \
  "${PROJECT_ROOT}/.uncle-dev/learns" \
  "${PROJECT_ROOT}/.devlocal" \
  "${PROJECT_ROOT}/.agents"

ok "openspec/specs  openspec/changes  .uncle-dev/learns  .devlocal  .agents"

if [[ "${SKIP_PREFS}" -eq 0 ]]; then
  TEMPLATE="${REPO_ROOT}/skills/uncle-dev-setup/uncle-dev-setup.template.yaml"
  [[ -f "${TEMPLATE}" ]] || fail "Template not found: ${TEMPLATE}"

  sed \
    -e "s|__PROJECT_NAME__|${PROJECT_NAME}|g" \
    -e "s|__SETUP_DATE__|${TODAY}|g" \
    -e "s|active: \[\]|active: ${ACTIVE_TOOLS_YAML}|g" \
    -e "s|agent_skills_root: \"\"|agent_skills_root: \"${REPO_ROOT}\"|g" \
    -e "s|sdd_mode: \"openspec\"|sdd_mode: \"${SDD_MODE}\"|g" \
    -e "s|spec_annotations: true|spec_annotations: ${SPEC_ANNOTATIONS}|g" \
    -e "s|graphify: false|graphify: ${GRAPHIFY}|g" \
    "${TEMPLATE}" > "${CONFIG_FILE}"

  ok ".agents/uncle-dev-setup.yaml written (sdd_mode=${SDD_MODE})"
else
  # Update only tool.active and agent_skills_root in existing config
  TMPFILE="${CONFIG_FILE}.tmp"
  sed \
    -e "s|active: \[.*\]|active: ${ACTIVE_TOOLS_YAML}|g" \
    -e "s|agent_skills_root: \".*\"|agent_skills_root: \"${REPO_ROOT}\"|g" \
    "${CONFIG_FILE}" > "${TMPFILE}"
  mv "${TMPFILE}" "${CONFIG_FILE}"
  ok ".agents/uncle-dev-setup.yaml updated (tool fields only)"
fi

# ── step 4: clean and ensure .claude/settings.json (Claude Code only) ────────
# Plugin hooks (session-start, pre-commit-guard, etc.) are defined in the
# plugin's own hooks/hooks.json and fire automatically when the plugin is
# installed. Do NOT copy them into .claude/settings.json — ${CLAUDE_PLUGIN_ROOT}
# is unavailable in project-level settings and causes hook errors on every call.
# This step also removes any bad hooks written by a previous setup run.

if [[ "${TOOL_CLAUDE}" -eq 1 ]]; then
  require_jq
  mkdir -p "${PROJECT_ROOT}/.claude"
  SETTINGS_FILE="${PROJECT_ROOT}/.claude/settings.json"
  [[ -f "${SETTINGS_FILE}" ]] || echo '{}' > "${SETTINGS_FILE}"

  # Remove any hook entries that reference ${CLAUDE_PLUGIN_ROOT} — those belong
  # in the plugin's hooks/hooks.json, not in project settings.json.
  CLEANED="$(jq '
    if .hooks then
      .hooks |= with_entries(
        .value = [
          .value[] |
          if .hooks then
            .hooks = [.hooks[] | select(.command | test("\\$\\{CLAUDE_PLUGIN_ROOT\\}") | not)]
          else . end
        ] |
        select((.value | length) > 0 and (.value[].hooks? // [] | length) > 0)
      ) |
      if (.hooks | length) == 0 then del(.hooks) else . end
    else . end
  ' "${SETTINGS_FILE}")"
  echo "${CLEANED}" > "${SETTINGS_FILE}"

  ok ".claude/settings.json — cleaned (removed any \${CLAUDE_PLUGIN_ROOT} hooks; plugin loads its own)"
fi

# ── step 5: inject CLAUDE.md block (Claude Code only) ────────────────────────

if [[ "${TOOL_CLAUDE}" -eq 1 ]]; then
  echo ""
  echo "Injecting CLAUDE.md rules..."

  CLAUDE_MD="${PROJECT_ROOT}/CLAUDE.md"

  if grep -q '<!-- uncle-dev -->' "${CLAUDE_MD}" 2>/dev/null; then
    ok "CLAUDE.md already contains <!-- uncle-dev --> block — skipping"
  else
    [[ -f "${CLAUDE_MD}" ]] || touch "${CLAUDE_MD}"
    cat >> "${CLAUDE_MD}" <<'BLOCK'

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

### Workflow rules
- Run `/uncle-dev-spec` before any non-trivial feature
- Run `/uncle-dev-plan` after spec, before coding
- Check `.agents/uncle-dev-setup.yaml` for project-specific overrides and sdd_mode
<!-- /uncle-dev -->
BLOCK
    ok "CLAUDE.md — <!-- uncle-dev --> block appended"
  fi
fi

# ── step 6: gitignore ─────────────────────────────────────────────────────────

GITIGNORE="${PROJECT_ROOT}/.gitignore"
if grep -qxF '.devlocal/' "${GITIGNORE}" 2>/dev/null; then
  ok ".gitignore already contains .devlocal/"
else
  echo '.devlocal/' >> "${GITIGNORE}"
  ok ".gitignore — added .devlocal/"
fi

# ── summary ───────────────────────────────────────────────────────────────────

echo ""
echo "────────────────────────────────────────────"
echo "uncle-dev project setup complete"
echo ""
echo "Common"
[[ -d "${PROJECT_ROOT}/openspec" ]]          && ok "openspec/"          || warn "openspec/ missing"
[[ -d "${PROJECT_ROOT}/.uncle-dev/learns" ]] && ok ".uncle-dev/learns/" || warn ".uncle-dev/learns/ missing"
[[ -d "${PROJECT_ROOT}/.devlocal" ]]         && ok ".devlocal/"         || warn ".devlocal/ missing"
[[ -f "${CONFIG_FILE}" ]]                    && ok ".agents/uncle-dev-setup.yaml (sdd_mode=${SDD_MODE})" || warn ".agents/uncle-dev-setup.yaml missing"

if [[ "${TOOL_CLAUDE}" -eq 1 ]]; then
  echo ""
  echo "Claude Code"
  [[ -f "${PROJECT_ROOT}/.claude/settings.json" ]] && ok ".claude/settings.json exists" || warn ".claude/settings.json missing"
  grep -q '<!-- uncle-dev -->' "${PROJECT_ROOT}/CLAUDE.md" 2>/dev/null && ok "CLAUDE.md contains uncle-dev block" || warn "CLAUDE.md missing uncle-dev block"
  log "(plugin hooks fire from plugin's hooks/hooks.json — not written to settings.json)"
fi

echo ""
echo "Next steps:"
echo "  1. If plugin not installed: bash ${REPO_ROOT}/scripts/install-claude.sh"
echo "  2. Restart Claude Code to activate hooks"
echo "  3. Open .agents/uncle-dev-setup.yaml to review project.type and framework"
echo ""
