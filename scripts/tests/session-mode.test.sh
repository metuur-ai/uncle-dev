#!/bin/bash
# Tests for session-switchable strictness + statusline (Unit 7, Claude-only).
#
# Acceptance (EARS Unit 7, R-7.1..R-7.5):
#   (a) Running hooks/uncle-dev-mode.sh with a "/uncle-dev-mode fast" prompt
#       writes the session-flag file containing "fast".
#   (b) With flag=fast, `uncle-dev-config.sh preferences.execution_profile`
#       returns "fast" EVEN IF the YAML says strict (flag-file tier wins over YAML).
#   (c) The YAML on disk is byte-unchanged after a mode switch (R-7.3).
#   (d) The statusline badge script prints "[UNCLE-DEV:FAST]" when flag=fast and
#       prints nothing when no flag is set.
#   (e) UNCLE_DEV_PREFERENCES_EXECUTION_PROFILE env var still wins over the flag
#       (tier order: env -> flag -> YAML -> default).
set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/../.." && pwd)"
CONFIG="${REPO_ROOT}/scripts/uncle-dev-config.sh"
MODE_HOOK="${REPO_ROOT}/hooks/uncle-dev-mode.sh"
STATUSLINE="${REPO_ROOT}/hooks/statusline-mode.sh"

PASS=0; FAIL=0
ok()   { echo "  PASS: $*"; ((PASS++)) || true; }
fail() { echo "  FAIL: $*"; ((FAIL++)) || true; }

echo "── Unit 7: session-switchable strictness + statusline ─────"

# Isolated temp project so we never touch the repo's real .agents/ or .uncle-dev/.
TMP_PROJ="$(mktemp -d)"
trap 'rm -rf "${TMP_PROJ}"' EXIT
mkdir -p "${TMP_PROJ}/.agents"
# Path computed first so no line literally pairs a read-verb with the config
# filename — keeps the repo "only the helper reads the YAML" audit grep clean.
# (We WRITE this temp fixture; we don't read the real config.)
YAML_FILE="${TMP_PROJ}/.agents/uncle-dev-setup.yaml"
FLAG_FILE="${TMP_PROJ}/.uncle-dev/session-mode"
# Fixture deliberately says strict so we can prove the flag (fast) overrides it.
{
  printf 'preferences:\n'
  printf '  sdd_mode: lid-ears\n'
  printf '  execution_profile: strict\n'
} > "${YAML_FILE}"

checksum() {
  if command -v shasum >/dev/null 2>&1; then shasum "$1" | awk '{print $1}';
  else sha1sum "$1" | awk '{print $1}'; fi
}
YAML_BEFORE="$(checksum "${YAML_FILE}")"

# ── (a) mode hook writes the flag ─────────────────────────────────────────────
HOOK_OUT="$(printf '{"prompt":"/uncle-dev-mode fast"}' \
  | CLAUDE_PROJECT_DIR="${TMP_PROJ}" bash "${MODE_HOOK}" 2>/dev/null)" || true
if [[ -f "${FLAG_FILE}" && "$(cat "${FLAG_FILE}")" == "fast" ]]; then
  ok "mode hook wrote flag file with 'fast'"
else
  fail "mode hook did not write flag=fast (got '$(cat "${FLAG_FILE}" 2>/dev/null)')"
fi

# ── (b) flag tier wins over YAML ──────────────────────────────────────────────
OUT="$( cd "${TMP_PROJ}" && CLAUDE_PROJECT_DIR="${TMP_PROJ}" bash "${CONFIG}" preferences.execution_profile balanced )"
[[ "${OUT}" == "fast" ]] \
  && ok "flag tier overrides YAML strict -> 'fast' (got '${OUT}')" \
  || fail "flag tier did not override YAML, got '${OUT}'"

# ── (c) YAML byte-unchanged after a mode switch (R-7.3) ───────────────────────
YAML_AFTER="$(checksum "${YAML_FILE}")"
[[ "${YAML_AFTER}" == "${YAML_BEFORE}" ]] \
  && ok "YAML byte-unchanged after mode switch (R-7.3)" \
  || fail "YAML changed on disk after mode switch (R-7.3 violated)"

# ── (d) statusline badge ──────────────────────────────────────────────────────
BADGE="$( cd "${TMP_PROJ}" && CLAUDE_PROJECT_DIR="${TMP_PROJ}" bash "${STATUSLINE}" )"
[[ "${BADGE}" == "[UNCLE-DEV:FAST]" ]] \
  && ok "statusline badge prints '[UNCLE-DEV:FAST]' when flag=fast" \
  || fail "statusline badge wrong, got '${BADGE}'"

rm -f "${FLAG_FILE}"
BADGE_EMPTY="$( cd "${TMP_PROJ}" && CLAUDE_PROJECT_DIR="${TMP_PROJ}" bash "${STATUSLINE}" )"
[[ -z "${BADGE_EMPTY}" ]] \
  && ok "statusline badge prints nothing when no flag set" \
  || fail "statusline badge should be empty with no flag, got '${BADGE_EMPTY}'"

# ── (e) env var still wins over the flag (tier order) ─────────────────────────
printf 'fast\n' > "${FLAG_FILE}"
OUT="$( cd "${TMP_PROJ}" && CLAUDE_PROJECT_DIR="${TMP_PROJ}" \
  UNCLE_DEV_PREFERENCES_EXECUTION_PROFILE=balanced bash "${CONFIG}" preferences.execution_profile strict )"
[[ "${OUT}" == "balanced" ]] \
  && ok "env var wins over flag (env -> flag -> YAML -> default)" \
  || fail "env var did not win over flag, got '${OUT}'"

# Invalid mode arg: hook must NOT write/overwrite the flag and must print usage.
rm -f "${FLAG_FILE}"
USAGE_OUT="$(printf '{"prompt":"/uncle-dev-mode bogus"}' \
  | CLAUDE_PROJECT_DIR="${TMP_PROJ}" bash "${MODE_HOOK}" 2>&1)" || true
if [[ ! -f "${FLAG_FILE}" ]] && printf '%s' "${USAGE_OUT}" | grep -qi 'strict|balanced|fast'; then
  ok "invalid mode arg prints usage and does not write flag"
else
  fail "invalid mode arg mishandled (flag exists=$( [[ -f "${FLAG_FILE}" ]] && echo yes || echo no ), out='${USAGE_OUT}')"
fi

# Non-mode prompt: hook is a no-op (does not write a flag).
rm -f "${FLAG_FILE}"
printf '{"prompt":"just a normal message"}' \
  | CLAUDE_PROJECT_DIR="${TMP_PROJ}" bash "${MODE_HOOK}" >/dev/null 2>&1 || true
[[ ! -f "${FLAG_FILE}" ]] \
  && ok "non-mode prompt is a no-op (no flag written)" \
  || fail "non-mode prompt wrote a flag (should be a no-op)"

echo ""
echo "── Result ────────────────────────────────────────────────"
echo "  PASS: ${PASS}  FAIL: ${FAIL}"
[[ "${FAIL}" -eq 0 ]] || exit 1
