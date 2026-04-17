#!/bin/bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"

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

Installs this repository as a Claude Code plugin without requiring a GitHub
SSH key. Copies commands, skills, agents, and hooks into ~/.claude/plugins/cache/
and registers the plugin so Claude Code can load it on next startup.
Also generates dist/uncle-dev-claude.tar.gz for distribution.

Options:
  --scope   Plugin scope: user (default) or local
  --force   Overwrite an existing installation
  -h, --help  Show this help message
EOF
}

log()  { echo "$*" >&2; }
fail() { log "Error: $*"; exit 1; }

# ── dependency check ──────────────────────────────────────────────────────────

command -v jq >/dev/null 2>&1 || fail "jq is required but not found. Install it with: brew install jq"

# ── argument parsing ──────────────────────────────────────────────────────────

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
    --force)
      FORCE=1
      shift
      ;;
    -h|--help)
      usage
      exit 0
      ;;
    *)
      fail "Unexpected argument: $1"
      ;;
  esac
done

# ── pre-flight ────────────────────────────────────────────────────────────────

[[ -d "${PLUGINS_DIR}" ]] || fail "Claude plugins directory not found at ${PLUGINS_DIR}. Is Claude Code installed?"
[[ -f "${MARKETPLACES_FILE}" ]] || fail "known_marketplaces.json not found at ${MARKETPLACES_FILE}"
[[ -f "${INSTALLED_FILE}" ]] || fail "installed_plugins.json not found at ${INSTALLED_FILE}"
[[ -d "${REPO_ROOT}/.claude/commands" ]] || fail "No .claude/commands directory found in repo at ${REPO_ROOT}"

ALREADY_INSTALLED="$(jq --arg key "${PLUGIN_KEY}" '.plugins | has($key)' "${INSTALLED_FILE}")"
if [[ "${ALREADY_INSTALLED}" == "true" && "${FORCE}" -ne 1 ]]; then
  log "Plugin '${PLUGIN_KEY}' is already installed."
  log "Run with --force to reinstall."
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

# commands/ — Claude looks for this at the cache root
cp -r "${REPO_ROOT}/.claude/commands" "${CACHE_PATH}/commands"

# skills/ — all skill directories with SKILL.md and colocated reference files
cp -r "${REPO_ROOT}/skills" "${CACHE_PATH}/skills"

# agents/ — reusable agent personas
cp -r "${REPO_ROOT}/agents" "${CACHE_PATH}/agents"

# hooks/ — session lifecycle hooks
cp -r "${REPO_ROOT}/hooks" "${CACHE_PATH}/hooks"

# .claude-plugin/plugin.json — plugin metadata
mkdir -p "${CACHE_PATH}/.claude-plugin"
jq '{name, version, description, author, license}' \
  "${REPO_ROOT}/.claude-plugin/plugin.json" \
  > "${CACHE_PATH}/.claude-plugin/plugin.json"

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

# ── copy commands to ~/.claude/commands/ for bare /cmd access ─────────────────

USER_COMMANDS_DIR="${HOME}/.claude/commands"
mkdir -p "${USER_COMMANDS_DIR}"

log "Copying commands to ${USER_COMMANDS_DIR} for bare slash-command access"

for f in "${CACHE_PATH}/commands"/*.md; do
  dest="${USER_COMMANDS_DIR}/$(basename "${f}")"
  if [[ -f "${dest}" && "${FORCE}" -ne 1 ]]; then
    log "  Skipping $(basename "${f}") (already exists, use --force to overwrite)"
  else
    cp "${f}" "${dest}"
    log "  Copied $(basename "${f}")"
  fi
done

# ── generate distributable archive ───────────────────────────────────────────

mkdir -p "${DIST_DIR}"
ARCHIVE="${DIST_DIR}/uncle-dev-claude.tar.gz"

log "Generating archive at ${ARCHIVE}"
tar -czf "${ARCHIVE}" -C "$(dirname "${CACHE_PATH}")" "$(basename "${CACHE_PATH}")"

# ── done ──────────────────────────────────────────────────────────────────────

log ""
log "Done. Installed commands:"
for f in "${CACHE_PATH}/commands"/*.md; do
  log "  /$(basename "${f%.md}")"
done
log ""
log "Archive: ${ARCHIVE}"
log "Restart Claude Code for the commands to become available."
