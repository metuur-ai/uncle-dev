#!/bin/bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"

# shellcheck source=lib/manifest.sh
source "${SCRIPT_DIR}/lib/manifest.sh"
# shellcheck source=lib/install-common.sh
source "${SCRIPT_DIR}/lib/install-common.sh"

DIST_DIR="${REPO_ROOT}/dist"
PLUGIN_NAME="uncle-dev"
MARKETPLACE_TEMPLATE="${REPO_ROOT}/.agents/plugins/marketplace.json"

SCOPE="user"
FORCE=0

usage() {
  cat <<'EOF'
Usage:
  ./scripts/install-codex.sh [--scope user|local] [--force] [workspace]

Installs Uncle Dev as a native Codex plugin. Assembles the bundle from shared
repo sources at install time: all skills (including OpenSpec), all agents,
all commands (including opsx/), and rules files.

Note: Codex does not support session hooks; hooks/ is not installed.

Options:
  --scope   user (default) or local (installs into workspace)
  --force   Overwrite files that already exist
  -h, --help  Show this help message

Examples:
  ./scripts/install-codex.sh
  ./scripts/install-codex.sh --scope local ~/code/my-app
  ./scripts/install-codex.sh --scope local .
EOF
}

command -v python3 >/dev/null 2>&1 || fail "python3 is required but not found"

require_file() {
  [[ -e "$1" ]] || fail "Required path not found: $1"
}

# ── marketplace merge (python3, no jq dep for Codex installs) ─────────────────

merge_marketplace() {
  local src="$1" dest="$2"

  mkdir -p "$(dirname "$dest")"

  if [[ ! -f "$dest" ]]; then
    cp "$src" "$dest"
    return 0
  fi

  python3 - "$src" "$dest" <<'PY'
import json, sys
from pathlib import Path

src_path, dest_path = Path(sys.argv[1]), Path(sys.argv[2])

try:
    src = json.loads(src_path.read_text())
except json.JSONDecodeError as exc:
    raise SystemExit(f"Invalid source marketplace JSON: {src_path}: {exc}")

try:
    dest = json.loads(dest_path.read_text())
except json.JSONDecodeError as exc:
    raise SystemExit(f"Invalid existing marketplace JSON: {dest_path}: {exc}")

src_plugin = (src.get("plugins") or [{}])[0]
if not src_plugin:
    raise SystemExit("Source marketplace.json has no plugins")

plugins = dest.get("plugins", [])
replaced = any(
    (plugins.__setitem__(i, src_plugin) or True)
    for i, p in enumerate(plugins)
    if p.get("name") == src_plugin.get("name")
)
if not replaced:
    plugins.append(src_plugin)

dest["plugins"] = plugins
if "name" not in dest:
    dest["name"] = src.get("name", "uncle-dev")

dest_iface = dest.setdefault("interface", {})
src_iface = src.get("interface", {})
if "displayName" not in dest_iface and "displayName" in src_iface:
    dest_iface["displayName"] = src_iface["displayName"]

dest_path.write_text(json.dumps(dest, indent=2) + "\n")
PY
}

# ── bundle assembly ───────────────────────────────────────────────────────────

assemble_plugin() {
  local bundle_root="$1"
  local plugin_root="${bundle_root}/plugins/${PLUGIN_NAME}"

  if [[ -d "$plugin_root" && "${FORCE}" -eq 1 ]]; then
    rm -rf "$plugin_root"
  fi

  mkdir -p "$plugin_root"

  # Plugin manifest (.codex-plugin/plugin.json — Codex-native format)
  copy_file \
    "${REPO_ROOT}/plugins/${PLUGIN_NAME}/.codex-plugin/plugin.json" \
    "${plugin_root}/.codex-plugin/plugin.json" \
    "${FORCE}"

  # commands/ — all commands from canonical source (commands/)
  copy_dir_contents \
    "${REPO_ROOT}/${ASSET_COMMANDS_ROOT}" \
    "${plugin_root}/commands" \
    "${FORCE}"

  # skills/ — full skill library
  copy_dir_contents \
    "${REPO_ROOT}/${ASSET_SKILLS_ROOT}" \
    "${plugin_root}/skills" \
    "${FORCE}"

  # Codex-native agent manifests live under the plugin namespace, not in the
  # shared skills/ tree. Copy them into the matching bundled skill locations.
  while IFS= read -r agent_manifest; do
    skill_name="$(basename "$(dirname "${agent_manifest}")")"
    copy_file \
      "${agent_manifest}" \
      "${plugin_root}/skills/${skill_name}/agents/openai.yaml" \
      "${FORCE}"
  done < <(find "${REPO_ROOT}/${ASSET_CODEX_AGENT_MANIFESTS}" -path '*/openai.yaml' -type f | sort)

  # agents/ — reusable personas
  copy_dir_contents \
    "${REPO_ROOT}/${ASSET_AGENTS}" \
    "${plugin_root}/agents" \
    "${FORCE}"

  # scripts/ — config lookup and setup utilities
  copy_dir_contents \
    "${REPO_ROOT}/${ASSET_SCRIPTS}" \
    "${plugin_root}/scripts" \
    "${FORCE}"

  # rules — AGENTS.md, AGENT_RULES.md, CLAUDE.md at plugin root
  for rule in "${ASSET_RULES[@]}"; do
    copy_file "${REPO_ROOT}/${rule}" "${plugin_root}/${rule}" "${FORCE}"
  done

  # Optional plugin assets (branding etc.)
  if [[ -d "${REPO_ROOT}/plugins/${PLUGIN_NAME}/assets" ]]; then
    copy_dir_contents \
      "${REPO_ROOT}/plugins/${PLUGIN_NAME}/assets" \
      "${plugin_root}/assets" \
      "${FORCE}"
  fi
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
        user|local) SCOPE="$1" ;;
        *) fail "Invalid scope: $1 (expected user or local)" ;;
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

require_file "${REPO_ROOT}/plugins/${PLUGIN_NAME}/.codex-plugin/plugin.json"
require_file "${MARKETPLACE_TEMPLATE}"
validate_sources "${REPO_ROOT}"

# ── resolve install root ──────────────────────────────────────────────────────

if [[ "$SCOPE" == "user" ]]; then
  [[ -z "$WORKSPACE" ]] || fail "Do not pass a workspace when using --scope user"
  BUNDLE_ROOT="${HOME}"
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
  BUNDLE_ROOT="${WORKSPACE}"
fi

PLUGIN_DEST="${BUNDLE_ROOT}/plugins/${PLUGIN_NAME}"
MARKETPLACE_DEST="${BUNDLE_ROOT}/.agents/plugins/marketplace.json"

log "Installing Codex plugin into ${PLUGIN_DEST}"

# ── install ───────────────────────────────────────────────────────────────────

assemble_plugin "${BUNDLE_ROOT}"
merge_marketplace "${MARKETPLACE_TEMPLATE}" "${MARKETPLACE_DEST}"

# ── generate distributable archive ───────────────────────────────────────────

mkdir -p "${DIST_DIR}"
ARCHIVE="${DIST_DIR}/uncle-dev-codex.tar.gz"
BUNDLE_TMP="${DIST_DIR}/.codex-bundle-tmp"

log "Generating archive at ${ARCHIVE}"

rm -rf "${BUNDLE_TMP}"
mkdir -p "${BUNDLE_TMP}"
assemble_plugin "${BUNDLE_TMP}"
merge_marketplace "${MARKETPLACE_TEMPLATE}" "${BUNDLE_TMP}/.agents/plugins/marketplace.json"
tar -czf "${ARCHIVE}" -C "${DIST_DIR}" ".codex-bundle-tmp"
rm -rf "${BUNDLE_TMP}"

# ── summary ───────────────────────────────────────────────────────────────────

summarize_install "${PLUGIN_DEST}" "Codex"
log "Archive: ${ARCHIVE}"
if [[ "$SCOPE" == "user" ]]; then
  log "Codex discovers the plugin from ~/.agents/plugins/marketplace.json"
else
  log "Codex discovers the plugin from ${BUNDLE_ROOT}/.agents/plugins/marketplace.json"
fi
