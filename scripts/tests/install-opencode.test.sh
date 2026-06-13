#!/bin/bash
# Tests for install-opencode.sh
# Runs the installer (global scope) into a temp HOME and asserts all expected assets.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/../.." && pwd)"
INSTALL_SCRIPT="${SCRIPT_DIR}/../install-opencode.sh"

source "${SCRIPT_DIR}/../lib/manifest.sh"

PASS=0; FAIL=0

ok()   { echo "  PASS: $*"; ((PASS++)) || true; }
fail() { echo "  FAIL: $*"; ((FAIL++)) || true; }

assert_file()  { [[ -f "$1" ]] && ok "$1 exists" || fail "Missing file: $1"; }
assert_dir()   { [[ -d "$1" ]] && ok "$1 exists" || fail "Missing dir: $1"; }
assert_count() {
  local dir="$1" min="$2" label="$3"
  local n
  n="$(find "$dir" -mindepth 1 -maxdepth 1 2>/dev/null | wc -l | tr -d ' ')"
  [[ "$n" -ge "$min" ]] && ok "${label}: ${n} >= ${min}" || fail "${label}: got ${n}, expected >= ${min}"
}

# ── global scope test ─────────────────────────────────────────────────────────

FAKE_HOME="$(mktemp -d)"
trap 'rm -rf "${FAKE_HOME}"' EXIT

echo "Running install-opencode.sh --scope global into fake HOME: ${FAKE_HOME}"
HOME="${FAKE_HOME}" bash "${INSTALL_SCRIPT}" --scope global --force 2>&1 | sed 's/^/  /'

INSTALL_ROOT="${FAKE_HOME}/.config/opencode"

echo ""
echo "── Asset coverage (global scope) ─────────────────────────"

# AGENTS.md
assert_file "${INSTALL_ROOT}/AGENTS.md"

# skills: full library from skills/
assert_dir  "${INSTALL_ROOT}/skills"
assert_count "${INSTALL_ROOT}/skills" 43 "skills total"

# agents
assert_dir  "${INSTALL_ROOT}/agents"
assert_count "${INSTALL_ROOT}/agents" 9 "agents"

# rules
for rule in "${ASSET_RULES[@]}"; do
  assert_file "${INSTALL_ROOT}/${rule}"
done

# archive
assert_file "${REPO_ROOT}/dist/uncle-dev-opencode.tar.gz"

# ── local scope test ──────────────────────────────────────────────────────────

FAKE_WS="$(mktemp -d)"
trap 'rm -rf "${FAKE_WS}"' EXIT

echo ""
echo "Running install-opencode.sh --scope local into fake workspace: ${FAKE_WS}"
HOME="${FAKE_HOME}" bash "${INSTALL_SCRIPT}" --scope local --force "${FAKE_WS}" 2>&1 | sed 's/^/  /'

echo ""
echo "── Asset coverage (local scope) ──────────────────────────"

assert_file "${FAKE_WS}/AGENTS.md"
assert_dir  "${FAKE_WS}/.opencode/skills"
assert_count "${FAKE_WS}/.opencode/skills" 43 "skills total (local)"
assert_dir  "${FAKE_WS}/.opencode/agents"
assert_count "${FAKE_WS}/.opencode/agents" 9 "agents (local)"

for rule in "${ASSET_RULES[@]}"; do
  assert_file "${FAKE_WS}/${rule}"
done

# ── result ────────────────────────────────────────────────────────────────────

echo ""
echo "── Result ────────────────────────────────────────────────"
echo "  PASS: ${PASS}  FAIL: ${FAIL}"
[[ "$FAIL" -eq 0 ]] || exit 1
