#!/bin/bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"

# shellcheck source=lib/manifest.sh
source "${SCRIPT_DIR}/lib/manifest.sh"
# shellcheck source=lib/install-common.sh
source "${SCRIPT_DIR}/lib/install-common.sh"

DIST_DIR="${REPO_ROOT}/dist"

SCOPE="local"
FORCE=0

usage() {
  cat <<'EOF'
Usage:
  ./scripts/install-opencode.sh [--scope local|global] [--force] [workspace]

Installs uncle-dev agent skills for OpenCode. Copies all skills (including
OpenSpec), all agents, and all rules files (AGENTS.md, AGENT_RULES.md,
CLAUDE.md) into the OpenCode config directory (global) or project workspace
(local).

Note: OpenCode does not support slash commands or session hooks.
      Commands and hooks are not installed.

Also generates dist/uncle-dev-opencode.tar.gz.

Options:
  --scope   local (default, installs to workspace) or global (~/.config/opencode/)
  --force   Overwrite files that already exist
  -h, --help  Show this help message

Examples:
  ./scripts/install-opencode.sh --scope global
  ./scripts/install-opencode.sh ~/code/my-app
  ./scripts/install-opencode.sh --scope local .
EOF
}

# ── argument parsing ──────────────────────────────────────────────────────────

WORKSPACE=""
WORKSPACE_WAS_OMITTED=0

while [[ $# -gt 0 ]]; do
  case "$1" in
    --scope)
      shift
      [[ $# -gt 0 ]] || fail "Missing value for --scope"
      case "$1" in
        local|global) SCOPE="$1" ;;
        *) fail "Invalid scope: $1 (expected local or global)" ;;
      esac
      shift
      ;;
    --force) FORCE=1; shift ;;
    -h|--help) usage; exit 0 ;;
    *)
      [[ -z "$WORKSPACE" ]] || fail "Unexpected argument: $1"
      WORKSPACE="$1"
      shift
      ;;
  esac
done

validate_sources "${REPO_ROOT}"

# ── resolve install root ──────────────────────────────────────────────────────

if [[ "$SCOPE" == "global" ]]; then
  [[ -z "$WORKSPACE" ]] || fail "Do not pass a workspace when using --scope global"
  INSTALL_ROOT="${HOME}/.config/opencode"
  AGENTS_DEST="${INSTALL_ROOT}/AGENTS.md"
  SKILLS_DEST="${INSTALL_ROOT}/skills"
  AGENTS_PERSONAS_DEST="${INSTALL_ROOT}/agents"
  RULES_ROOT="${INSTALL_ROOT}"
else
  if [[ -z "$WORKSPACE" ]]; then
    WORKSPACE_WAS_OMITTED=1
    WORKSPACE="."
  fi
  WORKSPACE="$(cd "$WORKSPACE" && pwd)"
  if [[ "$WORKSPACE_WAS_OMITTED" -eq 1 ]]; then
    read -r -p "No workspace provided. Install into current directory: $WORKSPACE? [y/N] " reply
    case "$reply" in y|Y|yes|YES) ;; *) fail "Aborted" ;; esac
  fi
  [[ "$WORKSPACE" != "$REPO_ROOT" ]] || fail "Refusing to install into the source repository itself."
  INSTALL_ROOT="${WORKSPACE}"
  AGENTS_DEST="${WORKSPACE}/AGENTS.md"
  SKILLS_DEST="${WORKSPACE}/.opencode/skills"
  AGENTS_PERSONAS_DEST="${WORKSPACE}/.opencode/agents"
  RULES_ROOT="${WORKSPACE}"
fi

log "Installing for OpenCode in ${INSTALL_ROOT}"

# ── install files ─────────────────────────────────────────────────────────────

# AGENTS.md — primary OpenCode instruction file
copy_file "${REPO_ROOT}/AGENTS.md" "${AGENTS_DEST}" "${FORCE}"

# skills/ — root skills (32) + .claude/skills/ OpenSpec skills (4), merged
copy_dir_contents "${REPO_ROOT}/${ASSET_SKILLS_ROOT}" "${SKILLS_DEST}" "${FORCE}"
copy_dir_contents "${REPO_ROOT}/${ASSET_SKILLS_OPENSPEC}" "${SKILLS_DEST}" "${FORCE}"

# agents/ — reusable personas
copy_dir_contents "${REPO_ROOT}/${ASSET_AGENTS}" "${AGENTS_PERSONAS_DEST}" "${FORCE}"

# scripts/ — config lookup and setup utilities
copy_dir_contents "${REPO_ROOT}/${ASSET_SCRIPTS}" "${INSTALL_ROOT}/.opencode/scripts" "${FORCE}"

# rules — AGENT_RULES.md and CLAUDE.md alongside AGENTS.md
for rule in "${ASSET_RULES[@]}"; do
  copy_file "${REPO_ROOT}/${rule}" "${RULES_ROOT}/${rule}" "${FORCE}"
done

# ── generate distributable archive ───────────────────────────────────────────

mkdir -p "${DIST_DIR}"
ARCHIVE="${DIST_DIR}/uncle-dev-opencode.tar.gz"
BUNDLE_TMP="${DIST_DIR}/.opencode-bundle-tmp"

log "Generating archive at ${ARCHIVE}"

rm -rf "${BUNDLE_TMP}"
mkdir -p "${BUNDLE_TMP}"

copy_file "${REPO_ROOT}/AGENTS.md" "${BUNDLE_TMP}/AGENTS.md" "1"
for rule in "${ASSET_RULES[@]}"; do
  copy_file "${REPO_ROOT}/${rule}" "${BUNDLE_TMP}/${rule}" "1"
done
copy_dir_contents "${REPO_ROOT}/${ASSET_SKILLS_ROOT}" "${BUNDLE_TMP}/skills" "1"
copy_dir_contents "${REPO_ROOT}/${ASSET_SKILLS_OPENSPEC}" "${BUNDLE_TMP}/skills" "1"
copy_dir_contents "${REPO_ROOT}/${ASSET_AGENTS}" "${BUNDLE_TMP}/agents" "1"

tar -czf "${ARCHIVE}" -C "${DIST_DIR}" ".opencode-bundle-tmp"
rm -rf "${BUNDLE_TMP}"

# ── summary ───────────────────────────────────────────────────────────────────

# Build a fake summary root that mirrors what we installed
SUMMARY_TMP="$(mktemp -d)"
[[ -d "${SKILLS_DEST}" ]]         && ln -s "${SKILLS_DEST}" "${SUMMARY_TMP}/skills"
[[ -d "${AGENTS_PERSONAS_DEST}" ]] && ln -s "${AGENTS_PERSONAS_DEST}" "${SUMMARY_TMP}/agents"
for rule in "${ASSET_RULES[@]}"; do
  [[ -f "${RULES_ROOT}/${rule}" ]] && cp "${RULES_ROOT}/${rule}" "${SUMMARY_TMP}/${rule}"
done

log ""
log "── OpenCode install summary ─────────────────────────────"
[[ -d "${SKILLS_DEST}" ]]          && log "  Skills    : $(find "${SKILLS_DEST}" -mindepth 1 -maxdepth 1 | wc -l | tr -d ' ') installed"
[[ -d "${AGENTS_PERSONAS_DEST}" ]] && log "  Agents    : $(find "${AGENTS_PERSONAS_DEST}" -mindepth 1 -maxdepth 1 | wc -l | tr -d ' ') installed"

local_rules=()
for rule in "${ASSET_RULES[@]}"; do
  [[ -f "${RULES_ROOT}/${rule}" ]] && local_rules+=("$rule")
done
[[ ${#local_rules[@]} -gt 0 ]] && log "  Rules     : ${local_rules[*]}"
log ""

rm -rf "${SUMMARY_TMP}"

log "Archive: ${ARCHIVE}"
