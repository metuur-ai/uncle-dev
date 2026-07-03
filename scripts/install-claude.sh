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

command -v jq >/dev/null 2>&1 || fail "jq is required but not found. Install: brew install jq"

# Identity is derived from the manifests (single source of truth), never hardcoded.
#   marketplace id ← .claude-plugin/marketplace.json ".name"
#   plugin name    ← .claude-plugin/plugin.json      ".name"  (drives the /<name>: namespace)
#   version        ← .claude-plugin/plugin.json      ".version"
# Hardcoding the plugin name as the marketplace id previously produced a second,
# mis-keyed registration (uncle-dev-agent-skills@… instead of the canonical
# uncle-dev@…), so the plugin appeared installed twice.
MARKETPLACE_ID="$(jq -r '.name' "${REPO_ROOT}/.claude-plugin/marketplace.json")"
PLUGIN_NAME="$(jq -r '.name' "${REPO_ROOT}/${ASSET_PLUGIN_META}")"
VERSION="$(jq -r '.version' "${REPO_ROOT}/${ASSET_PLUGIN_META}")"
[[ -n "${MARKETPLACE_ID}" && "${MARKETPLACE_ID}" != "null" ]] || fail "Could not read marketplace name from marketplace.json"
[[ -n "${PLUGIN_NAME}" && "${PLUGIN_NAME}" != "null" ]] || fail "Could not read plugin name from plugin.json"
[[ -n "${VERSION}" && "${VERSION}" != "null" ]] || fail "Could not read version from plugin.json"
PLUGIN_KEY="${PLUGIN_NAME}@${MARKETPLACE_ID}"
CACHE_PATH="${PLUGINS_DIR}/cache/${MARKETPLACE_ID}/${PLUGIN_NAME}/${VERSION}"
DIST_DIR="${REPO_ROOT}/dist"

SCOPE="user"
FORCE=0
DEV=0

usage() {
  cat <<'EOF'
Usage:
  ./scripts/install-claude.sh [--scope user|local] [--force] [--dev]

Installs this repository as a Claude Code plugin. Copies all skills (including
OpenSpec skills), agents, commands (including opsx/), hooks, rules, and plugin
manifest into ~/.claude/plugins/cache/ and registers the plugin.

Also generates dist/uncle-dev-claude.tar.gz for distribution.

Options:
  --scope   Plugin scope: user (default) or local
  --force   Overwrite an existing installation
  --dev     Serve directly from source repo (no cache copy).
            Changes to source files take effect immediately — no reinstall needed.
            $CLAUDE_PLUGIN_ROOT will point to the repo root.
  -h, --help  Show this help message
EOF
}

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
    --dev)   DEV=1; shift ;;
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

# In dev mode, serve directly from source — $CLAUDE_PLUGIN_ROOT = REPO_ROOT
if [[ "$DEV" -eq 1 ]]; then
  INSTALL_PATH="${REPO_ROOT}"
  log "Dev mode: serving from source at ${INSTALL_PATH}"
else
  INSTALL_PATH="${CACHE_PATH}"
fi

# ── copy files to cache (skipped in --dev mode) ───────────────────────────────

if [[ "$DEV" -eq 0 ]]; then
  log "Copying plugin files to ${CACHE_PATH}"

  if [[ -d "${CACHE_PATH}" && "${FORCE}" -eq 1 ]]; then
    rm -rf "${CACHE_PATH}"
  fi

  mkdir -p "${CACHE_PATH}"

  # skills/ — full skill library
  copy_dir_contents "${REPO_ROOT}/${ASSET_SKILLS_ROOT}" "${CACHE_PATH}/skills" "${FORCE}"

  # agents/ — reusable personas
  copy_dir_contents "${REPO_ROOT}/${ASSET_AGENTS}" "${CACHE_PATH}/agents" "${FORCE}"

  # commands/ — recursive, preserving any subdir structure
  copy_dir_contents "${REPO_ROOT}/${ASSET_COMMANDS_ROOT}" "${CACHE_PATH}/commands" "${FORCE}"

  # hooks/ — session lifecycle hooks
  copy_dir_contents "${REPO_ROOT}/${ASSET_HOOKS}" "${CACHE_PATH}/hooks" "${FORCE}"

  # scripts/ — setup-project.sh and install utilities
  copy_dir_contents "${REPO_ROOT}/${ASSET_SCRIPTS}" "${CACHE_PATH}/scripts" "${FORCE}"

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
fi

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
  --arg path "${INSTALL_PATH}" \
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

# ── commands are served from the plugin (no loose promotion) ──────────────────
# Claude Code surfaces a plugin's commands directly from the installed package,
# namespaced as /uncle-dev:<command>. We intentionally do NOT copy them into
# ~/.claude/commands/: that produced duplicate, un-namespaced entries in the
# slash menu and a second copy to keep in sync. The plugin registration above
# (marketplace + installed_plugins, scope "${SCOPE}") is the complete, global
# install — in --dev mode installPath points at the repo, so source edits take
# effect with no reinstall.

# ── generate distributable archive (skipped in --dev mode) ───────────────────

if [[ "$DEV" -eq 0 ]]; then
  mkdir -p "${DIST_DIR}"
  ARCHIVE="${DIST_DIR}/uncle-dev-claude.tar.gz"
  log "Generating archive at ${ARCHIVE}"
  tar -czf "${ARCHIVE}" -C "$(dirname "${CACHE_PATH}")" "$(basename "${CACHE_PATH}")"
fi

# ── summary ───────────────────────────────────────────────────────────────────

if [[ "$DEV" -eq 1 ]]; then
  summarize_install "${REPO_ROOT}" "Claude Code (dev)"
else
  summarize_install "${INSTALL_PATH}" "Claude Code"
fi
if [[ "$DEV" -eq 0 ]]; then
  log "Archive: ${DIST_DIR}/uncle-dev-claude.tar.gz"
fi
if [[ "$DEV" -eq 1 ]]; then
  log "\$CLAUDE_PLUGIN_ROOT will be: ${REPO_ROOT}"
  log "Edit source files directly — no reinstall needed."
fi
# ── put `uncle-dev-configure` on PATH (interactive config TUI) ───────────────
# Symlinks ~/.local/bin/uncle-dev-configure -> the installed configurator so
# users can run it from any project. Non-fatal if it can't be linked.
if [[ -f "${INSTALL_PATH}/scripts/link-configurator.sh" ]]; then
  bash "${INSTALL_PATH}/scripts/link-configurator.sh" || true
fi

log "Restart Claude Code for the changes to take effect."
