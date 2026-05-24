#!/bin/bash
# Run all install test scripts and report aggregate pass/fail.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

TESTS=(
  "${SCRIPT_DIR}/install-claude.test.sh"
  "${SCRIPT_DIR}/install-codex.test.sh"
  "${SCRIPT_DIR}/install-opencode.test.sh"
)

TOTAL_PASS=0
TOTAL_FAIL=0

for test_script in "${TESTS[@]}"; do
  name="$(basename "$test_script")"
  echo ""
  echo "══ ${name} ══════════════════════════════════════════════"
  if bash "$test_script"; then
    echo "  [OK] ${name}"
  else
    echo "  [FAIL] ${name}"
    ((TOTAL_FAIL++)) || true
  fi
done

echo ""
echo "══ All tests complete ════════════════════════════════════"
if [[ "$TOTAL_FAIL" -eq 0 ]]; then
  echo "  All test suites passed."
  exit 0
else
  echo "  ${TOTAL_FAIL} test suite(s) failed."
  exit 1
fi
