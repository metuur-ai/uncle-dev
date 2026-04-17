#!/bin/bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"
DIST_DIR="${REPO_ROOT}/dist"

SCOPE="local"
FORCE=0

usage() {
  cat <<'EOF'
Usage:
  ./scripts/install-opencode.sh [--scope local|global] [--force] [workspace]

Installs uncle-dev agent skills for OpenCode. Copies AGENTS.md, skills/,
and agents/ into the OpenCode config directory (global) or project workspace
(local). Also generates dist/uncle-dev-opencode.tar.gz.

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

log()  { echo "$*" >&2; }
fail() { log "Error: $*"; exit 1; }

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

if [[ "$SCOPE" == "global" ]]; then
  [[ -z "$WORKSPACE" ]] || fail "Do not pass a workspace when using --scope global"
  AGENTS_DEST="${HOME}/.config/opencode/AGENTS.md"
  SKILLS_DEST="${HOME}/.config/opencode/skills"
  AGENTS_PERSONAS_DEST="${HOME}/.config/opencode/agents"
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
  AGENTS_DEST="${WORKSPACE}/AGENTS.md"
  SKILLS_DEST="${WORKSPACE}/.opencode/skills"
  AGENTS_PERSONAS_DEST="${WORKSPACE}/.opencode/agents"
fi

log "Installing for OpenCode in $(dirname "$AGENTS_DEST")"

# ── helper functions ──────────────────────────────────────────────────────────

copy_file() {
  local src="$1"
  local dest="$2"
  mkdir -p "$(dirname "$dest")"
  if [[ -f "$dest" ]] && cmp -s "$src" "$dest"; then
    return 0
  fi
  if [[ -e "$dest" && "$FORCE" -ne 1 ]]; then
    if [[ "$(basename "$dest")" == "AGENTS.md" ]]; then
      log "Conflict: existing AGENTS.md differs: $dest"
      read -r -p "Replace it? [y/N] " reply
      case "$reply" in y|Y|yes|YES) cp "$src" "$dest"; return 0 ;; *) fail "Aborted" ;; esac
    fi
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

# ── install files ─────────────────────────────────────────────────────────────

# AGENTS.md — OpenCode reads this for agent instructions
copy_file "${REPO_ROOT}/AGENTS.md" "${AGENTS_DEST}"

# skills/ — all skill directories with SKILL.md and colocated reference files
copy_dir_contents "${REPO_ROOT}/skills" "${SKILLS_DEST}"

# agents/ — reusable agent personas
copy_dir_contents "${REPO_ROOT}/agents" "${AGENTS_PERSONAS_DEST}"

# ── generate distributable archive ───────────────────────────────────────────

mkdir -p "${DIST_DIR}"
ARCHIVE="${DIST_DIR}/uncle-dev-opencode.tar.gz"
BUNDLE_TMP="${DIST_DIR}/.opencode-bundle-tmp"

log "Generating archive at ${ARCHIVE}"

rm -rf "${BUNDLE_TMP}"
mkdir -p "${BUNDLE_TMP}"
cp "${REPO_ROOT}/AGENTS.md" "${BUNDLE_TMP}/AGENTS.md"
cp -r "${REPO_ROOT}/skills" "${BUNDLE_TMP}/skills"
cp -r "${REPO_ROOT}/agents" "${BUNDLE_TMP}/agents"
tar -czf "${ARCHIVE}" -C "${DIST_DIR}" ".opencode-bundle-tmp"
rm -rf "${BUNDLE_TMP}"

# ── done ──────────────────────────────────────────────────────────────────────

log ""
log "Done. Installed:"
log "  ${AGENTS_DEST}"
log "  ${SKILLS_DEST}/"
log "  ${AGENTS_PERSONAS_DEST}/"
log ""
log "Archive: ${ARCHIVE}"
