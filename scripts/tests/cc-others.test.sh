#!/bin/bash
# Tests for scripts/cc-others.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/../.." && pwd)"
SCRIPT="${REPO_ROOT}/scripts/cc-others"

PASS=0; FAIL=0
ok()   { echo "  PASS: $*"; ((PASS++)) || true; }
fail() { echo "  FAIL: $*"; ((FAIL++)) || true; }

FAKE_HOME="$(mktemp -d)"
FAKE_BIN="$(mktemp -d)"
trap 'rm -rf "${FAKE_HOME}" "${FAKE_BIN}"' EXIT

cat > "${FAKE_HOME}/.claude_profiles.json" <<'JSON'
{
  "anthropic": {
    "ANTHROPIC_API_KEY": "sk-ant-test",
    "ANTHROPIC_BASE_URL": null,
    "ANTHROPIC_MODEL": "claude-sonnet-4-6"
  },
  "glm": {
    "ANTHROPIC_AUTH_TOKEN": "glm-token",
    "ANTHROPIC_BASE_URL": "https://glm.example.invalid",
    "ANTHROPIC_MODEL": "glm.8-max",
    "FEATURE_FLAG": true,
    "RETRY_COUNT": 3
  },
  "qwen": {
    "ANTHROPIC_AUTH_TOKEN": "qwen-token",
    "ANTHROPIC_BASE_URL": "https://qwen.example.invalid",
    "ANTHROPIC_MODEL": "qwen3.8-max"
  },
  "ds": {
    "ANTHROPIC_BASE_URL": "https://api.deepseek.com/anthropic",
    "ANTHROPIC_AUTH_TOKEN": "deepseek-token",
    "ANTHROPIC_MODEL": "deepseek-v4-pro[1m]",
    "ANTHROPIC_DEFAULT_OPUS_MODEL": "deepseek-v4-pro[1m]",
    "ANTHROPIC_DEFAULT_SONNET_MODEL": "deepseek-v4-pro[1m]",
    "ANTHROPIC_DEFAULT_HAIKU_MODEL": "deepseek-v4-flash",
    "CLAUDE_CODE_SUBAGENT_MODEL": "deepseek-v4-flash",
    "CLAUDE_CODE_EFFORT_LEVEL": "max",
    "CLAUDE_CODE_AUTO_COMPACT_WINDOW": 786432
  },
  "invalid-name": {
    "ANTHROPIC-BASE-URL": "bad"
  },
  "bad-value": {
    "ANTHROPIC_MODEL": ["not", "scalar"]
  }
}
JSON

cat > "${FAKE_BIN}/claude" <<'SH'
#!/bin/bash
{
  printf 'ANTHROPIC_API_KEY=%s\n' "${ANTHROPIC_API_KEY-}"
  printf 'ANTHROPIC_AUTH_TOKEN=%s\n' "${ANTHROPIC_AUTH_TOKEN-}"
  printf 'ANTHROPIC_BASE_URL=%s\n' "${ANTHROPIC_BASE_URL-}"
  printf 'ANTHROPIC_MODEL=%s\n' "${ANTHROPIC_MODEL-}"
  printf 'ANTHROPIC_DEFAULT_OPUS_MODEL=%s\n' "${ANTHROPIC_DEFAULT_OPUS_MODEL-}"
  printf 'ANTHROPIC_DEFAULT_SONNET_MODEL=%s\n' "${ANTHROPIC_DEFAULT_SONNET_MODEL-}"
  printf 'ANTHROPIC_DEFAULT_HAIKU_MODEL=%s\n' "${ANTHROPIC_DEFAULT_HAIKU_MODEL-}"
  printf 'CLAUDE_CODE_SUBAGENT_MODEL=%s\n' "${CLAUDE_CODE_SUBAGENT_MODEL-}"
  printf 'CLAUDE_CODE_EFFORT_LEVEL=%s\n' "${CLAUDE_CODE_EFFORT_LEVEL-}"
  printf 'CLAUDE_CODE_AUTO_COMPACT_WINDOW=%s\n' "${CLAUDE_CODE_AUTO_COMPACT_WINDOW-}"
  printf 'FEATURE_FLAG=%s\n' "${FEATURE_FLAG-}"
  printf 'RETRY_COUNT=%s\n' "${RETRY_COUNT-}"
  printf 'ARGS=%s\n' "$*"
} > "${CLAUDE_CAPTURE}"
SH
chmod +x "${FAKE_BIN}/claude"

run_cc_others() {
  local capture="$1"; shift
  HOME="${FAKE_HOME}" \
  PATH="${FAKE_BIN}:$PATH" \
  CLAUDE_CAPTURE="${capture}" \
  ANTHROPIC_BASE_URL="https://old.example.invalid" \
  bash "${SCRIPT}" "$@"
}

echo "── cc-others ─────────────────────────────────────────────"

CAPTURE="${FAKE_HOME}/anthropic.out"
run_cc_others "${CAPTURE}" anthropic --dangerously-skip-permissions

grep -qx 'ANTHROPIC_API_KEY=sk-ant-test' "${CAPTURE}" \
  && ok "sets ANTHROPIC_API_KEY from profile" \
  || fail "did not set ANTHROPIC_API_KEY"

grep -qx 'ANTHROPIC_BASE_URL=' "${CAPTURE}" \
  && ok "null unsets ANTHROPIC_BASE_URL" \
  || fail "ANTHROPIC_BASE_URL was not unset"

grep -qx 'ANTHROPIC_MODEL=claude-sonnet-4-6' "${CAPTURE}" \
  && ok "sets ANTHROPIC_MODEL from profile" \
  || fail "did not set ANTHROPIC_MODEL"

grep -qx 'ARGS=--dangerously-skip-permissions' "${CAPTURE}" \
  && ok "passes extra args through to claude" \
  || fail "did not pass extra args through"

CAPTURE="${FAKE_HOME}/resume.out"
run_cc_others "${CAPTURE}" claude --resume f4422bb0-473d-40d7-84bc-8b329915876f --qwen

grep -qx 'ANTHROPIC_AUTH_TOKEN=glm-token' "${CAPTURE}" \
  && fail "loaded the wrong profile for trailing --qwen"

grep -qx 'ANTHROPIC_MODEL=qwen3.8-max' "${CAPTURE}" \
  && ok "loads trailing --qwen profile selector" \
  || fail "did not load qwen profile"

grep -qx 'ANTHROPIC_AUTH_TOKEN=qwen-token' "${CAPTURE}" \
  && ok "loads qwen auth token" \
  || fail "did not load qwen auth token"

grep -qx 'ARGS=--resume f4422bb0-473d-40d7-84bc-8b329915876f' "${CAPTURE}" \
  && ok "supports literal claude plus trailing --profile selector" \
  || fail "did not support literal claude plus trailing --profile selector"

CAPTURE="${FAKE_HOME}/deepseek.out"
run_cc_others "${CAPTURE}" claude --resume f4422bb0-473d-40d7-84bc-8b329915876f --ds

grep -qx 'ANTHROPIC_BASE_URL=https://api.deepseek.com/anthropic' "${CAPTURE}" \
  && ok "loads DeepSeek base URL via --ds" \
  || fail "did not load DeepSeek base URL via --ds"

grep -qx 'ANTHROPIC_MODEL=deepseek-v4-pro\[1m\]' "${CAPTURE}" \
  && grep -qx 'ANTHROPIC_DEFAULT_OPUS_MODEL=deepseek-v4-pro\[1m\]' "${CAPTURE}" \
  && grep -qx 'ANTHROPIC_DEFAULT_SONNET_MODEL=deepseek-v4-pro\[1m\]' "${CAPTURE}" \
  && ok "loads DeepSeek pro model defaults via --ds" \
  || fail "did not load DeepSeek pro model defaults via --ds"

grep -qx 'ANTHROPIC_DEFAULT_HAIKU_MODEL=deepseek-v4-flash' "${CAPTURE}" \
  && grep -qx 'CLAUDE_CODE_SUBAGENT_MODEL=deepseek-v4-flash' "${CAPTURE}" \
  && ok "loads DeepSeek flash model defaults via --ds" \
  || fail "did not load DeepSeek flash model defaults via --ds"

grep -qx 'CLAUDE_CODE_EFFORT_LEVEL=max' "${CAPTURE}" \
  && grep -qx 'CLAUDE_CODE_AUTO_COMPACT_WINDOW=786432' "${CAPTURE}" \
  && ok "loads DeepSeek Claude Code controls via --ds" \
  || fail "did not load DeepSeek Claude Code controls via --ds"

CAPTURE="${FAKE_HOME}/glm.out"
run_cc_others "${CAPTURE}" glm

grep -qx 'ANTHROPIC_AUTH_TOKEN=glm-token' "${CAPTURE}" \
  && ok "sets alternate auth token variable" \
  || fail "did not set ANTHROPIC_AUTH_TOKEN"

grep -qx 'FEATURE_FLAG=true' "${CAPTURE}" \
  && grep -qx 'RETRY_COUNT=3' "${CAPTURE}" \
  && ok "serializes boolean and number profile values" \
  || fail "did not serialize boolean and number values"

if HOME="${FAKE_HOME}" PATH="${FAKE_BIN}:$PATH" CLAUDE_CAPTURE="${FAKE_HOME}/missing.out" bash "${SCRIPT}" missing >/tmp/cc-others-missing.stdout 2>/tmp/cc-others-missing.stderr; then
  fail "missing profile unexpectedly succeeded"
else
  grep -q 'Available profiles:' /tmp/cc-others-missing.stderr \
    && ok "missing profile lists available profiles" \
    || fail "missing profile did not list available profiles"
fi

if HOME="${FAKE_HOME}" PATH="${FAKE_BIN}:$PATH" CLAUDE_CAPTURE="${FAKE_HOME}/invalid.out" bash "${SCRIPT}" invalid-name >/tmp/cc-others-invalid.stdout 2>/tmp/cc-others-invalid.stderr; then
  fail "invalid environment variable name unexpectedly succeeded"
else
  grep -q 'invalid environment variable name' /tmp/cc-others-invalid.stderr \
    && ok "rejects invalid environment variable names" \
    || fail "invalid environment variable name error missing"
fi

if HOME="${FAKE_HOME}" PATH="${FAKE_BIN}:$PATH" CLAUDE_CAPTURE="${FAKE_HOME}/bad-value.out" bash "${SCRIPT}" bad-value >/tmp/cc-others-bad-value.stdout 2>/tmp/cc-others-bad-value.stderr; then
  fail "non-scalar value unexpectedly succeeded"
else
  grep -q 'profile values must be strings, numbers, booleans, or null' /tmp/cc-others-bad-value.stderr \
    && ok "rejects non-scalar profile values" \
    || fail "non-scalar value error missing"
fi

echo ""
echo "── Result ────────────────────────────────────────────────"
echo "  PASS: ${PASS}  FAIL: ${FAIL}"
[[ "${FAIL}" -eq 0 ]] || exit 1
