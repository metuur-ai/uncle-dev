#!/bin/bash
# wrap-nudge — Stop event
# Nudges to run /uncle-dev-wrap when context/token usage crosses configured limits.

set -euo pipefail

command -v jq >/dev/null 2>&1 || exit 0

if [ -t 0 ]; then INPUT="{}"; else INPUT=$(cat); fi

# Resolve project dir from hook payload, then Claude env, then cwd.
HOOK_CWD=$(printf '%s' "$INPUT" | jq -r '.cwd // empty' 2>/dev/null || echo "")
PROJECT_DIR="${HOOK_CWD:-${CLAUDE_PROJECT_DIR:-$PWD}}"
CONFIG_FILE="${PROJECT_DIR}/.agents/uncle-dev-setup.yaml"

# Defaults requested by repo/user policy.
HOOK_ENABLED="true"
WRAP_ENABLED="true"
THRESHOLD_PERCENT="70"
THRESHOLD_TOKENS="130000"

if [[ -f "$CONFIG_FILE" ]]; then
  CFG_RAW=$(python3 - "$CONFIG_FILE" <<'PYEOF'
import sys
import yaml

path = sys.argv[1]
with open(path, "r", encoding="utf-8") as f:
    data = yaml.safe_load(f) or {}

hooks = data.get("hooks", {})
prefs = data.get("preferences", {})
wrap = prefs.get("wrap_trigger", {}) if isinstance(prefs, dict) else {}

def sval(v, d):
    if v is None:
        return d
    if isinstance(v, bool):
        return "true" if v else "false"
    return str(v)

print(sval(hooks.get("wrap_nudge"), "true"))
print(sval(wrap.get("enabled"), "true"))
print(sval(wrap.get("context_window_percent"), "70"))
print(sval(wrap.get("total_tokens"), "130000"))
PYEOF
)

  CFG0=$(printf '%s\n' "$CFG_RAW" | sed -n '1p')
  CFG1=$(printf '%s\n' "$CFG_RAW" | sed -n '2p')
  CFG2=$(printf '%s\n' "$CFG_RAW" | sed -n '3p')
  CFG3=$(printf '%s\n' "$CFG_RAW" | sed -n '4p')

  HOOK_ENABLED="${CFG0:-true}"
  WRAP_ENABLED="${CFG1:-true}"
  THRESHOLD_PERCENT="${CFG2:-70}"
  THRESHOLD_TOKENS="${CFG3:-130000}"
fi

[[ "$HOOK_ENABLED" == "true" ]] || exit 0
[[ "$WRAP_ENABLED" == "true" ]] || exit 0

# Read usage values from known hook payload paths.
USAGE_PERCENT=$(printf '%s' "$INPUT" | jq -r '
  .context_window_usage_pct //
  .usage.context_window_percent //
  .usage.context_window_usage_percent //
  .token_usage.context_window_percent //
  .token_usage.context_window_usage_percent //
  .model.context_window_percent //
  empty
' 2>/dev/null || true)

TOTAL_TOKENS=$(printf '%s' "$INPUT" | jq -r '
  .total_tokens //
  .usage.total_tokens //
  .usage.tokens.total //
  .token_usage.total_tokens //
  .token_usage.total //
  .metrics.total_tokens //
  empty
' 2>/dev/null || true)

# Normalize numbers (drop % and decimals).
USAGE_PERCENT=$(printf '%s' "$USAGE_PERCENT" | sed -E 's/%//g' | awk -F. '{print $1}')
TOTAL_TOKENS=$(printf '%s' "$TOTAL_TOKENS" | awk -F. '{print $1}')

PCT_HIT=0
TOK_HIT=0

if [[ "$USAGE_PERCENT" =~ ^[0-9]+$ ]] && [[ "$THRESHOLD_PERCENT" =~ ^[0-9]+$ ]]; then
  (( USAGE_PERCENT >= THRESHOLD_PERCENT )) && PCT_HIT=1 || true
fi

if [[ "$TOTAL_TOKENS" =~ ^[0-9]+$ ]] && [[ "$THRESHOLD_TOKENS" =~ ^[0-9]+$ ]]; then
  (( TOTAL_TOKENS >= THRESHOLD_TOKENS )) && TOK_HIT=1 || true
fi

(( PCT_HIT == 1 || TOK_HIT == 1 )) || exit 0

# Cooldown (30 min) to avoid repeating each stop event.
STAMP_DIR="${PROJECT_DIR}/.claude"
STAMP_FILE="${STAMP_DIR}/.wrap-nudged"
mkdir -p "$STAMP_DIR" 2>/dev/null || true
if [[ -f "$STAMP_FILE" ]]; then
  if [ -n "$(find "$STAMP_FILE" -mmin -30 2>/dev/null)" ]; then
    exit 0
  fi
fi
touch "$STAMP_FILE" 2>/dev/null || true

DETAILS=()
if (( PCT_HIT == 1 )); then
  DETAILS+=("context ${USAGE_PERCENT}% >= ${THRESHOLD_PERCENT}%")
fi
if (( TOK_HIT == 1 )); then
  DETAILS+=("tokens ${TOTAL_TOKENS} >= ${THRESHOLD_TOKENS}")
fi
REASON=$(IFS='; '; echo "${DETAILS[*]}")

jq -n --arg reason "$REASON" '{
  "priority": "IMPORTANT",
  "message": ("Session is approaching context/token limits (" + $reason + "). Run /uncle-dev-wrap to capture a resumable handoff before continuing.")
}'

exit 0
