#!/bin/bash
# Tests for the Unit 9 benchmark harness (benchmarks/).
#
# Runs fully OFFLINE — no ANTHROPIC_API_KEY, no live promptfoo eval.
#
# Acceptance (EARS Unit 9, R-9.1..R-9.3):
#   1. promptfooconfig.yaml is well-formed (parses as YAML).
#   2. The pinned model id is present in the config.
#   3. The pinned promptfoo version is present in package.json.
#   4. Two arms are defined: no-skill and uncle-dev.
#   5. All three task categories exist (spec-first feature, refactor, review).
#   6. The review-task grader catches the planted bug: it FAILS the buggy
#      fixture and PASSES the good fixture (validated without the API).
#   7. The report formatter produces the stable expected table from the
#      checked-in sample promptfoo JSON output.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/../.." && pwd)"
BENCH="${REPO_ROOT}/benchmarks"

PASS=0; FAIL=0
ok()   { echo "  PASS: $*"; ((PASS++)) || true; }
fail() { echo "  FAIL: $*"; ((FAIL++)) || true; }

echo "── Unit 9: benchmark harness ─────────────────────────────"

CONFIG="${BENCH}/promptfooconfig.yaml"
PKG="${BENCH}/package.json"
PINNED_MODEL="claude-sonnet-4-6"
PINNED_PFVER="0.121.17"

# ── Acceptance 1: config is well-formed YAML ──────────────────────────────────
if python3 - "${CONFIG}" <<'PY' 2>/dev/null
import sys
try:
    import yaml
except ImportError:
    # No pyyaml: fall back to asserting the file is non-empty and has the keys.
    txt = open(sys.argv[1]).read()
    assert "prompts:" in txt and "providers:" in txt and "tests:" in txt
    sys.exit(0)
with open(sys.argv[1]) as fh:
    data = yaml.safe_load(fh)
assert isinstance(data, dict), "config is not a mapping"
for k in ("prompts", "providers", "tests"):
    assert k in data, f"missing key: {k}"
sys.exit(0)
PY
then
  ok "promptfooconfig.yaml is well-formed (prompts/providers/tests present)"
else
  fail "promptfooconfig.yaml failed to parse / missing required keys"
fi

# ── Acceptance 2: pinned model present ────────────────────────────────────────
grep -q "${PINNED_MODEL}" "${CONFIG}" \
  && ok "pinned model ${PINNED_MODEL} present in config" \
  || fail "pinned model ${PINNED_MODEL} missing from config"

# ── Acceptance 3: pinned promptfoo version present ────────────────────────────
grep -q "\"${PINNED_PFVER}\"" "${PKG}" \
  && ok "pinned promptfoo version ${PINNED_PFVER} present in package.json" \
  || fail "pinned promptfoo version ${PINNED_PFVER} missing from package.json"

# ── Acceptance 4: two arms defined ────────────────────────────────────────────
grep -q "label: no-skill" "${CONFIG}" \
  && ok "arm 'no-skill' defined" \
  || fail "arm 'no-skill' missing"
grep -q "label: uncle-dev" "${CONFIG}" \
  && ok "arm 'uncle-dev' defined" \
  || fail "arm 'uncle-dev' missing"

# ── Acceptance 5: three task categories present ───────────────────────────────
for task in spec-first-feature refactor review-catch-rate; do
  grep -q "description: ${task}" "${CONFIG}" \
    && ok "task category '${task}' present in config" \
    || fail "task category '${task}' missing from config"
done

# ── Acceptance 6: grader catches the planted bug (offline) ────────────────────
GRADER="${BENCH}/grader.py"
BUGGY="${BENCH}/fixtures/review-answer-buggy.txt"
GOOD="${BENCH}/fixtures/review-answer-good.txt"

if python3 "${GRADER}" "${BUGGY}" >/dev/null 2>&1; then
  fail "grader PASSED the buggy fixture (should fail — bug not caught)"
else
  ok "grader fails the buggy fixture (planted defects not flagged)"
fi

if python3 "${GRADER}" "${GOOD}" >/dev/null 2>&1; then
  ok "grader passes the good fixture (both planted defects flagged)"
else
  fail "grader FAILED the good fixture (should pass — both defects named)"
fi

# Sanity: the planted defects are actually present in the reviewed snippet, so
# the fixtures are auditable, not theatre.
SNIPPET="${BENCH}/fixtures/review-snippet.js"
grep -q "i <= items.length" "${SNIPPET}" \
  && ok "planted off-by-one bug present in review snippet" \
  || fail "planted off-by-one bug NOT present in review snippet"
grep -q "@spec CART-TOTAL-999" "${SNIPPET}" \
  && ok "planted orphaned @spec present in review snippet" \
  || fail "planted orphaned @spec NOT present in review snippet"
# And the orphan id is genuinely absent from the known-good ids.
grep -q "CART-TOTAL-999" "${BENCH}/fixtures/known-spec-ids.txt" \
  && fail "orphan id CART-TOTAL-999 is in known-spec-ids (not an orphan)" \
  || ok "orphan id CART-TOTAL-999 absent from known-spec-ids (genuine orphan)"

# ── Acceptance 7: report formatter produces the stable expected table ─────────
SAMPLE="${BENCH}/samples/sample-eval-output.json"
EXPECTED="${BENCH}/samples/expected-table.md"
if diff <(python3 "${BENCH}/report.py" "${SAMPLE}") "${EXPECTED}" >/dev/null 2>&1; then
  ok "report.py output matches expected-table.md exactly"
else
  fail "report.py output diverges from expected-table.md"
  diff <(python3 "${BENCH}/report.py" "${SAMPLE}") "${EXPECTED}" || true
fi

# Determinism: two runs over the same input are byte-identical.
RUN_A="$(python3 "${BENCH}/report.py" "${SAMPLE}")"
RUN_B="$(python3 "${BENCH}/report.py" "${SAMPLE}")"
[[ "${RUN_A}" == "${RUN_B}" ]] \
  && ok "report.py is deterministic across runs" \
  || fail "report.py output differs between runs"

echo ""
echo "── Result ────────────────────────────────────────────────"
echo "  PASS: ${PASS}  FAIL: ${FAIL}"
[[ "${FAIL}" -eq 0 ]] || exit 1
