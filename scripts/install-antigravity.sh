#!/bin/bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"

ANTIGRAVITY_SKILLS_DIR="${HOME}/.gemini/antigravity/skills"

log()  { echo "$*" >&2; }
fail() { log "Error: $*"; exit 1; }

# ── install ───────────────────────────────────────────────────────────────────

log "Installing Uncle Dev skills to Antigravity..."

# Ensure the destination directory exists
mkdir -p "${ANTIGRAVITY_SKILLS_DIR}"

# Copy all skills
log "Copying skills from ${REPO_ROOT}/skills to ${ANTIGRAVITY_SKILLS_DIR}..."
cp -r "${REPO_ROOT}/skills/"* "${ANTIGRAVITY_SKILLS_DIR}/"

log ""
log "✅ Done. Uncle Dev skills are now installed in Antigravity!"
log "You can start using commands like /uncle-dev-spec and /uncle-dev-plan."
