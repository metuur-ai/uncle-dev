#!/bin/bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"
DIST_DIR="${REPO_ROOT}/dist"

SCOPE="user"
FORCE=0

usage() {
  cat <<'EOF'
Usage:
  ./scripts/install-codex.sh [--scope user|local] [--force] [workspace]

Installs uncle-dev agent skills for OpenAI Codex CLI. Copies AGENTS.md,
skills/, and agents/ into the Codex config directory (global) or project
workspace (local). Also generates dist/uncle-dev-codex.tar.gz.

Options:
  --scope   user (default, installs to ~/.codex/) or local (installs to workspace)
  --force   Overwrite files that already exist
  -h, --help  Show this help message

Examples:
  ./scripts/install-codex.sh                          # global user scope
  ./scripts/install-codex.sh --scope local ~/code/my-app
  ./scripts/install-codex.sh --scope local .
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
  INSTALL_ROOT="${HOME}/.codex"
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
fi

log "Installing for Codex in ${INSTALL_ROOT}"

# ── helper functions ──────────────────────────────────────────────────────────

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

# ── install files ─────────────────────────────────────────────────────────────

# AGENTS.md — Codex reads this for project/global instructions
copy_file "${REPO_ROOT}/AGENTS.md" "${INSTALL_ROOT}/AGENTS.md"

# skills/ — all skill directories with SKILL.md and colocated reference files
copy_dir_contents "${REPO_ROOT}/skills" "${INSTALL_ROOT}/skills"

# agents/ — reusable agent personas
copy_dir_contents "${REPO_ROOT}/agents" "${INSTALL_ROOT}/agents"

# ── generate distributable archive ───────────────────────────────────────────

mkdir -p "${DIST_DIR}"
ARCHIVE="${DIST_DIR}/uncle-dev-codex.tar.gz"
BUNDLE_TMP="${DIST_DIR}/.codex-bundle-tmp"

log "Generating archive at ${ARCHIVE}"

rm -rf "${BUNDLE_TMP}"
mkdir -p "${BUNDLE_TMP}"
cp "${REPO_ROOT}/AGENTS.md" "${BUNDLE_TMP}/AGENTS.md"
cp -r "${REPO_ROOT}/skills" "${BUNDLE_TMP}/skills"
cp -r "${REPO_ROOT}/agents" "${BUNDLE_TMP}/agents"
tar -czf "${ARCHIVE}" -C "${DIST_DIR}" ".codex-bundle-tmp"
rm -rf "${BUNDLE_TMP}"

# ── done ──────────────────────────────────────────────────────────────────────

log ""
log "Done. Installed:"
log "  ${INSTALL_ROOT}/AGENTS.md"
log "  ${INSTALL_ROOT}/skills/"
log "  ${INSTALL_ROOT}/agents/"
log ""
log "Archive: ${ARCHIVE}"
if [[ "$SCOPE" == "user" ]]; then
  log "Codex will load AGENTS.md from ~/.codex/ automatically."
else
  log "Codex will load AGENTS.md from the project root automatically."
fi
