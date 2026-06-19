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

# skills: full library from skills/
assert_dir  "${CACHE}/skills"
assert_count "${CACHE}/skills" 43 "skills total"

# agents
assert_dir  "${CACHE}/agents"
assert_count "${CACHE}/agents" 9 "agents"

# commands: all top-level .md from commands/
assert_dir "${CACHE}/commands"
assert_count "${CACHE}/commands" 24 "top-level commands"

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

# commands are served from the plugin package (namespaced /uncle-dev:<command>),
# NOT promoted into ~/.claude/commands/. Guard against the duplication regression.
assert_file "${CACHE}/commands/uncle-dev-spec.md"
if [[ ! -e "${FAKE_HOME}/.claude/commands/uncle-dev-spec.md" ]]; then
  ok "commands not promoted to ~/.claude/commands/ (served from plugin)"
else
  fail "commands were promoted to ~/.claude/commands/ (should be plugin-only)"
fi

# archive
assert_file "${REPO_ROOT}/dist/uncle-dev-claude.tar.gz"

# marketplace + installed registration
python3 -c "
import json
mm = json.load(open('${PLUGINS_DIR}/known_marketplaces.json'))
assert 'uncle-dev-agent-skills' in mm, 'marketplace not registered'
ip = json.load(open('${PLUGINS_DIR}/installed_plugins.json'))
keys = list(ip.get('plugins', {}))
# Canonical key: <plugin.json name>@<marketplace.json name> = uncle-dev@uncle-dev-agent-skills.
# Guards against the regression where the marketplace id was used as the plugin name.
assert 'uncle-dev@uncle-dev-agent-skills' in keys, f'canonical plugin key missing; got {keys}'
assert 'uncle-dev-agent-skills@uncle-dev-agent-skills' not in keys, f'mis-keyed registration present; got {keys}'
" && ok "plugin registered under canonical key uncle-dev@uncle-dev-agent-skills" || fail "plugin not registered under canonical key"

# ── result ────────────────────────────────────────────────────────────────────

echo ""
echo "── Result ────────────────────────────────────────────────"
echo "  PASS: ${PASS}  FAIL: ${FAIL}"
[[ "$FAIL" -eq 0 ]] || exit 1
