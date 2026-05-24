#!/bin/bash
# Tests for install-claude.sh
# Runs the installer into a temp HOME and asserts all expected assets are present.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/../.." && pwd)"
INSTALL_SCRIPT="${SCRIPT_DIR}/../install-claude.sh"

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

PLUGINS_DIR="${FAKE_HOME}/.claude/plugins"
mkdir -p "${PLUGINS_DIR}/cache"
echo '{}' > "${PLUGINS_DIR}/known_marketplaces.json"
echo '{"plugins":{}}' > "${PLUGINS_DIR}/installed_plugins.json"

# ── run installer ─────────────────────────────────────────────────────────────

echo "Running install-claude.sh into fake HOME: ${FAKE_HOME}"
HOME="${FAKE_HOME}" bash "${INSTALL_SCRIPT}" --force 2>&1 | sed 's/^/  /'

CACHE="$(find "${PLUGINS_DIR}/cache" -mindepth 3 -maxdepth 3 -type d | head -1)"
[[ -n "$CACHE" ]] || { echo "FAIL: cache dir not created"; exit 1; }
echo "Cache: ${CACHE}"

# ── assertions ────────────────────────────────────────────────────────────────

echo ""
echo "── Asset coverage ────────────────────────────────────────"

# skills: 32 root + 4 openspec = 36
assert_dir  "${CACHE}/skills"
assert_count "${CACHE}/skills" 36 "skills total"

# openspec skills specifically
for skill in openspec-apply-change openspec-archive-change openspec-explore openspec-propose; do
  assert_dir "${CACHE}/skills/${skill}"
done

# agents
assert_dir  "${CACHE}/agents"
assert_count "${CACHE}/agents" 6 "agents"

# commands: 19 top-level + opsx/ subdir with 4
assert_dir "${CACHE}/commands"
assert_count "${CACHE}/commands" 20 "top-level commands (19 md + opsx dir)"  # 19 md + opsx dir
assert_dir "${CACHE}/commands/opsx"
assert_count "${CACHE}/commands/opsx" 4 "opsx commands"

# hooks
assert_dir "${CACHE}/hooks"
assert_file "${CACHE}/hooks/hooks.json"
assert_file "${CACHE}/hooks/session-start.sh"

# hooks.json also at .claude-plugin/ for auto-discovery
assert_file "${CACHE}/.claude-plugin/hooks.json"

# plugin manifest (full, not filtered)
assert_file "${CACHE}/.claude-plugin/plugin.json"
# verify it has commands field (was stripped by old jq filter)
python3 -c "
import json, sys
d = json.load(open('${CACHE}/.claude-plugin/plugin.json'))
assert 'commands' in d, 'plugin.json missing commands key'
" 2>/dev/null && ok "plugin.json retains commands key" || fail "plugin.json missing commands key (was filtered)"

# rules
for rule in "${ASSET_RULES[@]}"; do
  assert_file "${CACHE}/${rule}"
done

# commands promoted to ~/.claude/commands/
assert_dir  "${FAKE_HOME}/.claude/commands"
assert_file "${FAKE_HOME}/.claude/commands/uncle-dev-spec.md"
assert_dir  "${FAKE_HOME}/.claude/commands/opsx"
assert_file "${FAKE_HOME}/.claude/commands/opsx/apply.md"

# archive
assert_file "${REPO_ROOT}/dist/uncle-dev-claude.tar.gz"

# marketplace + installed registration
python3 -c "
import json
mm = json.load(open('${PLUGINS_DIR}/known_marketplaces.json'))
assert 'uncle-dev-agent-skills' in mm, 'marketplace not registered'
ip = json.load(open('${PLUGINS_DIR}/installed_plugins.json'))
assert any('uncle-dev-agent-skills' in k for k in ip.get('plugins', {})), 'plugin not registered'
" && ok "marketplace and plugin registered" || fail "marketplace or plugin not registered"

# ── result ────────────────────────────────────────────────────────────────────

echo ""
echo "── Result ────────────────────────────────────────────────"
echo "  PASS: ${PASS}  FAIL: ${FAIL}"
[[ "$FAIL" -eq 0 ]] || exit 1
