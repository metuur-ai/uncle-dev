#!/bin/bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"

# shellcheck source=lib/manifest.sh
source "${SCRIPT_DIR}/lib/manifest.sh"
# shellcheck source=lib/install-common.sh
source "${SCRIPT_DIR}/lib/install-common.sh"

PLUGINS_DIR="${HOME}/.claude/plugins"
MARKETPLACES_FILE="${PLUGINS_DIR}/known_marketplaces.json"
INSTALLED_FILE="${PLUGINS_DIR}/installed_plugins.json"

MARKETPLACE_ID="uncle-dev-agent-skills"
PLUGIN_NAME="uncle-dev-agent-skills"
PLUGIN_KEY="${PLUGIN_NAME}@${MARKETPLACE_ID}"
VERSION="1.0.0"
CACHE_PATH="${PLUGINS_DIR}/cache/${MARKETPLACE_ID}/${PLUGIN_NAME}/${VERSION}"
DIST_DIR="${REPO_ROOT}/dist"

SCOPE="user"
FORCE=0

usage() {
  cat <<'EOF'
Usage:
  ./scripts/install-claude.sh [--scope user|local] [--force]

Installs this repository as a Claude Code plugin. Copies all skills (including
OpenSpec skills), agents, commands (including opsx/), hooks, rules, and plugin
manifest into ~/.claude/plugins/cache/ and registers the plugin.

Also generates dist/uncle-dev-claude.tar.gz for distribution.

Options:
  --scope   Plugin scope: user (default) or local
  --force   Overwrite an existing installation
  -h, --help  Show this help message
EOF
}

command -v jq >/dev/null 2>&1 || fail "jq is required but not found. Install: brew install jq"

while [[ $# -gt 0 ]]; do
  case "$1" in
    --scope)
      shift
      [[ $# -gt 0 ]] || fail "Missing value for --scope"
      case "$1" in
        user|local) SCOPE="$1" ;;
        *) fail "Invalid scope: $1 (expected user or local)" ;;
      esac
      shift
      ;;
    --force) FORCE=1; shift ;;
    -h|--help) usage; exit 0 ;;
    *) fail "Unexpected argument: $1" ;;
  esac
done

# ── pre-flight ────────────────────────────────────────────────────────────────

[[ -d "${PLUGINS_DIR}" ]] || fail "Claude plugins directory not found: ${PLUGINS_DIR}. Is Claude Code installed?"
[[ -f "${MARKETPLACES_FILE}" ]] || fail "known_marketplaces.json not found: ${MARKETPLACES_FILE}"
[[ -f "${INSTALLED_FILE}" ]] || fail "installed_plugins.json not found: ${INSTALLED_FILE}"

validate_sources "${REPO_ROOT}"

ALREADY_INSTALLED="$(jq --arg key "${PLUGIN_KEY}" '.plugins | has($key)' "${INSTALLED_FILE}")"
if [[ "${ALREADY_INSTALLED}" == "true" && "${FORCE}" -ne 1 ]]; then
  log "Plugin '${PLUGIN_KEY}' is already installed. Run with --force to reinstall."
  exit 0
fi

GIT_SHA="$(git -C "${REPO_ROOT}" rev-parse HEAD 2>/dev/null || echo "unknown")"
NOW="$(date -u +"%Y-%m-%dT%H:%M:%S.000Z")"

# ── copy files to cache ───────────────────────────────────────────────────────

log "Copying plugin files to ${CACHE_PATH}"

if [[ -d "${CACHE_PATH}" && "${FORCE}" -eq 1 ]]; then
  rm -rf "${CACHE_PATH}"
fi

mkdir -p "${CACHE_PATH}"

# skills/ — root skills (32) + .claude/skills/ OpenSpec skills (4), merged
copy_dir_contents "${REPO_ROOT}/${ASSET_SKILLS_ROOT}" "${CACHE_PATH}/skills" "${FORCE}"
copy_dir_contents "${REPO_ROOT}/${ASSET_SKILLS_OPENSPEC}" "${CACHE_PATH}/skills" "${FORCE}"

# agents/ — reusable personas
copy_dir_contents "${REPO_ROOT}/${ASSET_AGENTS}" "${CACHE_PATH}/agents" "${FORCE}"

# commands/ — recursive, preserving opsx/ subdir
copy_dir_contents "${REPO_ROOT}/${ASSET_COMMANDS_ROOT}" "${CACHE_PATH}/commands" "${FORCE}"

# hooks/ — session lifecycle hooks
copy_dir_contents "${REPO_ROOT}/${ASSET_HOOKS}" "${CACHE_PATH}/hooks" "${FORCE}"

# rules — AGENTS.md, AGENT_RULES.md, CLAUDE.md at cache root
for rule in "${ASSET_RULES[@]}"; do
  copy_file "${REPO_ROOT}/${rule}" "${CACHE_PATH}/${rule}" "${FORCE}"
done

# .claude-plugin/ — full directory (plugin.json + marketplace.json, no filtering)
mkdir -p "${CACHE_PATH}/.claude-plugin"
copy_file "${REPO_ROOT}/${ASSET_PLUGIN_META}" "${CACHE_PATH}/.claude-plugin/plugin.json" "${FORCE}"
copy_file "${REPO_ROOT}/.claude-plugin/marketplace.json" "${CACHE_PATH}/.claude-plugin/marketplace.json" "${FORCE}"

# hooks.json also at .claude-plugin/ for auto-discovery by Claude Code
copy_file "${REPO_ROOT}/hooks/hooks.json" "${CACHE_PATH}/.claude-plugin/hooks.json" "${FORCE}"

# ── register marketplace (directory source) ───────────────────────────────────

log "Registering marketplace '${MARKETPLACE_ID}'"

jq \
  --arg id "${MARKETPLACE_ID}" \
  --arg path "${REPO_ROOT}" \
  --arg now "${NOW}" \
  '.[$id] = {
    "source": { "source": "directory", "path": $path },
    "installLocation": $path,
    "lastUpdated": $now
  }' \
  "${MARKETPLACES_FILE}" > "${MARKETPLACES_FILE}.tmp"
mv "${MARKETPLACES_FILE}.tmp" "${MARKETPLACES_FILE}"

# ── register plugin in installed_plugins.json ─────────────────────────────────

log "Registering plugin '${PLUGIN_KEY}' (scope: ${SCOPE})"

jq \
  --arg key "${PLUGIN_KEY}" \
  --arg path "${CACHE_PATH}" \
  --arg scope "${SCOPE}" \
  --arg version "${VERSION}" \
  --arg sha "${GIT_SHA}" \
  --arg now "${NOW}" \
  '.plugins[$key] = [{
    "scope": $scope,
    "installPath": $path,
    "version": $version,
    "installedAt": $now,
    "lastUpdated": $now,
    "gitCommitSha": $sha
  }]' \
  "${INSTALLED_FILE}" > "${INSTALLED_FILE}.tmp"
mv "${INSTALLED_FILE}.tmp" "${INSTALLED_FILE}"

# ── promote commands to ~/.claude/commands/ ───────────────────────────────────

USER_COMMANDS_DIR="${HOME}/.claude/commands"
mkdir -p "${USER_COMMANDS_DIR}"

log "Promoting commands to ${USER_COMMANDS_DIR}"

# Walk recursively so opsx/ subdir structure is preserved under ~/.claude/commands/opsx/
while IFS= read -r -d '' cmd_file; do
  rel="${cmd_file#"${CACHE_PATH}/commands/"}"
  dest="${USER_COMMANDS_DIR}/${rel}"
  mkdir -p "$(dirname "$dest")"

  if [[ -f "${dest}" && "${FORCE}" -ne 1 ]]; then
    if cmp -s "${cmd_file}" "${dest}"; then
      continue
    fi
    log "  Skipping ${rel} (already exists, use --force to overwrite)"
  else
    cp "${cmd_file}" "${dest}"
    log "  Copied ${rel}"
  fi
done < <(find "${CACHE_PATH}/commands" -type f -name '*.md' -print0 | sort -z)

# ── generate distributable archive ───────────────────────────────────────────

mkdir -p "${DIST_DIR}"
ARCHIVE="${DIST_DIR}/uncle-dev-claude.tar.gz"

log "Generating archive at ${ARCHIVE}"
tar -czf "${ARCHIVE}" -C "$(dirname "${CACHE_PATH}")" "$(basename "${CACHE_PATH}")"

# ── summary ───────────────────────────────────────────────────────────────────

summarize_install "${CACHE_PATH}" "Claude Code"
log "Archive: ${ARCHIVE}"
log "Restart Claude Code for the changes to take effect."
