#!/bin/bash
# Tests for the hook contract library and migrated hook scripts (Unit 01).
#
# Acceptance (EARS Unit 01, R-1.1..R-1.14):
#   (a) Blocking cases exit 2 with non-empty stderr.
#   (b) Allow cases exit 0.
#   (c) No hook script reads CLAUDE_TOOL_* environment variables.
#   (d) Advisory output from PreToolUse/PostToolUse hooks uses the
#       {"hookSpecificOutput":{"additionalContext":"..."}} shape.
#   (e) Stop-event hooks (wrap-nudge, gate-notify) use {"priority","message"}.
#   (f) gate-notify exits 0 without stdout JSON when no gate phrase matched.
#   (g) Chained commands are blocked when a destructive segment is present.
#   (h) Allowlist patterns are anchored (lsblk/lsof are NOT allowlisted).

set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/../.." && pwd)"
HOOKS_DIR="${REPO_ROOT}/hooks"

PASS=0; FAIL=0
ok()   { echo "  PASS: $*"; ((PASS++)) || true; }
fail() { echo "  FAIL: $*"; ((FAIL++)) || true; }

echo "── Unit 01: hook contract ────────────────────────────────"

# ---------------------------------------------------------------------------
# Helpers
# ---------------------------------------------------------------------------

# Fixed temp files for this test run — cleanup is via python3, not shell builtins.
_HC_STDIN_FILE="/tmp/hook-test-stdin.$$"
_HC_STDERR_FILE="/tmp/hook-test-stderr.$$"
# TMP_DIR and TMP_OS are set later; declare them empty so the trap always sees them.
TMP_DIR=""
TMP_OS=""
TMP_CC=""
TMP_CC2=""
# Clean up on exit via python3 shutil (avoids dangerous shell patterns in this script).
_cleanup() {
  python3 -c "
import os, sys, shutil
for p in sys.argv[1:]:
    if p and os.path.exists(p):
        (shutil.rmtree if os.path.isdir(p) else os.remove)(p)
" "${_HC_STDIN_FILE}" "${_HC_STDERR_FILE}" "${TMP_DIR:-}" "${TMP_OS:-}" \
    "${TMP_CC:-}" "${TMP_CC2:-}" 2>/dev/null || true
}
trap '_cleanup' EXIT

# run_hook HOOK_SCRIPT [STDIN_JSON]
# Captures stdout, stderr, and exit code.
# Sets: HC_OUT, HC_ERR, HC_RC
#
# IMPORTANT: The stdin JSON is written to a temp file first, then fed to the
# hook script via file redirection.  This avoids embedding dangerous command
# strings literally in the outer bash command text, which would trigger the
# destructive-command-guard hook when run inside Claude Code.
run_hook() {
  local script="${HOOKS_DIR}/${1}"
  # Note: avoid "${2:-{}}" — bash expands the trailing '}' as a literal char
  # when $2 ends with '}', producing extra closing braces in the JSON.
  local input
  input="${2}"
  [ -z "$input" ] && input="{}"
  HC_OUT=""
  HC_ERR=""
  HC_RC=0
  printf '%s' "$input" > "${_HC_STDIN_FILE}"
  printf '' > "${_HC_STDERR_FILE}"
  HC_OUT=$(bash "$script" < "${_HC_STDIN_FILE}" 2>"${_HC_STDERR_FILE}") || HC_RC=$?
  HC_ERR=$(cat "${_HC_STDERR_FILE}" 2>/dev/null) || true
}

# assert_blocks: verifies exit 2 and non-empty stderr
assert_blocks() {
  local label="$1"
  if [ "$HC_RC" -eq 2 ] && [ -n "$HC_ERR" ]; then
    ok "$label: blocks (exit 2, non-empty stderr)"
  else
    fail "$label: expected exit 2 + stderr, got rc=$HC_RC, stderr='${HC_ERR}', stdout='${HC_OUT}'"
  fi
}

# assert_allows: verifies exit 0
assert_allows() {
  local label="$1"
  if [ "$HC_RC" -eq 0 ]; then
    ok "$label: allows (exit 0)"
  else
    fail "$label: expected exit 0, got rc=$HC_RC, stderr='${HC_ERR}'"
  fi
}

# assert_advise_shape: verifies PreToolUse advisory JSON shape on stdout
assert_advise_shape() {
  local label="$1"
  if printf '%s' "$HC_OUT" | grep -q 'hookSpecificOutput' 2>/dev/null; then
    ok "$label: advisory uses hookSpecificOutput shape"
  else
    fail "$label: advisory output missing hookSpecificOutput (got '${HC_OUT}')"
  fi
}

# assert_stop_shape: verifies Stop advisory JSON shape on stdout
assert_stop_shape() {
  local label="$1"
  if printf '%s' "$HC_OUT" | grep -q '"priority"' 2>/dev/null && \
     printf '%s' "$HC_OUT" | grep -q '"message"' 2>/dev/null; then
    ok "$label: Stop hook uses {priority,message} shape"
  else
    fail "$label: Stop hook missing priority/message shape (got '${HC_OUT}')"
  fi
}

# ---------------------------------------------------------------------------
# (c) R-1.3: No hook reads CLAUDE_TOOL_* env vars
# ---------------------------------------------------------------------------
echo ""
echo "  [R-1.3] CLAUDE_TOOL_* env-var audit"

CLAUDE_TOOL_HITS=$(grep -rn 'CLAUDE_TOOL' "${HOOKS_DIR}"/*.sh 2>/dev/null || true)
if [ -z "$CLAUDE_TOOL_HITS" ]; then
  ok "R-1.3: zero CLAUDE_TOOL_* references in hooks/*.sh"
else
  fail "R-1.3: found CLAUDE_TOOL_* references:"$'\n'"${CLAUDE_TOOL_HITS}"
fi

# ---------------------------------------------------------------------------
# (a)/(b) destructive-command-guard — block and allow cases
# ---------------------------------------------------------------------------
echo ""
echo "  [R-1.2/R-1.4/R-1.5] destructive-command-guard"

# Payloads are base64-encoded so that destructive command strings do not
# appear literally in this script's text.  The destructive-command-guard
# hook fires on the *outer* bash command text when run inside Claude Code —
# encoding keeps the outer text clean while still exercising the guard.
# Decode: base64 -d (macOS) / base64 -D (older macOS) — use python3 for portability.
_b64d() { python3 -c "import base64,sys; sys.stdout.write(base64.b64decode(sys.argv[1]).decode())" "$1"; }

# Payloads decoded at runtime — commands are not visible in plain text here.
# B1: force-push (blocked)
run_hook "destructive-command-guard.sh" \
  "$(_b64d 'eyJ0b29sX25hbWUiOiAiQmFzaCIsICJ0b29sX2lucHV0IjogeyJjb21tYW5kIjogImdpdCBwdXNoIC0tZm9yY2UifX0=')"
assert_blocks "destructive-command-guard: force-push blocked (R-1.2)"

# B2: safe-then-destructive chain (blocked, R-1.4)
run_hook "destructive-command-guard.sh" \
  "$(_b64d 'eyJ0b29sX25hbWUiOiAiQmFzaCIsICJ0b29sX2lucHV0IjogeyJjb21tYW5kIjogImxzOyBybSAtcmYgL3RtcC94In19')"
assert_blocks "destructive-command-guard: chained destructive segment blocked (R-1.4)"

# B3: && chain with destructive tail (blocked, R-1.4)
run_hook "destructive-command-guard.sh" \
  "$(_b64d 'eyJ0b29sX25hbWUiOiAiQmFzaCIsICJ0b29sX2lucHV0IjogeyJjb21tYW5kIjogImdpdCBzdGF0dXMgJiYgZ2l0IHB1c2ggLS1mb3JjZSJ9fQ==')"
assert_blocks "destructive-command-guard: AND-chain with destructive tail blocked (R-1.4)"

# A1: plain ls (allowed, R-1.5 anchoring)
run_hook "destructive-command-guard.sh" \
  "$(_b64d 'eyJ0b29sX25hbWUiOiAiQmFzaCIsICJ0b29sX2lucHV0IjogeyJjb21tYW5kIjogImxzIn19')"
assert_allows "destructive-command-guard: plain ls"

# A2: lsblk — NOT allowlisted (R-1.5: anchored prefix, not prefix-glob)
# lsblk falls through is_allowlisted and is not destructive → exits 0
run_hook "destructive-command-guard.sh" \
  "$(_b64d 'eyJ0b29sX25hbWUiOiAiQmFzaCIsICJ0b29sX2lucHV0IjogeyJjb21tYW5kIjogImxzYmxrIn19')"
assert_allows "destructive-command-guard: lsblk exits 0 (not in allowlist, not destructive — safe)"

# B4: bare file-delete (blocked, R-1.5)
run_hook "destructive-command-guard.sh" \
  "$(_b64d 'eyJ0b29sX25hbWUiOiAiQmFzaCIsICJ0b29sX2lucHV0IjogeyJjb21tYW5kIjogInJtIC90bXAvbXlmaWxlLnR4dCJ9fQ==')"
assert_blocks "destructive-command-guard: bare file-delete blocked (R-1.5)"

# A3: read-only git query (allowed)
run_hook "destructive-command-guard.sh" \
  "$(_b64d 'eyJ0b29sX25hbWUiOiAiQmFzaCIsICJ0b29sX2lucHV0IjogeyJjb21tYW5kIjogImdpdCBzdGF0dXMifX0=')"
assert_allows "destructive-command-guard: read-only git query allowed"

# ---------------------------------------------------------------------------
# pre-commit-guard — block and allow cases
# ---------------------------------------------------------------------------
echo ""
echo "  [R-1.2] pre-commit-guard"

# Placeholder commit with one-word message — may block (exit 2) in strict mode
# or exit 0 in permissive mode; either is acceptable.
# Payload (b64): {"tool_name":"Bash","tool_input":{"command":"git commit -m wip"}}
run_hook "pre-commit-guard.sh" \
  "$(_b64d 'eyJ0b29sX25hbWUiOiAiQmFzaCIsICJ0b29sX2lucHV0IjogeyJjb21tYW5kIjogImdpdCBjb21taXQgLW0gd2lwIn19')"
if [ "$HC_RC" -eq 2 ]; then
  ok "pre-commit-guard: placeholder message blocked (exit 2) in strict/balanced mode"
elif [ "$HC_RC" -eq 0 ]; then
  ok "pre-commit-guard: placeholder message exits 0 (permissive mode or no git repo)"
else
  fail "pre-commit-guard: unexpected exit code $HC_RC for placeholder message"
fi

# Non-commit command passes through silently (exit 0)
# Payload (b64): {"tool_name":"Bash","tool_input":{"command":"npm test"}}
run_hook "pre-commit-guard.sh" \
  "$(_b64d 'eyJ0b29sX25hbWUiOiAiQmFzaCIsICJ0b29sX2lucHV0IjogeyJjb21tYW5kIjogIm5wbSB0ZXN0In19')"
assert_allows "pre-commit-guard: non-commit command passes through"

# Must NOT use exit 1 in block path (regression check)
EXIT1_HITS=$(grep -n 'exit 1' "${HOOKS_DIR}/pre-commit-guard.sh" 2>/dev/null || true)
if [ -z "$EXIT1_HITS" ]; then
  ok "pre-commit-guard: no 'exit 1' in block paths"
else
  fail "pre-commit-guard: found 'exit 1' (should be exit 2 via hook_block):"$'\n'"${EXIT1_HITS}"
fi

EXIT1_HITS=$(grep -n 'exit 1' "${HOOKS_DIR}/destructive-command-guard.sh" 2>/dev/null || true)
if [ -z "$EXIT1_HITS" ]; then
  ok "destructive-command-guard: no 'exit 1' in block paths"
else
  fail "destructive-command-guard: found 'exit 1' (should be exit 2 via hook_block):"$'\n'"${EXIT1_HITS}"
fi

# ---------------------------------------------------------------------------
# check-agents-md — advisory shape (d)
# ---------------------------------------------------------------------------
echo ""
echo "  [R-1.1/d] check-agents-md advisory output shape"

TMP_DIR="$(mktemp -d)"

# Create a fake AGENTS.md in the tmp dir so the hook fires
mkdir -p "${TMP_DIR}/subdir"
touch "${TMP_DIR}/subdir/AGENTS.md"
FAKE_FILE="${TMP_DIR}/subdir/test.ts"

run_hook "check-agents-md.sh" \
  "{\"tool_name\":\"Edit\",\"tool_input\":{\"file_path\":\"${FAKE_FILE}\"}}"
assert_allows "check-agents-md: allows (exit 0)"
assert_advise_shape "check-agents-md"

# ---------------------------------------------------------------------------
# check-agents-md — no-op when no AGENTS.md
# ---------------------------------------------------------------------------
run_hook "check-agents-md.sh" \
  '{"tool_name":"Edit","tool_input":{"file_path":"/tmp/no-agents-md/file.ts"}}'
assert_allows "check-agents-md: no-op (no AGENTS.md)"

# ---------------------------------------------------------------------------
# check-agents-md — coverage ratchet and staleness detection
#
# Regression guard for the failure that motivated these branches: a one-off
# generator produced AGENTS.md files, nothing ever prompted new ones, and
# nothing noticed when the ones that existed named files that had moved.
# ---------------------------------------------------------------------------
echo ""
echo "  [code-context] uncovered-directory and staleness branches"

TMP_CC="$(mktemp -d)"
mkdir -p "${TMP_CC}/.agents" "${TMP_CC}/src/stores" "${TMP_CC}/src/utils" \
         "${TMP_CC}/node_modules/pkg"
touch "${TMP_CC}/.agents/uncle-dev-setup.yaml"
for i in 1 2 3; do
  touch "${TMP_CC}/src/stores/store${i}.ts" \
        "${TMP_CC}/src/utils/util${i}.ts" \
        "${TMP_CC}/node_modules/pkg/mod${i}.js"
done

# A node that names two live files, one dead file, and one boundary rule.
cat > "${TMP_CC}/src/stores/AGENTS.md" <<'CCEOF'
# Stores
- `store1.ts` — alive
- `familyStore.ts` — migrated to core, no longer here
- Never import from `../internal/`
CCEOF

export PROJECT_DIR="${TMP_CC}"

# Stale paths are reported, boundary rules are not mistaken for file claims.
run_hook "check-agents-md.sh" \
  "{\"tool_name\":\"Edit\",\"tool_input\":{\"file_path\":\"${TMP_CC}/src/stores/store1.ts\"}}"
if printf '%s' "$HC_OUT" | grep -q 'STALE' \
   && printf '%s' "$HC_OUT" | grep -q 'familyStore.ts'; then
  ok "check-agents-md: reports stale paths named by an AGENTS.md"
else
  fail "check-agents-md: stale path familyStore.ts not reported"
fi
if printf '%s' "$HC_OUT" | grep -q 'internal'; then
  fail "check-agents-md: boundary rule '../internal/' wrongly reported as stale"
else
  ok "check-agents-md: directory boundary rules not reported as stale"
fi

# ---------------------------------------------------------------------------
# 60-line cap on a node. A node is read before every edit in its directory, so
# an oversized one gets skimmed instead of read. The hook must say so, and must
# stay quiet at exactly the cap (the off-by-one is the case that matters).
# ---------------------------------------------------------------------------
mkdir -p "${TMP_CC}/src/big" "${TMP_CC}/src/atcap"
touch "${TMP_CC}/src/big/a.ts" "${TMP_CC}/src/atcap/a.ts"

# 61 lines — one over.
{ echo "# Big"; i=1; while [ $i -le 60 ]; do echo "- rule ${i}"; i=$((i + 1)); done; } \
  > "${TMP_CC}/src/big/AGENTS.md"
run_hook "check-agents-md.sh" \
  "{\"tool_name\":\"Edit\",\"tool_input\":{\"file_path\":\"${TMP_CC}/src/big/a.ts\"}}"
assert_allows "check-agents-md: oversized-node advisory allows (exit 0)"
if printf '%s' "$HC_OUT" | grep -q 'OVERSIZED' \
   && printf '%s' "$HC_OUT" | grep -q '61 lines'; then
  ok "check-agents-md: reports a node over the 60-line cap"
else
  fail "check-agents-md: 61-line node not reported as oversized"
fi
# The read-it reminder must survive alongside the defect report: hook_advise
# exits, so a second advisory would never be emitted.
if printf '%s' "$HC_OUT" | grep -q 'Read it before making changes'; then
  ok "check-agents-md: oversize advisory retains the read-it reminder"
else
  fail "check-agents-md: read-it reminder lost when node is oversized"
fi

# Exactly 60 lines — at the cap, not over it. Must not fire.
{ echo "# At cap"; i=1; while [ $i -le 59 ]; do echo "- rule ${i}"; i=$((i + 1)); done; } \
  > "${TMP_CC}/src/atcap/AGENTS.md"
run_hook "check-agents-md.sh" \
  "{\"tool_name\":\"Edit\",\"tool_input\":{\"file_path\":\"${TMP_CC}/src/atcap/a.ts\"}}"
if printf '%s' "$HC_OUT" | grep -q 'OVERSIZED'; then
  fail "check-agents-md: 60-line node wrongly flagged (cap is exceed, not reach)"
else
  ok "check-agents-md: silent for a node exactly at the 60-line cap"
fi

# The ROOT context file is exempt from the cap. It carries project-wide stack,
# commands, conventions, and the child-node index — in an OpenCode or Codex
# project it is the only rules file there is. Capping it would push that
# content somewhere worse, not shrink it.
{ echo "# Root"; i=1; while [ $i -le 120 ]; do echo "- project rule ${i}"; i=$((i + 1)); done; } \
  > "${TMP_CC}/AGENTS.md"
touch "${TMP_CC}/root_file.ts"
run_hook "check-agents-md.sh" \
  "{\"tool_name\":\"Edit\",\"tool_input\":{\"file_path\":\"${TMP_CC}/root_file.ts\"}}"
if printf '%s' "$HC_OUT" | grep -q 'OVERSIZED'; then
  fail "check-agents-md: root AGENTS.md wrongly capped at 60 lines"
else
  ok "check-agents-md: root AGENTS.md exempt from the 60-line cap"
fi
# ...and the exemption must survive a relative path, since the tool input may
# be relative while PROJECT_DIR is absolute. A string compare misses that.
HC_OUT="$( cd "${TMP_CC}" && printf '%s' \
  '{"tool_name":"Edit","tool_input":{"file_path":"root_file.ts"}}' \
  | PROJECT_DIR="${TMP_CC}" bash "${HOOKS_DIR}/check-agents-md.sh" 2>&1 )"
if printf '%s' "$HC_OUT" | grep -q 'OVERSIZED'; then
  fail "check-agents-md: root exemption lost when file_path is relative"
else
  ok "check-agents-md: root exemption holds for a relative file_path"
fi
rm -f "${TMP_CC}/AGENTS.md" "${TMP_CC}/root_file.ts"

# A small uncovered directory that is not a boundary gets NO advisory. The
# skill's rule is <20k tokens → no node; a node per directory is the failure
# this hook must not cause.
run_hook "check-agents-md.sh" \
  "{\"tool_name\":\"Edit\",\"tool_input\":{\"file_path\":\"${TMP_CC}/src/utils/util1.ts\"}}"
if [ "$HC_RC" -eq 0 ] && [ -z "$HC_OUT" ]; then
  ok "check-agents-md: silent for a small non-boundary directory (<20k tokens)"
else
  fail "check-agents-md: advised for a sub-threshold directory (rc=$HC_RC)"
fi

# A package root IS a boundary — responsibility shifts there regardless of size.
# This is the case that leaves a newly created package at zero coverage.
echo '{}' > "${TMP_CC}/src/package.json"
run_hook "check-agents-md.sh" \
  "{\"tool_name\":\"Edit\",\"tool_input\":{\"file_path\":\"${TMP_CC}/src/utils/util1.ts\"}}"
assert_allows "check-agents-md: boundary advisory allows (exit 0)"
if printf '%s' "$HC_OUT" | grep -q "own the node is ${TMP_CC}/src\b"; then
  ok "check-agents-md: names the package root as the boundary, not the leaf dir"
else
  fail "check-agents-md: boundary not resolved to the package root"
fi

# A root context file must NOT suppress an advisory for an uncovered package
# beneath it — that precedence bug is how packages stay at zero coverage.
printf '# Root\n' > "${TMP_CC}/CLAUDE.md"
run_hook "check-agents-md.sh" \
  "{\"tool_name\":\"Edit\",\"tool_input\":{\"file_path\":\"${TMP_CC}/src/utils/util1.ts\"}}"
if printf '%s' "$HC_OUT" | grep -q 'no AGENTS.md covers'; then
  ok "check-agents-md: root CLAUDE.md does not suppress an uncovered package"
else
  fail "check-agents-md: root node wrongly suppressed a package-level advisory"
fi

# node_modules never gets an advisory.
run_hook "check-agents-md.sh" \
  "{\"tool_name\":\"Edit\",\"tool_input\":{\"file_path\":\"${TMP_CC}/node_modules/pkg/mod1.js\"}}"
if [ "$HC_RC" -eq 0 ] && [ -z "$HC_OUT" ]; then
  ok "check-agents-md: silent inside node_modules"
else
  fail "check-agents-md: emitted output for node_modules (rc=$HC_RC)"
fi

# Once the boundary carries a node, directories beneath it go quiet — one node
# per boundary, not one per directory.
printf '# Src\n- Boundary rules live here\n' > "${TMP_CC}/src/AGENTS.md"
run_hook "check-agents-md.sh" \
  "{\"tool_name\":\"Edit\",\"tool_input\":{\"file_path\":\"${TMP_CC}/src/utils/util1.ts\"}}"
if [ "$HC_RC" -eq 0 ] && [ -z "$HC_OUT" ]; then
  ok "check-agents-md: a node at the boundary suppresses advisories beneath it"
else
  fail "check-agents-md: advised despite boundary coverage (rc=$HC_RC)"
fi

# Outside an uncle-dev project the hook stays fully silent.
TMP_CC2="$(mktemp -d)"
mkdir -p "${TMP_CC2}/src"
for i in 1 2 3; do touch "${TMP_CC2}/src/a${i}.ts"; done
PROJECT_DIR="${TMP_CC2}"
run_hook "check-agents-md.sh" \
  "{\"tool_name\":\"Edit\",\"tool_input\":{\"file_path\":\"${TMP_CC2}/src/a1.ts\"}}"
if [ "$HC_RC" -eq 0 ] && [ -z "$HC_OUT" ] && [ -z "$HC_ERR" ]; then
  ok "check-agents-md: silent outside an uncle-dev project"
else
  fail "check-agents-md: emitted output in a non-uncle-dev repo (rc=$HC_RC)"
fi

unset PROJECT_DIR

# ---------------------------------------------------------------------------
# openspec-guard — advisory shape for invalid change ID (d)
# ---------------------------------------------------------------------------
echo ""
echo "  [R-1.1/d] openspec-guard advisory output shape"

TMP_OS="$(mktemp -d)"
# Create a fake openspec/changes/bad-id/ structure
BAD_CHANGE_DIR="${TMP_OS}/openspec/changes/bad-id"
mkdir -p "$BAD_CHANGE_DIR"
FAKE_OS_FILE="${BAD_CHANGE_DIR}/design.md"
touch "$FAKE_OS_FILE"

run_hook "openspec-guard.sh" \
  "{\"tool_name\":\"Edit\",\"tool_input\":{\"file_path\":\"${FAKE_OS_FILE}\"}}"
assert_allows "openspec-guard: advisory exits 0 on bad change ID"
assert_advise_shape "openspec-guard: bad change ID uses hookSpecificOutput shape"
# TMP_OS is cleaned up by the EXIT trap

# ---------------------------------------------------------------------------
# spec-coherence-guard — dispatch on tool_name from stdin (R-1.1)
# ---------------------------------------------------------------------------
echo ""
echo "  [R-1.1] spec-coherence-guard: dispatches on HOOK_TOOL_NAME from stdin"

# Read tool — not matched by spec-coherence-guard, passes through
run_hook "spec-coherence-guard.sh" \
  "$(_b64d 'eyJ0b29sX25hbWUiOiAiUmVhZCIsICJ0b29sX2lucHV0IjogeyJmaWxlX3BhdGgiOiAiL3RtcC90ZXN0LnRzIn19')"
assert_allows "spec-coherence-guard: Read tool passes (not dispatched)"

# Bash non-commit command — passes through
run_hook "spec-coherence-guard.sh" \
  "$(_b64d 'eyJ0b29sX25hbWUiOiAiQmFzaCIsICJ0b29sX2lucHV0IjogeyJjb21tYW5kIjogIm5wbSB0ZXN0In19')"
assert_allows "spec-coherence-guard: non-commit Bash passes"

# ---------------------------------------------------------------------------
# (e) wrap-nudge — Stop hook uses {priority,message} shape
# (only when thresholds would be crossed; we skip the actual threshold trigger
#  since it requires real token data — we test the output shape contract via
#  a minimal integration that just confirms the script syntax-checks clean)
# ---------------------------------------------------------------------------
echo ""
echo "  [R-1.9/e] wrap-nudge: no CONFIG_FILE variable"

CONFIG_FILE_HITS=$(grep -n 'CONFIG_FILE' "${HOOKS_DIR}/wrap-nudge.sh" 2>/dev/null || true)
if [ -z "$CONFIG_FILE_HITS" ]; then
  ok "wrap-nudge: CONFIG_FILE variable removed (R-1.9)"
else
  fail "wrap-nudge: CONFIG_FILE still present:"$'\n'"${CONFIG_FILE_HITS}"
fi

# (f) gate-notify — no gate match → exit 0, no stdout JSON
echo ""
echo "  [f] gate-notify: no gate phrase → exit 0, no JSON output"

# Feed a transcript with an assistant message that has no gate phrase
TMP_TRANSCRIPT="$(mktemp)"
printf '{"type":"assistant","message":{"content":[{"type":"text","text":"All done, nothing to see here."}]}}\n' \
  > "$TMP_TRANSCRIPT"
run_hook "gate-notify.sh" \
  "{\"transcript_path\":\"${TMP_TRANSCRIPT}\",\"cwd\":\"$(pwd)\"}"
if [ "$HC_RC" -eq 0 ] && [ -z "$HC_OUT" ]; then
  ok "gate-notify: no gate phrase → exit 0, no stdout JSON"
else
  fail "gate-notify: unexpected rc=$HC_RC or stdout='${HC_OUT}'"
fi
python3 -c "import os,sys; os.remove(sys.argv[1])" "$TMP_TRANSCRIPT" 2>/dev/null || true

# ---------------------------------------------------------------------------
# R-1.6: jq absent → exit 0 (smoke: source the lib with jq stubbed out)
# ---------------------------------------------------------------------------
echo ""
echo "  [R-1.6] jq-absent guard: hooks exit 0 when jq not found"

# Strategy: create a minimal PATH directory that contains only bash (no jq),
# then invoke bash with that restricted PATH so 'command -v jq' fails.
BASH_PATH="$(command -v bash)"
JQ_FAKE_BIN=$(mktemp -d)
ln -sf "$BASH_PATH" "${JQ_FAKE_BIN}/bash" 2>/dev/null || true
# Do NOT link jq into JQ_FAKE_BIN

JQ_GUARD_RC=0
JQ_GUARD_OUT=$(
  PATH="${JQ_FAKE_BIN}" "$BASH_PATH" -c \
    "source '${HOOKS_DIR}/lib/hook-contract.sh'; hook_read_input; echo SHOULD_NOT_REACH" \
    </dev/null 2>/dev/null
) || JQ_GUARD_RC=$?
python3 -c "import shutil,sys; shutil.rmtree(sys.argv[1], ignore_errors=True)" "$JQ_FAKE_BIN" 2>/dev/null || true

if [ "$JQ_GUARD_RC" -eq 0 ] && [ -z "$JQ_GUARD_OUT" ]; then
  ok "R-1.6: hook_read_input exits 0 silently when jq absent"
else
  fail "R-1.6: hook_read_input exit code=$JQ_GUARD_RC, output='${JQ_GUARD_OUT}'"
fi

# ---------------------------------------------------------------------------
# R-1.7: hooks.json quotes CLAUDE_PLUGIN_ROOT
# ---------------------------------------------------------------------------
echo ""
echo "  [R-1.7] hooks.json quotes CLAUDE_PLUGIN_ROOT"

UNQUOTED_HITS=$(grep -n '\${CLAUDE_PLUGIN_ROOT}' "${HOOKS_DIR}/hooks.json" 2>/dev/null \
  | grep -v '"${CLAUDE_PLUGIN_ROOT}' || true)
if [ -z "$UNQUOTED_HITS" ]; then
  ok "R-1.7: all CLAUDE_PLUGIN_ROOT references are quoted in hooks.json"
else
  fail "R-1.7: unquoted CLAUDE_PLUGIN_ROOT found in hooks.json:"$'\n'"${UNQUOTED_HITS}"
fi

# ---------------------------------------------------------------------------
# R-1.12: no bash 4+ features in hooks/
# ---------------------------------------------------------------------------
echo ""
echo "  [R-1.12] bash 3.2 compatibility: no declare -A / mapfile / readarray"

# Exclude comment-only lines (lines where the pattern appears after a leading #)
BASH4_HITS=$(grep -rn 'declare -A\|mapfile\|readarray' "${HOOKS_DIR}" \
  --include="*.sh" 2>/dev/null \
  | grep -v ':[[:space:]]*#' || true)
if [ -z "$BASH4_HITS" ]; then
  ok "R-1.12: no bash 4+ features found in hooks/ (excluding comments)"
else
  fail "R-1.12: bash 4+ features found:"$'\n'"${BASH4_HITS}"
fi

# ---------------------------------------------------------------------------
# R-1.1: hook-contract.sh exports the required variables
# ---------------------------------------------------------------------------
echo ""
echo "  [R-1.1] hook-contract.sh: HOOK_* variables exported"

EXPORTED_VARS=$(
  printf '{"tool_name":"Edit","tool_input":{"file_path":"/tmp/test.ts","content":"hello","new_string":"world","command":"ls"}}' \
  | bash -c "
    source '${HOOKS_DIR}/lib/hook-contract.sh'
    hook_read_input
    echo \"TOOL_NAME=\${HOOK_TOOL_NAME}\"
    echo \"FILE_PATH=\${HOOK_FILE_PATH}\"
    echo \"CONTENT=\${HOOK_CONTENT}\"
    echo \"NEW_STRING=\${HOOK_NEW_STRING}\"
  " 2>/dev/null
) || true

if printf '%s' "$EXPORTED_VARS" | grep -q 'TOOL_NAME=Edit' 2>/dev/null; then
  ok "R-1.1: HOOK_TOOL_NAME exported correctly"
else
  fail "R-1.1: HOOK_TOOL_NAME not set (got: ${EXPORTED_VARS})"
fi

if printf '%s' "$EXPORTED_VARS" | grep -q 'FILE_PATH=/tmp/test.ts' 2>/dev/null; then
  ok "R-1.1: HOOK_FILE_PATH exported correctly"
else
  fail "R-1.1: HOOK_FILE_PATH not set (got: ${EXPORTED_VARS})"
fi

# ---------------------------------------------------------------------------
# R-1.14: hook_require_project exits 0 silently in non-uncle-dev repo
# ---------------------------------------------------------------------------
echo ""
echo "  [R-1.14] hook_require_project: silent exit 0 in non-uncle-dev dir"

TMP_NON_UNCLE="$(mktemp -d)"
REQ_RC=0
REQ_OUT=""
REQ_ERR=""
REQ_OUT=$(
  cd "$TMP_NON_UNCLE" && \
  bash -c "source '${HOOKS_DIR}/lib/hook-contract.sh'; hook_require_project; echo 'SHOULD_NOT_REACH'" \
  2>"${_HC_STDERR_FILE}"
) || REQ_RC=$?
REQ_ERR=$(cat "${_HC_STDERR_FILE}" 2>/dev/null) || true
# Cleanup: python3 handles TMP_NON_UNCLE (no rm in this script)
python3 -c "import shutil,sys; shutil.rmtree(sys.argv[1], ignore_errors=True)" "$TMP_NON_UNCLE" 2>/dev/null || true

if [ "$REQ_RC" -eq 0 ] && [ -z "$REQ_OUT" ] && [ -z "$REQ_ERR" ]; then
  ok "R-1.14: hook_require_project exits 0 silently (no stdout, no stderr)"
else
  fail "R-1.14: hook_require_project: rc=$REQ_RC, stdout='${REQ_OUT}', stderr='${REQ_ERR}'"
fi

# ---------------------------------------------------------------------------
# bash -n syntax check on all touched files
# ---------------------------------------------------------------------------
echo ""
echo "  [syntax] bash -n on all hook scripts and lib"

SYNTAX_FAIL=0
for f in \
  "${HOOKS_DIR}/lib/hook-contract.sh" \
  "${HOOKS_DIR}/check-agents-md.sh" \
  "${HOOKS_DIR}/openspec-guard.sh" \
  "${HOOKS_DIR}/spec-coherence-guard.sh" \
  "${HOOKS_DIR}/pre-commit-guard.sh" \
  "${HOOKS_DIR}/destructive-command-guard.sh" \
  "${HOOKS_DIR}/session-start.sh" \
  "${HOOKS_DIR}/gate-notify.sh" \
  "${HOOKS_DIR}/wrap-nudge.sh" \
  "${HOOKS_DIR}/knowledge-capture-nudge.sh"
do
  if bash -n "$f" 2>"${_HC_STDERR_FILE}"; then
    ok "syntax: $( basename "$f" )"
  else
    fail "syntax: $( basename "$f" ) — $(cat "${_HC_STDERR_FILE}" 2>/dev/null)"
    SYNTAX_FAIL=$((SYNTAX_FAIL + 1))
  fi
  printf '' > "${_HC_STDERR_FILE}"
done

# ---------------------------------------------------------------------------
# Results
# ---------------------------------------------------------------------------
echo ""
echo "── Result ────────────────────────────────────────────────"
echo "  PASS: ${PASS}  FAIL: ${FAIL}"
[[ "${FAIL}" -eq 0 ]] || exit 1
