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

# skills: full library from skills/
assert_dir  "${PLUGIN_ROOT}/skills"
assert_count "${PLUGIN_ROOT}/skills" 43 "skills total"

REPO_SKILL_AGENT_MANIFESTS="$(find "${REPO_ROOT}/skills" -path '*/agents/openai.yaml' -type f | wc -l | tr -d ' ')"
[[ "${REPO_SKILL_AGENT_MANIFESTS}" -eq 0 ]] \
  && ok "shared skills tree has no Codex agent manifests" \
  || fail "shared skills tree still contains ${REPO_SKILL_AGENT_MANIFESTS} Codex agent manifests"

SOURCE_AGENT_MANIFESTS="$(find "${REPO_ROOT}/plugins/uncle-dev/agent-manifests" -path '*/openai.yaml' -type f | wc -l | tr -d ' ')"
INSTALLED_AGENT_MANIFESTS="$(find "${PLUGIN_ROOT}/skills" -path '*/agents/openai.yaml' -not -path '*/command-*/*' -type f | wc -l | tr -d ' ')"
[[ "${INSTALLED_AGENT_MANIFESTS}" -eq "${SOURCE_AGENT_MANIFESTS}" ]] \
  && ok "skill-local openai.yaml manifests copied: ${INSTALLED_AGENT_MANIFESTS}" \
  || fail "skill-local openai.yaml manifests copied: got ${INSTALLED_AGENT_MANIFESTS}, expected ${SOURCE_AGENT_MANIFESTS}"

# agents
assert_dir  "${PLUGIN_ROOT}/agents"
assert_count "${PLUGIN_ROOT}/agents" 9 "agents"

# commands: all from commands/
assert_dir "${PLUGIN_ROOT}/command-templates"

# Discovery matters: large command bodies must remain intact behind small,
# explicit entry points, and agent personas must be native TOML definitions.
python3 - "${REPO_ROOT}" "${PLUGIN_ROOT}" "${FAKE_HOME}" <<'PY' \
  && ok "all commands and agents are invocable without truncation" \
  || fail "command/agent discovery contract failed"
import json, pathlib, sys
try:
    import tomllib
except ImportError:
    tomllib = None
repo, plugin, home = map(pathlib.Path, sys.argv[1:])
for source in (repo / 'commands').rglob('*.md'):
    if source.name in ('README.md', 'AGENTS.md'):
        continue
    relative = source.relative_to(repo / 'commands')
    name = 'command-' + '-'.join(relative.with_suffix('').parts)
    entry = plugin / 'skills' / name / 'SKILL.md'
    assert entry.is_file(), f'undiscoverable command: {relative}'
    assert entry.stat().st_size < 4000, f'oversized entry: {relative}'
    assert (plugin / 'command-templates' / relative).read_bytes() == source.read_bytes()
    assert relative.as_posix() in entry.read_text()
assert not (plugin / 'commands').exists(), 'legacy automatic migration would duplicate commands'
for source in (repo / 'agents').glob('*.md'):
    if source.name in ('README.md', 'AGENTS.md'):
        continue
    agent = home / '.codex' / 'agents' / (source.stem + '.toml')
    assert agent.is_file(), f'unregistered agent: {source.stem}'
    # Generated TOML uses JSON-compatible basic string values.
    fields = dict(line.split(' = ', 1) for line in agent.read_text().splitlines())
    assert json.loads(fields['name']) == source.stem
    if tomllib:
        parsed = tomllib.loads(agent.read_text())
        assert parsed['name'] == source.stem
        assert 'model' not in parsed, 'Claude model aliases must not become Codex models'
    body = source.read_text().split('---', 2)[2].strip()
    assert body in json.loads(fields['developer_instructions'])
spec_ui = plugin / 'skills/uncle-dev-spec-driven-development/agents/openai.yaml'
assert 'Uncle PO' not in spec_ui.read_text(), 'skill still impersonates independent agent'
for skill in (repo / 'skills').glob('*/SKILL.md'):
    installed = plugin / 'skills' / skill.parent.name / 'SKILL.md'
    assert 'Read ../../CODEX.md' in installed.read_text()
    assert skill.read_text().split('---', 2)[2] in installed.read_text()
PY

# rules
for rule in "${ASSET_RULES[@]}"; do
  assert_file "${PLUGIN_ROOT}/${rule}"
done

# plugin manifest
assert_file "${PLUGIN_ROOT}/.codex-plugin/plugin.json"
assert_file "${PLUGIN_ROOT}/${ASSET_CODEX_INSTALL_GUIDE}"

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

# Reinstall must compare final generated content, preserve unrelated agents,
# and refuse modified files before changing any installed components.
printf 'unrelated agent\n' > "${FAKE_HOME}/.codex/agents/unrelated.toml"
BEFORE_VERSION="$(python3 -c 'import json,sys; print(json.load(open(sys.argv[1]))["version"])' "${PLUGIN_ROOT}/.codex-plugin/plugin.json")"
if HOME="${FAKE_HOME}" bash "${INSTALL_SCRIPT}" --scope user >"${FAKE_HOME}/reinstall.log" 2>&1; then
  ok "identical reinstall succeeds without --force"
else
  cat "${FAKE_HOME}/reinstall.log"
  fail "identical reinstall failed"
fi
AFTER_VERSION="$(python3 -c 'import json,sys; print(json.load(open(sys.argv[1]))["version"])' "${PLUGIN_ROOT}/.codex-plugin/plugin.json")"
[[ "$BEFORE_VERSION" == "$AFTER_VERSION" ]] && ok "cachebuster is reproducible" || fail "cachebuster drift"
printf '\nuser edit\n' >> "${FAKE_HOME}/.codex/agents/uncle-po.toml"
if HOME="${FAKE_HOME}" bash "${INSTALL_SCRIPT}" --scope user >"${FAKE_HOME}/conflict.log" 2>&1; then
  fail "overwrote edited agent without --force"
else
  if grep -q 'Refusing to overwrite:.*uncle-po.toml' "${FAKE_HOME}/conflict.log"; then
    ok "edited native agent requires --force"
  else
    cat "${FAKE_HOME}/conflict.log"
    fail "installer failed for an unexpected reason"
  fi
fi

LOCAL_PROJECT="${FAKE_HOME}/local project"
mkdir -p "$LOCAL_PROJECT"
HOME="${FAKE_HOME}" bash "${INSTALL_SCRIPT}" --scope local "$LOCAL_PROJECT" >"${FAKE_HOME}/local.log" 2>&1
assert_file "${LOCAL_PROJECT}/.codex/agents/uncle-po.toml"
assert_file "${LOCAL_PROJECT}/plugins/uncle-dev/skills/command-uncle-dev-spec/SKILL.md"
assert_file "${FAKE_HOME}/.codex/agents/unrelated.toml"

# Validate relocatability and preserve the original long command in the archive.
python3 - "${REPO_ROOT}" <<'PY' \
  && ok "archive includes portable full commands and native agents" \
  || fail "archive coverage failed"
import pathlib, sys, tarfile
repo = pathlib.Path(sys.argv[1])
with tarfile.open(repo / 'dist/uncle-dev-codex.tar.gz') as archive:
    assert archive.extractfile('./plugins/uncle-dev/command-templates/uncle-dev-spec.md').read() == (repo / 'commands/uncle-dev-spec.md').read_bytes()
    assert archive.extractfile('./.codex/agents/uncle-po.toml')
PY

# ── result ────────────────────────────────────────────────────────────────────

echo ""
echo "── Result ────────────────────────────────────────────────"
echo "  PASS: ${PASS}  FAIL: ${FAIL}"
[[ "$FAIL" -eq 0 ]] || exit 1
