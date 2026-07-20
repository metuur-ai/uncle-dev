#!/usr/bin/env bash
# sync-plugin.sh — regenerate plugins/uncle-dev/commands/ from canonical commands/
#
# Strategy 1 (Generate): plain copy — canonical commands/ is the single source
# of truth; the plugin fork is a generated artefact, not a maintained copy.
#
# Usage:
#   bash scripts/sync-plugin.sh
#
# Idempotent — safe to re-run after any wave. Run after every commands/ edit
# before committing; the sha256 drift check in check-manifest.sh enforces this.
#
# Audit Unit 03 (R-3.1, R-3.2).
# Constraints: macOS bash 3.2 (no mapfile/declare -A); set -euo pipefail safe.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"

CANONICAL="${REPO_ROOT}/commands"
FORK="${REPO_ROOT}/plugins/uncle-dev/commands"

# ── Preflight ────────────────────────────────────────────────────────────────

if [[ ! -d "$CANONICAL" ]]; then
  echo "ERROR: canonical commands/ not found at: $CANONICAL" >&2
  exit 1
fi

if [[ ! -d "$FORK" ]]; then
  echo "ERROR: plugin fork directory not found at: $FORK" >&2
  exit 1
fi

# ── Copy canonical → fork ────────────────────────────────────────────────────

echo "── sync-plugin.sh ──────────────────────────────────────────"
echo "Canonical : $CANONICAL"
echo "Fork      : $FORK"

COPIED=0
UNCHANGED=0
REMOVED=0

# 1. Copy/overwrite every canonical file into the fork.
for src in "$CANONICAL"/*.md; do
  [[ -e "$src" ]] || continue          # nullglob safety
  name="$(basename "$src")"
  dest="$FORK/$name"
  if [[ -f "$dest" ]] && cmp -s "$src" "$dest"; then
    UNCHANGED=$((UNCHANGED + 1))
  else
    cp "$src" "$dest"
    COPIED=$((COPIED + 1))
    echo "  COPIED  : $name"
  fi
done

# 2. Remove stale files from the fork that no longer exist canonically.
for stale in "$FORK"/*.md; do
  [[ -e "$stale" ]] || continue        # nullglob safety
  name="$(basename "$stale")"
  if [[ ! -f "$CANONICAL/$name" ]]; then
    rm "$stale"
    REMOVED=$((REMOVED + 1))
    echo "  REMOVED : $name"
  fi
done

echo "───────────────────────────────────────────────────────────────"
echo "Done: ${COPIED} copied, ${UNCHANGED} unchanged, ${REMOVED} removed."
