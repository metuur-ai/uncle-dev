#!/bin/bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"
DIST_DIR="${REPO_ROOT}/dist"
PLUGIN_NAME="uncle-dev"
PLUGIN_WRAPPER_DIR="${REPO_ROOT}/plugins/${PLUGIN_NAME}"
MARKETPLACE_TEMPLATE="${REPO_ROOT}/.agents/plugins/marketplace.json"

SCOPE="user"
FORCE=0

usage() {
  cat <<'EOF'
Usage:
  ./scripts/install-codex.sh [--scope user|local] [--force] [workspace]

Installs Uncle Dev as a native Codex plugin. The installer assembles the
plugin bundle from shared repo sources at install time by copying:
  - shared skills/ and agents/
  - Codex-specific commands and .codex-plugin/plugin.json
  - marketplace metadata

Options:
  --scope   user (default, installs to ~/plugins and ~/.agents/plugins/) or local (installs to workspace)
  --force   Overwrite files that already exist
  -h, --help  Show this help message

Examples:
  ./scripts/install-codex.sh
  ./scripts/install-codex.sh --scope local ~/code/my-app
  ./scripts/install-codex.sh --scope local .
EOF
}

log()  { echo "$*" >&2; }
fail() { log "Error: $*"; exit 1; }

command -v python3 >/dev/null 2>&1 || fail "python3 is required but not found"

require_file() {
  local path="$1"
  [[ -e "$path" ]] || fail "Required path not found: $path"
}

copy_file() {
  local src="$1"
  local dest="$2"
  mkdir -p "$(dirname "$dest")"
  if [[ -f "$dest" ]] && cmp -s "$src" "$dest"; then
    return 0
  fi
  if [[ -e "$dest" && "$FORCE" -ne 1 ]]; then
    fail "Refusing to overwrite existing file: $dest (rerun with --force)"
  fi
  cp "$src" "$dest"
}

copy_dir_contents() {
  local src_dir="$1"
  local dest_dir="$2"
  mkdir -p "$dest_dir"
  local entry
  for entry in "$src_dir"/*; do
    local name
    name="$(basename "$entry")"
    if [[ -d "$entry" ]]; then
      copy_dir_contents "$entry" "$dest_dir/$name"
    else
      copy_file "$entry" "$dest_dir/$name"
    fi
  done
}

copy_optional_dir_contents() {
  local src_dir="$1"
  local dest_dir="$2"
  if [[ -d "$src_dir" ]]; then
    copy_dir_contents "$src_dir" "$dest_dir"
  fi
}

merge_marketplace() {
  local src="$1"
  local dest="$2"

  mkdir -p "$(dirname "$dest")"

  if [[ ! -f "$dest" ]]; then
    cp "$src" "$dest"
    return 0
  fi

  python3 - "$src" "$dest" <<'PY'
import json
import sys
from pathlib import Path

src_path = Path(sys.argv[1])
dest_path = Path(sys.argv[2])

try:
    src = json.loads(src_path.read_text())
except json.JSONDecodeError as exc:
    raise SystemExit(f"Invalid source marketplace JSON: {src_path}: {exc}")

try:
    dest = json.loads(dest_path.read_text())
except json.JSONDecodeError as exc:
    raise SystemExit(f"Invalid existing marketplace JSON: {dest_path}: {exc}")

src_plugins = src.get("plugins", [])
if not src_plugins:
    raise SystemExit("Source marketplace.json has no plugins")

src_plugin = src_plugins[0]
plugins = dest.get("plugins", [])
replaced = False
for idx, plugin in enumerate(plugins):
    if plugin.get("name") == src_plugin.get("name"):
        plugins[idx] = src_plugin
        replaced = True
        break

if not replaced:
    plugins.append(src_plugin)

dest["plugins"] = plugins

if "name" not in dest:
    dest["name"] = src.get("name", "uncle-dev")

dest_interface = dest.setdefault("interface", {})
src_interface = src.get("interface", {})
if "displayName" not in dest_interface and "displayName" in src_interface:
    dest_interface["displayName"] = src_interface["displayName"]

dest_path.write_text(json.dumps(dest, indent=2) + "\n")
PY
}

assemble_plugin() {
  local bundle_root="$1"
  local plugin_root="${bundle_root}/plugins/${PLUGIN_NAME}"

  if [[ -d "$plugin_root" && "$FORCE" -eq 1 ]]; then
    rm -rf "$plugin_root"
  fi

  mkdir -p "$plugin_root"

  copy_file \
    "${PLUGIN_WRAPPER_DIR}/.codex-plugin/plugin.json" \
    "${plugin_root}/.codex-plugin/plugin.json"
  copy_dir_contents \
    "${PLUGIN_WRAPPER_DIR}/commands" \
    "${plugin_root}/commands"
  copy_optional_dir_contents \
    "${PLUGIN_WRAPPER_DIR}/assets" \
    "${plugin_root}/assets"
  copy_dir_contents \
    "${REPO_ROOT}/skills" \
    "${plugin_root}/skills"
  copy_dir_contents \
    "${REPO_ROOT}/agents" \
    "${plugin_root}/agents"
}

list_commands() {
  find "${PLUGIN_WRAPPER_DIR}/commands" -maxdepth 1 -type f -name '*.md' | sort
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
    --force)
      FORCE=1
      shift
      ;;
    -h|--help)
      usage
      exit 0
      ;;
    *)
      if [[ -z "$WORKSPACE" ]]; then
        WORKSPACE="$1"
      else
        fail "Unexpected argument: $1"
      fi
      shift
      ;;
  esac
done

require_file "${PLUGIN_WRAPPER_DIR}/.codex-plugin/plugin.json"
require_file "${MARKETPLACE_TEMPLATE}"

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

# ── install files ─────────────────────────────────────────────────────────────

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

# ── done ──────────────────────────────────────────────────────────────────────

log ""
log "Done. Installed:"
log "  ${PLUGIN_DEST}/"
log "  ${MARKETPLACE_DEST}"
log ""
log "Commands:"
while IFS= read -r cmd; do
  log "  $(basename "${cmd%.md}")"
done < <(list_commands)
log ""
log "Archive: ${ARCHIVE}"
if [[ "$SCOPE" == "user" ]]; then
  log "Codex can discover the plugin from ~/.agents/plugins/marketplace.json."
else
  log "Codex can discover the plugin from the workspace .agents/plugins/marketplace.json."
fi
