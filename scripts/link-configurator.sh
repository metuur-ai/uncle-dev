#!/usr/bin/env bash
# link-configurator.sh — put `uncle-dev-configure` on the user's PATH.
#
# Creates a symlink ~/.local/bin/uncle-dev-configure -> this plugin's
# scripts/uncle-dev-configure.py, so users can launch the interactive config
# TUI from any project by typing `uncle-dev-configure`. Safe to re-run: the
# symlink is refreshed to the current install (ln -sf), so upgrades just work.
#
# Called by the installers, and runnable standalone:
#   bash <plugin>/scripts/link-configurator.sh [bin-dir]
#
# The configurator resolves its bundled schema via realpath(__file__), so it
# works correctly even when invoked through this symlink.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
TARGET="${SCRIPT_DIR}/uncle-dev-configure.py"
BIN_DIR="${1:-${HOME}/.local/bin}"
LINK="${BIN_DIR}/uncle-dev-configure"

if [[ ! -f "${TARGET}" ]]; then
  echo "link-configurator: cannot find ${TARGET}" >&2
  exit 1
fi

mkdir -p "${BIN_DIR}"
chmod +x "${TARGET}" 2>/dev/null || true
ln -sf "${TARGET}" "${LINK}"
echo "linked ${LINK} -> ${TARGET}"

case ":${PATH}:" in
  *":${BIN_DIR}:"*) : ;;
  *)
    echo "note: ${BIN_DIR} is not on your PATH." >&2
    echo "      add it, e.g.:  echo 'export PATH=\"${BIN_DIR}:\$PATH\"' >> ~/.zshrc" >&2
    ;;
esac
