#!/bin/bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"
DIST_DIR="${REPO_ROOT}/dist"
PLUGIN_NAME="uncle-dev"
# Derive version from plugin.json (same pattern as install-claude.sh:27) so a
# version bump in the manifest propagates with zero manual edits (R-9.4).
command -v jq >/dev/null 2>&1 || { echo "Error: jq is required but not installed." >&2; exit 1; }
PLUGIN_VERSION="$(jq -r '.version' "${REPO_ROOT}/.claude-plugin/plugin.json")"
[[ -n "${PLUGIN_VERSION}" && "${PLUGIN_VERSION}" != "null" ]] || { echo "Error: Could not read version from .claude-plugin/plugin.json" >&2; exit 1; }
PLUGIN_DESCRIPTION="Production-grade engineering skills — spec-driven development from idea to shipped feature."

# Shared copy helpers (copy_file, copy_dir_contents) sourced from lib (R-9.5).
# shellcheck source=lib/install-common.sh
source "${SCRIPT_DIR}/lib/install-common.sh"

SCOPE="user"
FORCE=0

usage() {
  cat <<'EOF'
Usage:
  ./scripts/install-hermes.sh [--scope user|local] [--force] [workspace]

Installs Uncle Dev as a Hermes plugin. Skills are bundled inside the plugin
directory and registered via ctx.register_skill() so Hermes can load them
on demand with skill_view("uncle-dev:<skill-name>").

Layout installed:
  plugins/uncle-dev/
  ├── plugin.yaml         # manifest
  ├── __init__.py         # register(ctx) — wires all skills
  └── skills/
      └── <skill-name>/
          └── SKILL.md

Options:
  --scope   user (default, installs to ~/.hermes/plugins/) or local (installs
            to <workspace>/plugins/)
  --force   Overwrite files that already exist
  -h, --help  Show this help message

Examples:
  ./scripts/install-hermes.sh
  ./scripts/install-hermes.sh --scope local ~/code/my-app
  ./scripts/install-hermes.sh --scope local .
EOF
}

log()  { echo "$*" >&2; }
fail() { log "Error: $*"; exit 1; }

write_plugin_yaml() {
  local dest="$1"
  local tmp
  tmp="$(mktemp)"
  cat >"$tmp" <<EOF
name: ${PLUGIN_NAME}
version: ${PLUGIN_VERSION}
description: "${PLUGIN_DESCRIPTION}"
EOF
  copy_file "$tmp" "$dest"
  rm -f "$tmp"
}

# Generates __init__.py with a register(ctx) function that calls
# ctx.register_skill() for every skill bundled in the plugin's skills/ dir.
write_init_py() {
  local dest="$1"
  local tmp
  tmp="$(mktemp)"

  # Build the list of skill names from the repo's skills/ dir
  local skill_list=""
  local entry name
  for entry in "${REPO_ROOT}/skills"/*/; do
    [[ -d "$entry" ]] || continue
    name="$(basename "$entry")"
    skill_list="${skill_list}    \"${name}\",\n"
  done

  cat >"$tmp" <<PYEOF
"""Uncle Dev plugin for Hermes Agent — registers all bundled skills."""

from pathlib import Path

_PLUGIN_DIR = Path(__file__).parent
_SKILLS_DIR = _PLUGIN_DIR / "skills"

# All skill directory names bundled in this plugin
_SKILLS = [
$(printf "%b" "${skill_list}")\
]


def register(ctx):
    """Register all uncle-dev skills with Hermes."""
    for skill_name in _SKILLS:
        skill_md = _SKILLS_DIR / skill_name / "SKILL.md"
        if skill_md.exists():
            ctx.register_skill(skill_name, skill_md)
PYEOF

  copy_file "$tmp" "$dest"
  rm -f "$tmp"
}

assemble_plugin() {
  local bundle_root="$1"
  local plugin_root="${bundle_root}/plugins/${PLUGIN_NAME}"

  mkdir -p "$plugin_root"

  write_plugin_yaml "$plugin_root/plugin.yaml"
  write_init_py     "$plugin_root/__init__.py"

  # Bundle skills inside the plugin directory
  local entry name
  for entry in "${REPO_ROOT}/skills"/*/; do
    [[ -d "$entry" ]] || continue
    name="$(basename "$entry")"
    copy_dir_contents "$entry" "$plugin_root/skills/$name" "$FORCE"
  done
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

# ── resolve install root ──────────────────────────────────────────────────────

if [[ "$SCOPE" == "user" ]]; then
  [[ -z "$WORKSPACE" ]] || fail "Do not pass a workspace when using --scope user"
  BUNDLE_ROOT="${HOME}/.hermes"
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

log "Installing Hermes plugin into ${PLUGIN_DEST}"

# ── install files ─────────────────────────────────────────────────────────────

assemble_plugin "${BUNDLE_ROOT}"

# ── generate distributable archive ───────────────────────────────────────────

mkdir -p "${DIST_DIR}"
ARCHIVE="${DIST_DIR}/uncle-dev-hermes.tar.gz"
BUNDLE_TMP="${DIST_DIR}/.hermes-bundle-tmp"

log "Generating archive at ${ARCHIVE}"

rm -rf "${BUNDLE_TMP}"
mkdir -p "${BUNDLE_TMP}"
assemble_plugin "${BUNDLE_TMP}"
tar -czf "${ARCHIVE}" -C "${DIST_DIR}" ".hermes-bundle-tmp"
rm -rf "${BUNDLE_TMP}"

# ── done ──────────────────────────────────────────────────────────────────────

log ""
log "Done. Installed:"
log "  ${PLUGIN_DEST}/plugin.yaml"
log "  ${PLUGIN_DEST}/__init__.py"
log "  ${PLUGIN_DEST}/skills/  ($(ls "${PLUGIN_DEST}/skills" | wc -l | tr -d ' ') skills)"
log ""
log "Skills (load with skill_view(\"uncle-dev:<name>\")):"
for entry in "${PLUGIN_DEST}/skills"/*/; do
  [[ -d "$entry" ]] || continue
  log "  uncle-dev:$(basename "$entry")"
done
log ""
log "Archive: ${ARCHIVE}"
log ""
if [[ "$SCOPE" == "user" ]]; then
  log "Hermes will auto-discover the plugin from ~/.hermes/plugins/."
  log "Run 'hermes' and check the banner, or type /plugins to verify."
else
  log "Run Hermes from ${WORKSPACE} so it scans this plugins/ tree."
  log "Type /plugins in a session to verify uncle-dev is loaded."
fi
