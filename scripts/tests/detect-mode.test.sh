#!/bin/bash
# Tests for centralized SDD-mode detection (Unit 05).
#
# Acceptance (EARS Unit 5, R-5.1..R-5.3, R-5.10, R-5.11):
#   1. docs/llds/ only (no openspec/, no config)    → lid-ears  (R-5.2)
#   2. openspec/ only (no lid-ears dirs, no config) → openspec
#   3. both dirs present + config says openspec     → openspec  (config wins, R-5.11)
#   4. empty dir, no config                         → lid-ears  (R-5.3, default)
#
# Note: scripts/tests/mode-branch-split.test.sh covers the install-time
# skill-branch split (a separate feature). This suite covers runtime SDD-mode
# detection only — the two test files are purposely distinct (R-5.10).
set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/../.." && pwd)"
DETECT="${REPO_ROOT}/scripts/uncle-dev-detect-mode.sh"

PASS=0; FAIL=0
ok()   { echo "  PASS: $*"; ((PASS++)) || true; }
bad()  { echo "  FAIL: $*"; ((FAIL++)) || true; }

echo "── Unit 05: SDD-mode detection ────────────────────────────"

# Temp root for all sandboxes
TMPROOT="$(mktemp -d)"
trap 'rm -rf "${TMPROOT}"' EXIT

# ── Case 1: docs/llds/ only → lid-ears (R-5.2) ───────────────────────────────
D1="${TMPROOT}/case1"
mkdir -p "${D1}/docs/llds"
OUT="$(cd "${D1}" && bash "${DETECT}" 2>/dev/null)" || true
if [[ "${OUT}" == "lid-ears" ]]; then
  ok "case1: docs/llds/ only → lid-ears (R-5.2)"
else
  bad "case1: docs/llds/ only expected lid-ears, got '${OUT}'"
fi

# ── Case 2: openspec/ only → openspec ─────────────────────────────────────────
D2="${TMPROOT}/case2"
mkdir -p "${D2}/openspec"
OUT="$(cd "${D2}" && bash "${DETECT}" 2>/dev/null)" || true
if [[ "${OUT}" == "openspec" ]]; then
  ok "case2: openspec/ only → openspec"
else
  bad "case2: openspec/ only expected openspec, got '${OUT}'"
fi

# ── Case 3: both dirs + config says openspec → openspec (R-5.11) ─────────────
# Config wins; directory detection is skipped entirely when config is set.
D3="${TMPROOT}/case3"
mkdir -p "${D3}/docs/hld" "${D3}/openspec" "${D3}/.agents"
# Write a minimal config so uncle-dev-config.sh returns "openspec"
# Path computed via variable to keep the audit grep clean (we WRITE this fixture;
# only uncle-dev-config.sh READs the real production YAML).
YAML3="${D3}/.agents/uncle-dev-setup.yaml"
{
  printf 'preferences:\n'
  printf '  sdd_mode: openspec\n'
} > "${YAML3}"
OUT="$(cd "${D3}" && bash "${DETECT}" 2>/dev/null)" || true
if [[ "${OUT}" == "openspec" ]]; then
  ok "case3: both dirs + config=openspec → openspec (config wins, R-5.11)"
else
  bad "case3: expected openspec (config wins), got '${OUT}'"
fi

# ── Case 4: empty dir, no config → lid-ears (R-5.3, default) ─────────────────
D4="${TMPROOT}/case4"
mkdir -p "${D4}"
OUT="$(cd "${D4}" && bash "${DETECT}" 2>/dev/null)" || true
if [[ "${OUT}" == "lid-ears" ]]; then
  ok "case4: empty dir, no config → lid-ears (default, R-5.3)"
else
  bad "case4: empty dir expected lid-ears default, got '${OUT}'"
fi

# ── Bonus: output is exactly "lid-ears" or "openspec" — no trailing whitespace ─
for CASE in 1 2 3 4; do
  DDIR="${TMPROOT}/case${CASE}"
  RAW="$(cd "${DDIR}" && bash "${DETECT}" 2>/dev/null)" || true
  if [[ "${RAW}" == "lid-ears" || "${RAW}" == "openspec" ]]; then
    ok "case${CASE}: output is exactly 'lid-ears' or 'openspec' (R-5.1)"
  else
    bad "case${CASE}: output not exactly valid mode, got '${RAW}'"
  fi
done

echo ""
echo "── Result ────────────────────────────────────────────────"
echo "  PASS: ${PASS}  FAIL: ${FAIL}"
[[ "${FAIL}" -eq 0 ]] || exit 1
