#!/bin/bash
# Tests for scripts/uncle-dev-load-skill.sh (Audit Unit 04).
#
# Acceptance (EARS Unit 4):
#   R-4.1  Unknown skill name → stderr error + non-zero exit.
#   R-4.2  Known skill name  → stdout "SKILL: uncle-dev:<name>" + exit 0.
#   R-4.3  Zero occurrences of "agent-skills:" in commands/, skills/, scripts/.
#   R-4.4  commands/uncle-dev-code-simplify.md passes uncle-dev-dev-code-simplification.
#   R-4.5  (a) exit 0 + SKILL: uncle-dev:<name> for known; (b) non-zero + stderr for bogus.
#   R-4.6  Every "bash "$_loader" <name>" arg in commands/ has a matching skills/<name>/ dir.
#   R-4.7  Sort-V fallback (structural; grep-based check since we can't install two cache copies).
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/../.." && pwd)"
LOADER="${REPO_ROOT}/scripts/uncle-dev-load-skill.sh"
SKILLS_DIR="${REPO_ROOT}/skills"

PASS=0; FAIL=0
ok()   { echo "  PASS: $*"; ((PASS++)) || true; }
fail() { echo "  FAIL: $*"; ((FAIL++)) || true; }

echo "── Unit 04: skill loader validation + namespace ──────────"

# ── R-4.2 / R-4.5(a): known-good skill → exit 0 + "SKILL: uncle-dev:<name>" ──
KNOWN="uncle-dev-test-driven-development"
STDOUT_OK="$(bash "${LOADER}" "${KNOWN}" 2>/dev/null)" && EXIT_CODE=0 || EXIT_CODE=$?
if [[ "${EXIT_CODE}" -eq 0 ]]; then
  ok "known skill exits 0"
else
  fail "known skill '${KNOWN}' exited ${EXIT_CODE} (expected 0)"
fi

if echo "${STDOUT_OK}" | grep -qF "SKILL: uncle-dev:${KNOWN}"; then
  ok "known skill emits 'SKILL: uncle-dev:${KNOWN}'"
else
  fail "known skill stdout did not contain 'SKILL: uncle-dev:${KNOWN}'; got: ${STDOUT_OK}"
fi

# ── R-4.1 / R-4.5(b): bogus name → non-zero exit + stderr ──────────────────
BOGUS="not-a-real-skill-xyzzy"
STDERR_BOGUS="$(bash "${LOADER}" "${BOGUS}" 2>&1 1>/dev/null)" && EXIT_BOGUS=0 || EXIT_BOGUS=$?
if [[ "${EXIT_BOGUS}" -ne 0 ]]; then
  ok "bogus skill exits non-zero (${EXIT_BOGUS})"
else
  fail "bogus skill '${BOGUS}' exited 0 (expected non-zero)"
fi

if echo "${STDERR_BOGUS}" | grep -qiE "error|unknown"; then
  ok "bogus skill emits error on stderr"
else
  fail "bogus skill stderr did not contain 'error'/'unknown'; got: ${STDERR_BOGUS}"
fi

# ── R-4.3: zero "agent-skills:" occurrences in commands/, skills/, scripts/ ──
# Exclude this test file itself (it references the pattern in comments/grep strings).
AGENT_SKILLS_HITS="$(grep -rn 'agent-skills:' \
  "${REPO_ROOT}/commands/" \
  "${REPO_ROOT}/skills/" \
  "${REPO_ROOT}/scripts/" 2>/dev/null \
  | grep -v "$(basename "${BASH_SOURCE[0]}")" || true)"

if [[ -z "${AGENT_SKILLS_HITS}" ]]; then
  ok "zero 'agent-skills:' occurrences in commands/, skills/, scripts/ (excl. this test)"
else
  fail "found 'agent-skills:' namespace references (must be zero):"
  echo "${AGENT_SKILLS_HITS}" | head -20
fi

# ── R-4.4: code-simplify command passes the correct (non-typo) skill name ────
SIMPLIFY_CMD="${REPO_ROOT}/commands/uncle-dev-code-simplify.md"
if grep -qF 'uncle-dev-dev-code-simplification' "${SIMPLIFY_CMD}"; then
  ok "uncle-dev-code-simplify.md passes 'uncle-dev-dev-code-simplification'"
else
  fail "uncle-dev-code-simplify.md does not contain 'uncle-dev-dev-code-simplification'"
fi
if grep -qF 'uncle-dev-code-simplification' "${SIMPLIFY_CMD}" && \
   ! grep -qF 'uncle-dev-dev-code-simplification' "${SIMPLIFY_CMD}"; then
  fail "uncle-dev-code-simplify.md still uses old typo 'uncle-dev-code-simplification'"
fi

# ── R-4.6: every loader arg in commands/ has a matching skills/<name>/ dir ───
MISSING_SKILLS=()
while IFS= read -r skill_name; do
  if [[ ! -d "${SKILLS_DIR}/${skill_name}" ]]; then
    MISSING_SKILLS+=("${skill_name}")
  fi
done < <(grep -rhoE 'bash "\$_loader" ([a-z-]+)' "${REPO_ROOT}/commands/" \
           | awk '{print $NF}' | sort -u)

if [[ ${#MISSING_SKILLS[@]} -eq 0 ]]; then
  ok "all loader arguments in commands/ have matching skills/<name>/ directories"
else
  fail "loader args with no matching skill directory: ${MISSING_SKILLS[*]}"
fi

# ── R-4.7: loader uses sort -V | tail -1, not find | head -1 (structural) ───
if grep -qF 'sort -V | tail -1' "${LOADER}" || grep -qF 'sort -V | tail -1' "${LOADER}"; then
  ok "loader uses sort -V | tail -1 for cache resolution"
else
  fail "loader does not use 'sort -V | tail -1' for cache version resolution"
fi
# Must not contain the old nondeterministic form for cache lookup
if grep -qE "find.*plugins.*head -1" "${LOADER}"; then
  fail "loader still contains 'find ... | head -1' for cache resolution"
else
  ok "loader does not use 'find ... | head -1' for cache resolution"
fi

# ── Summary ──────────────────────────────────────────────────────────────────
echo ""
echo "── Unit 04 results: ${PASS} passed, ${FAIL} failed ──────────"
if [[ "${FAIL}" -gt 0 ]]; then
  exit 1
fi
exit 0
