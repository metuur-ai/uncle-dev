#!/bin/bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"
PLUGIN_NAME="uncle-dev"

SCOPE="user"

usage() {
  cat <<'EOF'
Usage:
  ./scripts/uninstall-hermes.sh [--scope user|local] [workspace]

Removes the Uncle Dev Hermes plugin installed by install-hermes.sh.

Options:
  --scope   user (default, removes from ~/.hermes/plugins/) or local (removes
            from <workspace>/plugins/)
  -h, --help  Show this help message

Examples:
  ./scripts/uninstall-hermes.sh
  ./scripts/uninstall-hermes.sh --scope local ~/code/my-app
  ./scripts/uninstall-hermes.sh --scope local .
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
    read -r -p "No workspace provided. Remove from current directory: $WORKSPACE? [y/N] " reply
    case "$reply" in y|Y|yes|YES) ;; *) fail "Aborted" ;; esac
  fi
  BUNDLE_ROOT="${WORKSPACE}"
fi

PLUGIN_DEST="${BUNDLE_ROOT}/plugins/${PLUGIN_NAME}"

# ── repo-root guard ───────────────────────────────────────────────────────────
# Refuse to delete plugin source that lives inside this repo's checkout.
# Mirrors the guard in install-hermes.sh:200 (every installer has this;
# the uninstaller must too — audit Finding A).
TRACKED_PLUGIN_DIR="${REPO_ROOT}/plugins/${PLUGIN_NAME}"

# Resolve both paths to canonical form so symlinks and ".." segments don't
# bypass the check (bash 3.2: no realpath, use cd-and-pwd).
_dest_resolved="$(cd "${PLUGIN_DEST}" 2>/dev/null && pwd || true)"
_tracked_resolved="$(cd "${TRACKED_PLUGIN_DIR}" 2>/dev/null && pwd || true)"

if [[ -n "$_tracked_resolved" && -n "$_dest_resolved" ]]; then
  if [[ "$_dest_resolved" == "$_tracked_resolved" ]] || \
     [[ "$_dest_resolved" == "${REPO_ROOT}"* ]]; then
    fail "Refusing: destination '${PLUGIN_DEST}' resolves inside the plugin source repository (${REPO_ROOT}). Aborting to protect checked-in source. Pass --scope user or a workspace path outside the repo."
  fi
fi

# ── confirm removal ───────────────────────────────────────────────────────────

if [[ ! -d "$PLUGIN_DEST" ]]; then
  log "Nothing to remove: ${PLUGIN_DEST} does not exist."
  exit 0
fi

log "This will permanently remove:"
log "  ${PLUGIN_DEST}/"
log ""
read -r -p "Remove? [y/N] " reply
case "$reply" in y|Y|yes|YES) ;; *) fail "Aborted" ;; esac

# ── remove ────────────────────────────────────────────────────────────────────

rm -rf "${PLUGIN_DEST}"

log ""
log "Removed: ${PLUGIN_DEST}"
log ""
log "The uncle-dev plugin has been uninstalled from Hermes."
log "Run 'hermes' and check /plugins to confirm it is gone."
