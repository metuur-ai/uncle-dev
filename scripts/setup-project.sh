#!/usr/bin/env bash
# setup-project.sh — wire uncle-dev into a target project
#
# Usage:
#   bash setup-project.sh           # first-time setup
#   bash setup-project.sh --update  # re-ask all preference questions
#
# What this script handles (equivalent to /uncle-dev-setup Steps 1, 3, 4, 5, 6):
#   1. Detect active tools (Claude Code / Codex / OpenCode)
#   2. Ask preference questions (sdd_mode, tdd_mode, execution_profile, spec_annotations, graphify)
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

# agent_skills_root records the GLOBAL uncle-dev installation — where the shared
# scripts, skills, and commands live that every skill, command, and agent needs
# to locate. It necessarily points outside the project.
#
# Resolution is ordered by authority, not convenience:
#   1. A complete checkout containing the running script outranks everything. An
#      explicit clone is a stronger statement of intent than an ambient variable,
#      and it survives plugin upgrades.
#   2. Otherwise CLAUDE_PLUGIN_ROOT, which the harness sets for plugin-provided
#      commands and hooks. It is unset in a plain shell.
#   3. Otherwise the parent of the running script, as before.
#
# Note this does NOT produce an unversioned path: a marketplace install lives
# under a versioned cache directory by construction. The goal is to name the
# installation actually in use, not to strip the version.
#
# REPO_ROOT stays separate and keeps locating the config template (see the
# TEMPLATE assignment below). Deriving the template from this value would let a
# newer script look for its template inside an older installation.
if [[ -f "${REPO_ROOT}/scripts/install-claude.sh" ]] && [[ -d "${REPO_ROOT}/skills" ]]; then
  AGENT_SKILLS_ROOT="${REPO_ROOT}"
elif [[ -n "${CLAUDE_PLUGIN_ROOT:-}" ]]; then
  AGENT_SKILLS_ROOT="${CLAUDE_PLUGIN_ROOT}"
else
  AGENT_SKILLS_ROOT="${REPO_ROOT}"
fi

# ── flags ─────────────────────────────────────────────────────────────────────

UPDATE_MODE=0
NONINTERACTIVE=0
for arg in "$@"; do
  case "${arg}" in
    --update|-u) UPDATE_MODE=1 ;;
    --non-interactive) NONINTERACTIVE=1 ;;
    --help|-h)
      echo "Usage: bash setup-project.sh [--update] [--non-interactive]"
      echo "  (no flag)          First-time setup. Skips preference questions if config exists."
      echo "  --update           Re-ask all preference questions and overwrite existing config."
      echo "  --non-interactive  Take preferences from the environment instead of prompting."
      echo ""
      echo "Non-interactive mode requires ALL five variables below. Any that are unset"
      echo "or hold a disallowed value abort the run before anything is written — no"
      echo "preference is ever silently defaulted in this mode."
      echo ""
      echo "  UNCLE_DEV_PREFERENCES_SDD_MODE           openspec | lid-ears"
      echo "  UNCLE_DEV_PREFERENCES_SPEC_ANNOTATIONS   true | false"
      echo "  UNCLE_DEV_PREFERENCES_TDD_MODE           strict | lite"
      echo "  UNCLE_DEV_PREFERENCES_EXECUTION_PROFILE  fast | balanced | strict"
      echo "  UNCLE_DEV_PREFERENCES_GRAPHIFY           true | false"
      echo ""
      echo "These are the same names uncle-dev-config.sh uses for its override tier."
      echo "To change preferences in an already-configured project, combine the flags:"
      echo "  bash setup-project.sh --update --non-interactive"
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

ask_choice() {
  # ask_choice PROMPT DEFAULT OPT1 OPT2 [...]
  # Re-prompts until the value is one of OPTn.
  local prompt="$1"
  local default="$2"
  shift 2
  local options=("$@")
  local answer=""

  while true; do
    printf "  %s [%s]: " "${prompt}" "${default}" >&2
    read -r answer
    answer="${answer:-${default}}"

    for opt in "${options[@]}"; do
      if [[ "${answer}" == "${opt}" ]]; then
        echo "${answer}"
        return 0
      fi
    done

    warn "Invalid choice '${answer}'. Allowed values: ${options[*]}"
  done
}

require_jq() {
  command -v jq >/dev/null 2>&1 || fail "jq is required. Install: brew install jq"
}

# ── non-interactive preference resolution ─────────────────────────────────────
# Sources the five workflow preferences from the environment instead of stdin,
# reusing the variable names uncle-dev-config.sh already resolves for its
# override tier (see scripts/AGENTS.md) rather than inventing a second
# convention.
#
# Fail-closed by design: every unset or disallowed value is collected and all of
# them are reported together, before anything is written. No default is applied
# in this mode — that is its entire safety property, and the reason the
# interactive default (lid-ears) is deliberately not reused here.
#
# ni_take writes to NI_VALUE instead of echoing: a command substitution runs in
# a subshell and would discard the appends to NI_MISSING / NI_INVALID. bash 3.2
# is the floor, so namerefs are not available.

NI_MISSING=()
NI_INVALID=()
NI_VALUE=""

ni_take() {
  # ni_take VAR_NAME "allowed values ..."
  local var="$1" allowed="$2" value opt
  NI_VALUE=""
  # The ':-' is mandatory. Under 'set -u' a bare indirect expansion of an unset
  # name aborts immediately, which would report only the first missing variable
  # instead of all of them.
  value="${!var:-}"
  if [[ -z "${value}" ]]; then
    NI_MISSING+=("${var}")
    return 0
  fi
  for opt in ${allowed}; do
    if [[ "${value}" == "${opt}" ]]; then
      NI_VALUE="${value}"
      return 0
    fi
  done
  NI_INVALID+=("${var}='${value}' (allowed: ${allowed// /, })")
}

resolve_prefs_from_env() {
  local v
  NI_MISSING=()
  NI_INVALID=()

  ni_take UNCLE_DEV_PREFERENCES_SDD_MODE          "openspec lid-ears";    SDD_MODE="${NI_VALUE}"
  ni_take UNCLE_DEV_PREFERENCES_SPEC_ANNOTATIONS  "true false";           SPEC_ANNOTATIONS="${NI_VALUE}"
  ni_take UNCLE_DEV_PREFERENCES_TDD_MODE          "strict lite";          TDD_MODE="${NI_VALUE}"
  ni_take UNCLE_DEV_PREFERENCES_EXECUTION_PROFILE "fast balanced strict"; EXECUTION_PROFILE="${NI_VALUE}"
  ni_take UNCLE_DEV_PREFERENCES_GRAPHIFY          "true false";           GRAPHIFY="${NI_VALUE}"

  if [[ ${#NI_MISSING[@]} -gt 0 ]] || [[ ${#NI_INVALID[@]} -gt 0 ]]; then
    if [[ ${#NI_MISSING[@]} -gt 0 ]]; then
      echo "" >&2
      echo "  unset:" >&2
      for v in "${NI_MISSING[@]}"; do echo "    ${v}" >&2; done
    fi
    if [[ ${#NI_INVALID[@]} -gt 0 ]]; then
      echo "" >&2
      echo "  invalid:" >&2
      for v in "${NI_INVALID[@]}"; do echo "    ${v}" >&2; done
    fi
    echo "" >&2
    fail "--non-interactive requires all five preferences. Nothing was written. See --help."
  fi

  echo ""
  echo "Preferences (from environment):"
  log "sdd_mode=${SDD_MODE}  spec_annotations=${SPEC_ANNOTATIONS}  tdd-mode=${TDD_MODE}"
  log "execution_profile=${EXECUTION_PROFILE}  graphify=${GRAPHIFY}"
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
  # A config exists, so preferences are preserved and the environment is not
  # consulted. Accepting --non-interactive here would take five variables,
  # discard every one of them, and still exit 0 — indistinguishable from success
  # to any caller checking only the exit status. Refuse instead, and name the
  # flag combination that does what the caller asked for.
  if [[ "${NONINTERACTIVE}" -eq 1 ]]; then
    echo "" >&2
    echo "  A project config already exists, so preferences are preserved and the" >&2
    echo "  UNCLE_DEV_PREFERENCES_* variables would be ignored." >&2
    echo "" >&2
    echo "    to change preferences:  bash setup-project.sh --update --non-interactive" >&2
    echo "    to refresh tool fields: bash setup-project.sh" >&2
    echo "" >&2
    fail "--non-interactive requires --update when a config already exists. Nothing was written."
  fi
  warn ".agents/uncle-dev-setup.yaml already exists — preserving preferences, updating tool fields only"
  warn "Run with --update to reconfigure preferences."
  SKIP_PREFS=1
else
  SKIP_PREFS=0
fi

if [[ "${SKIP_PREFS}" -eq 0 ]] && [[ "${NONINTERACTIVE}" -eq 1 ]]; then
  resolve_prefs_from_env
elif [[ "${SKIP_PREFS}" -eq 0 ]]; then
  echo ""
  echo "Preferences (press Enter to accept default):"
  echo ""

  echo "  SDD mode — how should /uncle-dev-spec start?"
  echo "    openspec  → scaffold OpenSpec change first"
  echo "    lid-ears  → elicit requirements via LID EARS first (default)"
  SDD_MODE="$(ask_choice "sdd_mode" "lid-ears" "openspec" "lid-ears")"

  echo ""
  SPEC_ANNOTATIONS="$(ask_yn "Require @spec IDs linking code to specs?" "y")"

  echo ""
  echo "  TDD mode — how strict should test workflow be?"
  echo "    strict   → full red-green-refactor, prove-it for bugs"
  echo "    lite     → tests for complex/critical logic only (default)"
  TDD_MODE="$(ask_choice "tdd-mode" "lite" "strict" "lite")"

  echo ""
  echo "  Execution profile — speed vs guardrails?"
  echo "    fast      → fastest inner loop, advisory non-critical checks"
  echo "    balanced  → targeted tests per slice, full checks at milestones (default)"
  echo "    strict    → full checks and blocking guards"
  EXECUTION_PROFILE="$(ask_choice "execution_profile" "balanced" "fast" "balanced" "strict")"

  echo ""
  GRAPHIFY="$(ask_yn "Have you run 'graphify .' on this project?" "n")"
else
  # Read existing values via uncle-dev-config.sh (single-reader boundary — R-2.3).
  # Check for legacy key name (warn only, do not block).
  if bash "${SCRIPT_DIR}/uncle-dev-config.sh" preferences.tdd_mode 2>/dev/null | grep -q .; then
    warn "Detected legacy key 'tdd_mode' in .agents/uncle-dev-setup.yaml. Use 'tdd-mode' instead."
    warn "Run --update and confirm choices to rewrite the config with canonical keys."
  fi
  SDD_MODE="$(bash "${SCRIPT_DIR}/uncle-dev-config.sh" preferences.sdd_mode "" 2>/dev/null)"
  SDD_MODE="${SDD_MODE:-lid-ears}"
  SPEC_ANNOTATIONS="$(bash "${SCRIPT_DIR}/uncle-dev-config.sh" preferences.spec_annotations "" 2>/dev/null)"
  SPEC_ANNOTATIONS="${SPEC_ANNOTATIONS:-true}"
  TDD_MODE="$(bash "${SCRIPT_DIR}/uncle-dev-config.sh" preferences.tdd-mode "" 2>/dev/null)"
  TDD_MODE="${TDD_MODE:-lite}"
  EXECUTION_PROFILE="$(bash "${SCRIPT_DIR}/uncle-dev-config.sh" preferences.execution_profile "" 2>/dev/null)"
  EXECUTION_PROFILE="${EXECUTION_PROFILE:-balanced}"
  GRAPHIFY="$(bash "${SCRIPT_DIR}/uncle-dev-config.sh" preferences.graphify "" 2>/dev/null)"
  GRAPHIFY="${GRAPHIFY:-false}"
fi

# ── step 3: create directories and write config ───────────────────────────────

echo ""
echo "Scaffolding project directories..."

# Mode-specific spec directories. Creating openspec/ in lid-ears projects
# pollutes auto-detection in command files (they treat openspec/ as the mode
# marker), so each mode owns its own directories.
if [[ "${SDD_MODE}" == "lid-ears" ]]; then
  mkdir -p \
    "${PROJECT_ROOT}/docs/hld" \
    "${PROJECT_ROOT}/docs/lld" \
    "${PROJECT_ROOT}/docs/ears"
  SPEC_DIRS_SUMMARY="docs/hld  docs/lld  docs/ears"
else
  mkdir -p \
    "${PROJECT_ROOT}/openspec/specs" \
    "${PROJECT_ROOT}/openspec/changes"
  SPEC_DIRS_SUMMARY="openspec/specs  openspec/changes"
fi

mkdir -p \
  "${PROJECT_ROOT}/.uncle-dev/learns" \
  "${PROJECT_ROOT}/.devlocal" \
  "${PROJECT_ROOT}/.agents"

ok "${SPEC_DIRS_SUMMARY}  .uncle-dev/learns  .devlocal  .agents"

if [[ "${SKIP_PREFS}" -eq 0 ]]; then
  TEMPLATE="${REPO_ROOT}/skills/uncle-dev-setup/uncle-dev-setup.template.yaml"
  [[ -f "${TEMPLATE}" ]] || fail "Template not found: ${TEMPLATE}"

  sed \
    -e "s|__PROJECT_NAME__|${PROJECT_NAME}|g" \
    -e "s|__SETUP_DATE__|${TODAY}|g" \
    -e "s|active: \[\]|active: ${ACTIVE_TOOLS_YAML}|g" \
    -e "s|agent_skills_root: \"\"|agent_skills_root: \"${AGENT_SKILLS_ROOT}\"|g" \
    -e "s|sdd_mode: \"lid-ears\"|sdd_mode: \"${SDD_MODE}\"|g" \
    -e "s|execution_profile: \"balanced\"|execution_profile: \"${EXECUTION_PROFILE}\"|g" \
    -e "s|tdd-mode: lite|tdd-mode: ${TDD_MODE}|g" \
    -e "s|spec_annotations: true|spec_annotations: ${SPEC_ANNOTATIONS}|g" \
    -e "s|graphify: false|graphify: ${GRAPHIFY}|g" \
    "${TEMPLATE}" > "${CONFIG_FILE}"

  ok ".agents/uncle-dev-setup.yaml written (sdd_mode=${SDD_MODE})"

  # Post-write verification: read every preference back and compare it against
  # what we meant to write, so a substitution that quietly stopped matching
  # fails loudly instead of leaving a template default in place. Previously only
  # sdd_mode was checked, which left the other four unguarded.
  #
  # Lookups run from PROJECT_ROOT so the helper resolves .agents/ correctly, and
  # with the UNCLE_DEV_PREFERENCES_* names plus CLAUDE_PROJECT_DIR cleared. The
  # helper resolves the environment ahead of the file, so leaving those set would
  # echo back the value we just supplied and verify nothing — and, where the two
  # differed, produced a spurious failure blaming the template. Clearing
  # CLAUDE_PROJECT_DIR anchors the lookup to the project we actually wrote.
  read_back() {
    ( cd "${PROJECT_ROOT}" && env \
        -u CLAUDE_PROJECT_DIR \
        -u UNCLE_DEV_PREFERENCES_SDD_MODE \
        -u UNCLE_DEV_PREFERENCES_SPEC_ANNOTATIONS \
        -u UNCLE_DEV_PREFERENCES_TDD_MODE \
        -u UNCLE_DEV_PREFERENCES_EXECUTION_PROFILE \
        -u UNCLE_DEV_PREFERENCES_GRAPHIFY \
        bash "${SCRIPT_DIR}/uncle-dev-config.sh" "$1" "" 2>/dev/null || true )
  }

  WRITE_MISMATCH=()
  check_written() {
    local got
    got="$(read_back "$1")"
    [[ "${got:-}" == "$2" ]] || WRITE_MISMATCH+=("$1 — expected '$2' but reads '${got:-}'")
  }

  check_written preferences.sdd_mode         "${SDD_MODE}"
  check_written preferences.spec_annotations "${SPEC_ANNOTATIONS}"
  check_written preferences.tdd-mode         "${TDD_MODE}"
  check_written preferences.graphify         "${GRAPHIFY}"

  # execution_profile carries a third tier: a /uncle-dev-mode session flag file
  # outranks the stored value. Where one exists the read-back cannot observe what
  # was written, so checking it would report a mismatch that is not a defect.
  if [[ -f "${PROJECT_ROOT}/.uncle-dev/session-mode" ]]; then
    warn "execution_profile not verified — a .uncle-dev/session-mode flag outranks the stored value"
  else
    check_written preferences.execution_profile "${EXECUTION_PROFILE}"
  fi

  if [[ ${#WRITE_MISMATCH[@]} -gt 0 ]]; then
    echo "" >&2
    for _m in "${WRITE_MISMATCH[@]}"; do echo "    ${_m}" >&2; done
    echo "" >&2
    fail "Config write assertion failed. Check the template for two-line scalar form."
  fi
else
  # Refresh tool.active, and agent_skills_root only when it is not already set.
  #
  # A stored non-empty value is preserved: this branch runs on every plain
  # re-run, and overwriting it there would silently repoint a project from a
  # developer's checkout to whichever copy of the script happened to be invoked.
  # Use --update to change it deliberately.
  EXISTING_SKILLS_ROOT="$(cd "${PROJECT_ROOT}" && env -u UNCLE_DEV_TOOL_AGENT_SKILLS_ROOT \
    bash "${SCRIPT_DIR}/uncle-dev-config.sh" tool.agent_skills_root "" 2>/dev/null || true)"

  TMPFILE="${CONFIG_FILE}.tmp"
  if [[ -n "${EXISTING_SKILLS_ROOT:-}" ]] && [[ "${UPDATE_MODE}" -ne 1 ]]; then
    sed \
      -e "s|active: \[.*\]|active: ${ACTIVE_TOOLS_YAML}|g" \
      "${CONFIG_FILE}" > "${TMPFILE}"
    mv "${TMPFILE}" "${CONFIG_FILE}"
    ok ".agents/uncle-dev-setup.yaml updated (tool.active; agent_skills_root preserved)"
  else
    sed \
      -e "s|active: \[.*\]|active: ${ACTIVE_TOOLS_YAML}|g" \
      -e "s|agent_skills_root: \".*\"|agent_skills_root: \"${AGENT_SKILLS_ROOT}\"|g" \
      "${CONFIG_FILE}" > "${TMPFILE}"
    mv "${TMPFILE}" "${CONFIG_FILE}"
    ok ".agents/uncle-dev-setup.yaml updated (tool fields only)"
  fi
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
# The block is generated dynamically so the configured sdd_mode is explicit in
# CLAUDE.md — agents read it without parsing the yaml config file.
# In --update mode, only the script-owned inner span is rewritten, in place.

if [[ "${TOOL_CLAUDE}" -eq 1 ]]; then
  echo ""
  echo "Injecting CLAUDE.md rules..."

  CLAUDE_MD="${PROJECT_ROOT}/CLAUDE.md"
  [[ -f "${CLAUDE_MD}" ]] || touch "${CLAUDE_MD}"

  # The script owns only the span between the INNER markers. Everything else
  # inside the outer <!-- uncle-dev --> region belongs to the project and is
  # never touched.
  #
  # Previously --update deleted the whole outer region and re-appended a canned
  # block at end of file. In any project that had added its own rules inside that
  # region — this repository's own CLAUDE.md among them — that destroyed all of
  # them, along with any nested generated markers, and moved the region to the
  # bottom of the file on every run.

    # Build the sdd_mode-specific section
    if [[ "${SDD_MODE}" == "lid-ears" ]]; then
      SDD_SECTION="### SDD mode: lid-ears (LID+EARS)
This project uses the **LID+EARS documentation chain** for spec-driven development.
- Run \`/uncle-dev-spec\` before any non-trivial feature — it will elicit requirements and produce three docs
- Documents live in \`docs/hld/\`, \`docs/lld/\`, \`docs/ears/\`
- **Do NOT use OpenSpec change scaffolding in this project**
- Arrow of intent: HLD → LLD → EARS → code/tests
- To change a behaviour: update \`docs/ears/\` first, then let changes flow downstream"
    else
      SDD_SECTION="### SDD mode: openspec
This project uses **OpenSpec** for spec-driven development.
- Run \`/uncle-dev-spec\` before any non-trivial feature — it will scaffold an OpenSpec change
- Specs tracked in \`openspec/changes/<change-id>/\` (proposal, design, tasks, execution, handoff)
- Run \`/uncle-dev-plan\` after spec, before coding"
    fi

    CLAUDE_BODY="$(mktemp)"
    cat > "${CLAUDE_BODY}" <<BLOCK
## uncle-dev

This project uses uncle-dev engineering skills for structured AI-assisted development.

${SDD_SECTION}

### Skills by Phase
**Define:** uncle-dev-research, uncle-dev-idea-refine, uncle-dev-grill, uncle-dev-ubiquitous-language, uncle-dev-spec-driven-development, uncle-dev-design-architecture-docs, uncle-dev-acknowledge
**Plan:** uncle-dev-planning-and-task-breakdown
**Build:** uncle-dev-incremental-implementation, uncle-dev-test-driven-development, uncle-dev-spec-annotations, uncle-dev-context-engineering, uncle-dev-frontend-ui-engineering, uncle-dev-api-and-interface-design
**Verify:** uncle-dev-browser-testing-with-devtools, uncle-dev-debug-error
**Review:** uncle-dev-code-review-and-quality, uncle-dev-security-and-hardening, uncle-dev-performance-optimization
**Ship:** uncle-dev-git-workflow-and-versioning, uncle-dev-shipping-and-launch, uncle-dev-documentation-and-adrs
**Capture:** uncle-dev-knowledge-capture
**Maintain:** uncle-dev-knowledge-maintenance

### Skill loading

When a command prints \`SKILL: <ref>\` lines, read each \`<ref>\` as the active skill — if \`<ref>\` is \`uncle-dev:<name>\`, use the bundled plugin skill; if it is a file path, read that file instead. When a command also prints \`COMPANION: <path>\` lines, read each companion file **after** the active skill and merge its \`## Companion Additions\` into your working context.

### Conventions
- Personal scratchpad in \`.devlocal/<user>/\` (gitignored, not shared)
- Team learnings captured in \`.uncle-dev/learns/\`
BLOCK

  # The updater is written to a file and then run, rather than piped into
  # 'python3 -' from a here-document nested inside a command substitution. That
  # nesting parses, but the assignment does not bind, so the result is lost.
  CLAUDE_PY="$(mktemp)"
  cat > "${CLAUDE_PY}" <<'PY'
import re, sys

md_path, body_path = sys.argv[1], sys.argv[2]
update_mode = sys.argv[3] == "1"

text = open(md_path).read()
body = open(body_path).read().strip("\n")

O_OPEN, O_CLOSE = "<!-- uncle-dev -->", "<!-- /uncle-dev -->"
I_OPEN, I_CLOSE = "<!-- uncle-dev:generated -->", "<!-- /uncle-dev:generated -->"
inner = I_OPEN + "\n" + body + "\n" + I_CLOSE

# No region yet: create the whole thing at end of file.
if O_OPEN not in text:
    prefix = text
    if prefix and not prefix.endswith("\n"):
        prefix += "\n"
    if prefix and not prefix.endswith("\n\n"):
        prefix += "\n"
    open(md_path, "w").write(prefix + O_OPEN + "\n" + inner + "\n" + O_CLOSE + "\n")
    print("created")
    sys.exit(0)

# A region exists. Without --update we leave it entirely alone.
if not update_mode:
    print("preserved")
    sys.exit(0)

# Replace ONLY our own inner span, in place. Anything else in the region —
# project prose, nested BEGIN GENERATED blocks — is outside the match and
# survives untouched, and the region keeps its position in the file.
pat = re.compile(re.escape(I_OPEN) + r".*?" + re.escape(I_CLOSE), re.DOTALL)
if pat.search(text):
    open(md_path, "w").write(pat.sub(lambda m: inner, text, count=1))
    print("replaced")
else:
    # Legacy region predating the inner markers. We cannot distinguish our own
    # prose from the project's, so we remove nothing: insert the marked block at
    # the top of the region and leave everything already there in place.
    open(md_path, "w").write(text.replace(O_OPEN, O_OPEN + "\n" + inner, 1))
    print("migrated")
PY

  CLAUDE_MD_ACTION="$(python3 "${CLAUDE_PY}" "${CLAUDE_MD}" "${CLAUDE_BODY}" "${UPDATE_MODE}")"
  rm -f "${CLAUDE_BODY}" "${CLAUDE_PY}"

  case "${CLAUDE_MD_ACTION}" in
    created)
      ok "CLAUDE.md — uncle-dev block written (sdd_mode=${SDD_MODE})" ;;
    replaced)
      ok "CLAUDE.md — generated block refreshed in place (sdd_mode=${SDD_MODE})" ;;
    preserved)
      ok "CLAUDE.md already contains the uncle-dev block — preserving (use --update to refresh)" ;;
    migrated)
      warn "CLAUDE.md — the existing uncle-dev region had no generated markers; they were inserted without removing anything"
      warn "Review that region and delete any older duplicate of the generated block by hand." ;;
    *)
      warn "CLAUDE.md — unexpected result while updating the block: '${CLAUDE_MD_ACTION}'" ;;
  esac
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
if [[ "${SDD_MODE}" == "lid-ears" ]]; then
  [[ -d "${PROJECT_ROOT}/docs/hld" && -d "${PROJECT_ROOT}/docs/lld" && -d "${PROJECT_ROOT}/docs/ears" ]] \
    && ok "docs/hld/  docs/lld/  docs/ears/" \
    || warn "docs/{hld,lld,ears}/ missing"
else
  [[ -d "${PROJECT_ROOT}/openspec" ]] && ok "openspec/" || warn "openspec/ missing"
fi
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
