#!/bin/bash
# Tests for the env-var override tier in scripts/uncle-dev-config.sh (Unit 2).
#
# Acceptance (EARS Unit 2, R-2.1..R-2.4):
#   1. UNCLE_DEV_PREFERENCES_SDD_MODE=openspec overrides the YAML value, and the
#      YAML on disk stays byte-unchanged.
#   2. The env key is DERIVED (uppercase, dots->underscores). A non-derived name
#      must NOT override.
#   3. With no env var set, behavior is unchanged (YAML value, then caller default).
#   4. The helper is the only reader of the YAML (audit grep).
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/../.." && pwd)"
CONFIG="${REPO_ROOT}/scripts/uncle-dev-config.sh"
YAML="${REPO_ROOT}/.agents/uncle-dev-setup.yaml"

PASS=0; FAIL=0
ok()   { echo "  PASS: $*"; ((PASS++)) || true; }
fail() { echo "  FAIL: $*"; ((FAIL++)) || true; }

# All config invocations run from the repo root (callers use a relative
# CONFIG_FILE). Run from REPO_ROOT so the relative .agents/ path resolves.
run_cfg() {
  # usage: run_cfg "ENV1=v1 ENV2=v2" arg1 [arg2...]
  local envs="$1"; shift
  ( cd "${REPO_ROOT}" && env ${envs} bash "${CONFIG}" "$@" )
}

echo "── Unit 2: env-var config override tier ──────────────────"

# Baseline YAML checksum (portable: shasum on macOS, sha1sum on Linux).
checksum() {
  if command -v shasum >/dev/null 2>&1; then shasum "$1" | awk '{print $1}';
  else sha1sum "$1" | awk '{print $1}'; fi
}
YAML_BEFORE="$(checksum "${YAML}")"

# Capture the on-disk YAML value of sdd_mode (with no env override) so we can
# prove the override differs from it.
YAML_VALUE="$(run_cfg "" preferences.sdd_mode)"

# ── Acceptance 1: env override wins, YAML untouched ───────────────────────────
OUT="$(run_cfg "UNCLE_DEV_PREFERENCES_SDD_MODE=openspec" preferences.sdd_mode)"
[[ "${OUT}" == "openspec" ]] \
  && ok "env override returns 'openspec' (got '${OUT}')" \
  || fail "env override expected 'openspec', got '${OUT}'"

YAML_AFTER="$(checksum "${YAML}")"
[[ "${YAML_AFTER}" == "${YAML_BEFORE}" ]] \
  && ok "YAML byte-unchanged after env-overridden read" \
  || fail "YAML changed on disk after env-overridden read"

# Sanity: the override actually differs from the on-disk value (otherwise the
# test would pass trivially even with no override implemented).
[[ "${YAML_VALUE}" != "openspec" ]] \
  && ok "on-disk sdd_mode ('${YAML_VALUE}') differs from override target" \
  || fail "test precondition broken: on-disk sdd_mode already 'openspec'"

# ── Acceptance 2: only the DERIVED key name overrides ─────────────────────────
# A plausible-but-wrong env name must NOT override.
OUT="$(run_cfg "UNCLE_DEV_SDD_MODE=openspec" preferences.sdd_mode)"
[[ "${OUT}" == "${YAML_VALUE}" ]] \
  && ok "non-derived env name does NOT override (got '${OUT}')" \
  || fail "non-derived env name leaked through, got '${OUT}'"

# Derivation correctness: dotted path -> UPPER + dots->underscores.
OUT="$(run_cfg "UNCLE_DEV_PREFERENCES_EXECUTION_PROFILE=strict" preferences.execution_profile balanced)"
[[ "${OUT}" == "strict" ]] \
  && ok "derived key for preferences.execution_profile resolves" \
  || fail "derived key for execution_profile failed, got '${OUT}'"

# ── Acceptance 3: no env -> unchanged behavior ────────────────────────────────
OUT="$(run_cfg "" preferences.sdd_mode)"
[[ "${OUT}" == "${YAML_VALUE}" ]] \
  && ok "no env: returns YAML value '${OUT}'" \
  || fail "no env: expected YAML value '${YAML_VALUE}', got '${OUT}'"

# Missing key with no env -> caller default.
OUT="$(run_cfg "" preferences.does_not_exist_xyz myfallback)"
[[ "${OUT}" == "myfallback" ]] \
  && ok "no env, missing key: returns caller default" \
  || fail "no env, missing key: expected 'myfallback', got '${OUT}'"

# Empty env var must NOT override (treated as unset for resolution).
OUT="$(run_cfg "UNCLE_DEV_PREFERENCES_SDD_MODE=" preferences.sdd_mode)"
[[ "${OUT}" == "${YAML_VALUE}" ]] \
  && ok "empty env var does not override (falls through to YAML)" \
  || fail "empty env var overrode YAML, got '${OUT}'"

# ── Acceptance 4: helper is the only YAML reader ──────────────────────────────
HITS="$( ( cd "${REPO_ROOT}" && grep -rn 'open.*setup\.yaml\|cat.*setup\.yaml\|yq.*setup\.yaml' scripts/ .claude/ hooks/ 2>/dev/null ) || true )"
# Only the helper may READ the YAML. Drop blank lines, the helper itself, and
# prose-comment false positives (e.g. a loader's contract note that merely names
# the config file is not a reader). A comment match has '#' before the pattern.
NONHELPER="$(
  printf '%s\n' "${HITS}" \
    | grep -v '^$' \
    | grep -v 'scripts/uncle-dev-config.sh' \
    | grep -Ev ':[0-9]+:[[:space:]]*#' \
    || true
)"
[[ -z "${NONHELPER}" ]] \
  && ok "audit grep: only the helper reads the YAML" \
  || fail "audit grep found other YAML readers:"$'\n'"${NONHELPER}"

echo ""
echo "── Result ────────────────────────────────────────────────"
echo "  PASS: ${PASS}  FAIL: ${FAIL}"
[[ "${FAIL}" -eq 0 ]] || exit 1
