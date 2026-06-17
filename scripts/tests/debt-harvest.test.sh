#!/bin/bash
# Tests for the @debt harvester (Unit 6, harvest-debt.py).
#
# Acceptance (EARS Unit 6, R-6.1..R-6.3):
#   1. A well-formed `@debt <ceiling>, <upgrade>` marker appears in the ledger
#      with all three fields: location (file:line), ceiling, and upgrade.
#   2. A malformed marker (missing the upgrade) is flagged as SILENT-ROT RISK.
#   3. The malformed marker is sorted ABOVE the well-formed one.
#   4. The grammar rejects the missing-field marker: harvester exits non-zero
#      when a rot-risk marker exists.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/../.." && pwd)"
HARVEST="${REPO_ROOT}/skills/uncle-dev-spec-annotations/harvest-debt.py"

PASS=0; FAIL=0
ok()   { echo "  PASS: $*"; ((PASS++)) || true; }
fail() { echo "  FAIL: $*"; ((FAIL++)) || true; }

echo "── Unit 6: @debt harvester ───────────────────────────────"

TMP="$(mktemp -d)"
cleanup() { rm -rf "${TMP}"; }
trap cleanup EXIT

# Seed a file with a well-formed marker and a malformed one (missing upgrade).
# The well-formed marker is placed on an EARLIER line / file that would sort
# BEFORE the malformed one alphabetically, to prove rot-risk wins ordering by
# risk, not by location.
cat > "${TMP}/a_conforming.ts" <<'EOF'
// @spec SOME-ID-001
export function ok() {
  // @debt < 10k sessions, swap the in-memory map for Redis
  return new Map();
}
EOF

cat > "${TMP}/z_malformed.py" <<'EOF'
def shortcut():
    # @debt single-region only
    pass
EOF

OUT="$(python3 "${HARVEST}" --root "${TMP}" 2>&1)" && RC=0 || RC=$?
echo "---- harvester output ----"
echo "${OUT}"
echo "--------------------------"

# ── Acceptance 4: non-zero exit when a rot-risk marker exists ─────────────────
[[ "${RC}" -ne 0 ]] \
  && ok "grammar rejects missing-field marker (exit ${RC} != 0)" \
  || fail "expected non-zero exit for missing-upgrade marker, got ${RC}"

# ── Acceptance 1: well-formed marker appears with all three fields ────────────
echo "${OUT}" | grep -q "a_conforming.ts:3" \
  && ok "well-formed marker location (file:line) present" \
  || fail "well-formed marker location missing from ledger"

echo "${OUT}" | grep -q "ceiling: < 10k sessions" \
  && ok "well-formed marker ceiling present" \
  || fail "well-formed marker ceiling missing"

echo "${OUT}" | grep -q "upgrade: swap the in-memory map for Redis" \
  && ok "well-formed marker upgrade present" \
  || fail "well-formed marker upgrade missing"

# ── Acceptance 2: malformed marker flagged as silent-rot risk ─────────────────
echo "${OUT}" | grep -q "SILENT-ROT RISK: z_malformed.py:2" \
  && ok "malformed marker flagged as silent-rot risk" \
  || fail "malformed marker not flagged as silent-rot risk"

# ── Acceptance 3: malformed sorted ABOVE conforming ───────────────────────────
ROT_LINE="$(echo "${OUT}" | grep -n "SILENT-ROT RISK: z_malformed.py" | head -1 | cut -d: -f1)"
OK_LINE="$(echo "${OUT}" | grep -n "a_conforming.ts:3" | head -1 | cut -d: -f1)"
if [[ -n "${ROT_LINE}" && -n "${OK_LINE}" && "${ROT_LINE}" -lt "${OK_LINE}" ]]; then
  ok "silent-rot risk sorted above well-formed (rot@${ROT_LINE} < ok@${OK_LINE})"
else
  fail "silent-rot risk NOT sorted above well-formed (rot@${ROT_LINE:-?} ok@${OK_LINE:-?})"
fi

# ── Sanity: a clean tree (well-formed only) exits zero ────────────────────────
CLEAN="$(mktemp -d)"
cat > "${CLEAN}/clean.go" <<'EOF'
// @debt < 1k rows, paginate via the cursor API
func load() {}
EOF
python3 "${HARVEST}" --root "${CLEAN}" >/dev/null 2>&1 && CRC=0 || CRC=$?
rm -rf "${CLEAN}"
[[ "${CRC}" -eq 0 ]] \
  && ok "well-formed-only tree exits zero" \
  || fail "well-formed-only tree expected exit 0, got ${CRC}"

echo ""
echo "── Result ────────────────────────────────────────────────"
echo "  PASS: ${PASS}  FAIL: ${FAIL}"
[[ "${FAIL}" -eq 0 ]] || exit 1
