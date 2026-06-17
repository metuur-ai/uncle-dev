#!/bin/bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

usage() {
  cat <<'EOF'
Usage:
  ./scripts/install.sh <tool> [tool-options]
  ./scripts/install.sh all [--force]
  ./scripts/install.sh verify

Tools:
  claude    Install as Claude Code plugin
  codex     Install as Codex plugin
  opencode  Install for OpenCode

Commands:
  all       Run claude + codex installers (opencode requires a workspace arg)
  verify    Run test suite to validate all installs

Tool options are passed through to the per-tool installer unchanged:
  ./scripts/install.sh claude --force
  ./scripts/install.sh codex --scope local ~/code/my-app
  ./scripts/install.sh opencode --scope global
  ./scripts/install.sh opencode --scope local ~/code/my-app

Examples:
  ./scripts/install.sh all --force
  ./scripts/install.sh claude --force
  ./scripts/install.sh codex
  ./scripts/install.sh opencode --scope global
  ./scripts/install.sh verify
EOF
}

fail() { echo "Error: $*" >&2; exit 1; }

[[ $# -gt 0 ]] || { usage; exit 1; }

TOOL="$1"
shift

case "$TOOL" in
  claude)
    exec "${SCRIPT_DIR}/install-claude.sh" "$@"
    ;;
  codex)
    exec "${SCRIPT_DIR}/install-codex.sh" "$@"
    ;;
  opencode)
    exec "${SCRIPT_DIR}/install-opencode.sh" "$@"
    ;;
  all)
    echo "── Installing Claude Code plugin ────────────────────────" >&2
    "${SCRIPT_DIR}/install-claude.sh" "$@"
    echo "" >&2
    echo "── Installing Codex plugin ──────────────────────────────" >&2
    "${SCRIPT_DIR}/install-codex.sh" "$@"
    echo "" >&2
    echo "Done. Run './scripts/install.sh opencode --scope global' to install for OpenCode." >&2
    ;;
  verify)
    "${SCRIPT_DIR}/check-manifest.sh"
    exec "${SCRIPT_DIR}/tests/run-all.sh"
    ;;
  -h|--help)
    usage
    exit 0
    ;;
  *)
    fail "Unknown tool: $TOOL (expected: claude, codex, opencode, all, verify)"
    ;;
esac
