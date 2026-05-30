#!/bin/bash
# Tests for install-codex.sh
# Runs the installer (user scope) into a temp HOME and asserts all expected assets.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/../.." && pwd)"
INSTALL_SCRIPT="${SCRIPT_DIR}/../install-codex.sh"

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

# ── set up temp HOME ──────────────────────────────────────────────────────────

FAKE_HOME="$(mktemp -d)"
trap 'rm -rf "${FAKE_HOME}"' EXIT

echo "Running install-codex.sh into fake HOME: ${FAKE_HOME}"
HOME="${FAKE_HOME}" bash "${INSTALL_SCRIPT}" --scope user --force 2>&1 | sed 's/^/  /'

PLUGIN_ROOT="${FAKE_HOME}/plugins/uncle-dev"

# ── assertions ────────────────────────────────────────────────────────────────

echo ""
echo "── Asset coverage ────────────────────────────────────────"

# skills: 36 (32 root + 4 openspec)
assert_dir  "${PLUGIN_ROOT}/skills"
assert_count "${PLUGIN_ROOT}/skills" 36 "skills total"

for skill in openspec-apply-change openspec-archive-change openspec-explore openspec-propose; do
  assert_dir "${PLUGIN_ROOT}/skills/${skill}"
done

# agents
assert_dir  "${PLUGIN_ROOT}/agents"
assert_count "${PLUGIN_ROOT}/agents" 8 "agents"

# commands: all from .claude/commands/ (19 top-level + opsx/)
assert_dir  "${PLUGIN_ROOT}/commands"
assert_count "${PLUGIN_ROOT}/commands" 20 "commands dir entries (19 md + opsx)"
assert_dir  "${PLUGIN_ROOT}/commands/opsx"
assert_count "${PLUGIN_ROOT}/commands/opsx" 4 "opsx commands"

# rules
for rule in "${ASSET_RULES[@]}"; do
  assert_file "${PLUGIN_ROOT}/${rule}"
done

# plugin manifest
assert_file "${PLUGIN_ROOT}/.codex-plugin/plugin.json"

# marketplace registered
assert_file "${FAKE_HOME}/.agents/plugins/marketplace.json"
python3 -c "
import json
mm = json.load(open('${FAKE_HOME}/.agents/plugins/marketplace.json'))
plugins = mm.get('plugins', [])
assert any(p.get('name') == 'uncle-dev' for p in plugins), 'uncle-dev not in marketplace'
" && ok "marketplace contains uncle-dev" || fail "uncle-dev not found in marketplace"

# archive
assert_file "${REPO_ROOT}/dist/uncle-dev-codex.tar.gz"

# ── result ────────────────────────────────────────────────────────────────────

echo ""
echo "── Result ────────────────────────────────────────────────"
echo "  PASS: ${PASS}  FAIL: ${FAIL}"
[[ "$FAIL" -eq 0 ]] || exit 1
