#!/bin/bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"

# shellcheck source=lib/manifest.sh
source "${SCRIPT_DIR}/lib/manifest.sh"
# shellcheck source=lib/install-common.sh
source "${SCRIPT_DIR}/lib/install-common.sh"

# Default destination (override with --dest <path>).
ANTIGRAVITY_SKILLS_DIR="${HOME}/.gemini/antigravity/skills"
FORCE=0

usage() {
  cat <<'EOF'
Usage:
  ./scripts/install-antigravity.sh [--dest <path>] [--force]

Installs Uncle Dev skills to the Antigravity (Gemini CLI) plugin directory.

Note: This target supports skills only. Slash commands (/uncle-dev-spec etc.)
are NOT available on Antigravity — they require a Claude Code or Codex install.

Options:
  --dest    Override the default destination (~/.gemini/antigravity/skills).
  --force   Overwrite files that already exist without prompting.
  -h, --help  Show this help message.

Examples:
  ./scripts/install-antigravity.sh
  ./scripts/install-antigravity.sh --dest ~/my-antigravity/skills
  ./scripts/install-antigravity.sh --force
EOF
}

log()       { echo "$*" >&2; }
# Redefine fail locally to shadow install-common.sh's version with same signature.
fail()      { log "Error: $*"; exit 1; }

# ── argument parsing ──────────────────────────────────────────────────────────

while [[ $# -gt 0 ]]; do
  case "$1" in
    --dest)
      shift
      [[ $# -gt 0 ]] || fail "Missing value for --dest"
      ANTIGRAVITY_SKILLS_DIR="$1"
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

# ── overwrite guard (R-9.2) ───────────────────────────────────────────────────
# Refuse to overwrite an existing installation unless --force was given.
# Check for any SKILL.md under the destination as the presence signal.
if [[ -d "${ANTIGRAVITY_SKILLS_DIR}" ]] && [[ "$FORCE" -ne 1 ]]; then
  if find "${ANTIGRAVITY_SKILLS_DIR}" -name "SKILL.md" -maxdepth 3 -print 2>/dev/null | grep -q .; then
    fail "Destination '${ANTIGRAVITY_SKILLS_DIR}' already contains skills. Re-run with --force to overwrite."
  fi
fi

# ── install ───────────────────────────────────────────────────────────────────

log "Installing Uncle Dev skills to Antigravity..."
log "Destination: ${ANTIGRAVITY_SKILLS_DIR}"

mkdir -p "${ANTIGRAVITY_SKILLS_DIR}"

log "Copying skills from ${REPO_ROOT}/skills ..."
copy_dir_contents "${REPO_ROOT}/skills" "${ANTIGRAVITY_SKILLS_DIR}" "${FORCE}"

# ── done (R-9.3) ─────────────────────────────────────────────────────────────

SKILL_COUNT="$(find "${ANTIGRAVITY_SKILLS_DIR}" -mindepth 1 -maxdepth 1 -type d 2>/dev/null | wc -l | tr -d ' ')"
log ""
log "Done. ${SKILL_COUNT} Uncle Dev skills installed to Antigravity."
log "  ${ANTIGRAVITY_SKILLS_DIR}"
log ""
log "Skills installed; commands are not supported on this target."
log "(Slash commands like /uncle-dev-spec require Claude Code or Codex.)"
