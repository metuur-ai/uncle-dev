#!/bin/bash
# Tests for full-coverage instruction adapters (Unit 8 — R-8.1/R-8.2/R-8.3).
#
# Runs install-plugin.sh for each instruction-only target into a temp workspace
# and asserts:
#   - each adapter is emitted at its host-correct path (R-8.2)
#   - each always-on rule body is derived from canonical AGENTS.md (R-8.1)
#   - on-demand skill copies land alongside each adapter (R-8.1)
#   - the drift guard flags a hand-edited adapter (R-8.3)
#   - the default `check-manifest.sh` (no args) still exits 0 on a clean tree
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/../.." && pwd)"
INSTALL_SCRIPT="${SCRIPT_DIR}/../install-plugin.sh"
CHECK_MANIFEST="${SCRIPT_DIR}/../check-manifest.sh"

# shellcheck source=../lib/instruction-adapter.sh
source "${SCRIPT_DIR}/../lib/instruction-adapter.sh"

PASS=0; FAIL=0
ok()   { echo "  PASS: $*"; ((PASS++)) || true; }
bad()  { echo "  FAIL: $*"; ((FAIL++)) || true; }

assert_file() { [[ -f "$1" ]] && ok "$1 exists" || bad "Missing file: $1"; }

# assert_derived <adapter-path>: body must byte-match the AGENTS.md-derived rule.
assert_derived() {
  local path="$1"
  local expected
  expected="$(adapter_rule_body "${REPO_ROOT}/AGENTS.md")"
  if printf '%s' "$expected" | cmp -s - "$path"; then
    ok "$path is derived from canonical AGENTS.md"
  else
    bad "$path body does not match AGENTS.md-derived rule"
  fi
}

WS="$(mktemp -d)"
trap 'rm -rf "${WS}"' EXIT

# Target → host-correct adapter rule path + skills dir (bash 3.2: no assoc arrays).
rule_path_for() {
  case "$1" in
    copilot) echo ".github/copilot-instructions.md" ;;
    cline)   echo ".clinerules/uncle-dev.md" ;;
    kiro)    echo ".kiro/steering/uncle-dev.md" ;;
    pi)      echo ".pi/rules/uncle-dev.md" ;;
  esac
}
skills_dir_for() {
  case "$1" in
    copilot) echo ".github/skills" ;;
    cline)   echo ".clinerules/skills" ;;
    kiro)    echo ".kiro/steering/skills" ;;
    pi)      echo ".pi/rules/skills" ;;
  esac
}

echo "── R-8.1/R-8.2: each target emits a derived adapter + skill copies ──"
for target in copilot cline kiro pi; do
  dest="${WS}/${target}"
  bash "${INSTALL_SCRIPT}" --scope local --force "${target}" "${dest}" 2>&1 | sed 's/^/  /'

  rule="${dest}/$(rule_path_for "$target")"
  assert_file "${rule}"
  assert_derived "${rule}"

  # on-demand skill copies present (curated set)
  skdir="$(skills_dir_for "$target")"
  for skill in "${ADAPTER_ONDEMAND_SKILLS[@]}"; do
    assert_file "${dest}/${skdir}/${skill}/SKILL.md"
  done
done

echo ""
echo "── R-8.3: clean generated tree passes the adapter drift guard ──"
CLEAN="${WS}/copilot"
if bash "${CHECK_MANIFEST}" --adapters "${CLEAN}" >/dev/null 2>&1; then
  ok "drift guard accepts clean generated adapter tree"
else
  bad "drift guard rejected a clean generated adapter tree"
fi

echo ""
echo "── R-8.3: hand-editing a generated adapter is flagged ──"
HAND_EDIT="${CLEAN}/$(rule_path_for copilot)"
printf '\n<!-- sneaky hand edit -->\n' >> "${HAND_EDIT}"
if bash "${CHECK_MANIFEST}" --adapters "${CLEAN}" >/dev/null 2>&1; then
  bad "drift guard did NOT flag a hand-edited adapter"
else
  ok "drift guard flagged a hand-edited adapter (non-zero exit)"
fi

echo ""
echo "── default check-manifest.sh (no args) still exits 0 ──"
if bash "${CHECK_MANIFEST}" >/dev/null 2>&1; then
  ok "default check-manifest.sh exits 0 on clean checkout"
else
  bad "default check-manifest.sh did not exit 0"
fi

echo ""
echo "── Result ────────────────────────────────────────────────"
echo "  PASS: ${PASS}  FAIL: ${FAIL}"
[[ "$FAIL" -eq 0 ]] || exit 1
