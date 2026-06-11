#!/bin/bash
# lint-skills — run nori-lint (https://github.com/tilework-tech/nori-lint) over SKILL.md files.
#
# Usage: lint-skills.sh [--enforce] [--deep] [--fix [--dry-run]] [path ...]
#   (no flags)  Report-only: print violations, always exit 0.
#   --enforce   Exit 1 if any violations are found (CI gate, post-baseline).
#   --deep      Also run LLM-based rules. Requires ANTHROPIC_API_KEY in the
#               environment; the key is merged into a temp config and never
#               written to a tracked file.
#   --fix       Auto-fix fixable violations IN PLACE via `nori-lint fix`.
#               Caution: applies nori-lint's opinions (strips bold/italics,
#               deletes "When to Use" sections); without --deep the disabled
#               list in nori-lint.config.json is NOT honored. Run on a clean
#               git tree and review the diff.
#   --dry-run   With --fix: show what would change without writing.
#   path        One or more skill directories or SKILL.md files. Defaults to skills/.
#
# Rule configuration lives in scripts/nori-lint.config.json (rules.disabled).
# nori-lint only honors a config file when it contains an API key, so in static
# mode this script filters disabled rules from the JSON output itself.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"
RULE_CONFIG="${SCRIPT_DIR}/nori-lint.config.json"

ENFORCE=0
DEEP=0
FIX=0
DRY_RUN=0
PATHS=()
for arg in "$@"; do
  case "$arg" in
    --enforce) ENFORCE=1 ;;
    --deep)    DEEP=1 ;;
    --fix)     FIX=1 ;;
    --dry-run) DRY_RUN=1 ;;
    -h|--help) sed -n '2,21p' "${BASH_SOURCE[0]}"; exit 0 ;;
    *)         PATHS+=("$arg") ;;
  esac
done
[ "${#PATHS[@]}" -eq 0 ] && PATHS=("${REPO_ROOT}/skills")

command -v npx >/dev/null 2>&1 || { echo "lint-skills: npx not found; skipping skill lint" >&2; exit 0; }
command -v jq  >/dev/null 2>&1 || { echo "lint-skills: jq not found; skipping skill lint" >&2; exit 0; }

DISABLED_RULES="$(jq -c '.rules.disabled // []' "$RULE_CONFIG" 2>/dev/null || echo '[]')"

# --deep: merge the rule config with the API key into a temp config.
CONFIG_ARGS=()
if [ "$DEEP" -eq 1 ]; then
  if [ -z "${ANTHROPIC_API_KEY:-}" ]; then
    echo "lint-skills: --deep requires ANTHROPIC_API_KEY in the environment" >&2
    exit 1
  fi
  TMP_CONFIG="$(mktemp -t nori-lint-config.XXXXXX)"
  trap 'rm -f "$TMP_CONFIG"' EXIT
  jq --arg key "$ANTHROPIC_API_KEY" '. + {anthropic_api_key: $key}' "$RULE_CONFIG" > "$TMP_CONFIG"
  CONFIG_ARGS=(--config "$TMP_CONFIG")
fi

# Resolve each path to the set of directories containing a SKILL.md.
# nori-lint is run once per skill directory: large single runs lose JSON
# output past 64KB on process exit.
TARGETS=()
for p in "${PATHS[@]}"; do
  if [ -f "$p" ]; then
    TARGETS+=("$(cd "$(dirname "$p")" && pwd)")
  elif [ -d "$p" ]; then
    while IFS= read -r f; do
      TARGETS+=("$(cd "$(dirname "$f")" && pwd)")
    done < <(find "$p" -name SKILL.md -not -path '*/node_modules/*' | sort)
  else
    echo "lint-skills: path not found: $p" >&2
  fi
done
if [ "${#TARGETS[@]}" -eq 0 ]; then
  echo "lint-skills: no SKILL.md files found"
  exit 0
fi
TARGETS=($(printf '%s\n' "${TARGETS[@]}" | awk '!seen[$0]++'))

if [ "$FIX" -eq 1 ]; then
  FIX_ARGS=()
  [ "$DRY_RUN" -eq 1 ] && FIX_ARGS=(--dry-run)
  [ "$DRY_RUN" -eq 0 ] && echo "lint-skills: applying fixes in place — review the git diff afterwards" >&2
  for dir in "${TARGETS[@]}"; do
    echo "── fix: ${dir#"$REPO_ROOT"/} ──"
    npx --yes nori-lint fix "$dir" ${FIX_ARGS[@]+"${FIX_ARGS[@]}"} ${CONFIG_ARGS[@]+"${CONFIG_ARGS[@]}"} || true
  done
  exit 0
fi

TOTAL=0
FILES_AFFECTED=0
for dir in "${TARGETS[@]}"; do
  OUTPUT="$(npx --yes nori-lint lint "$dir" --format json ${CONFIG_ARGS[@]+"${CONFIG_ARGS[@]}"} 2>/dev/null | sed '/^note:/d' || true)"
  jq -e . >/dev/null 2>&1 <<<"$OUTPUT" || { echo "lint-skills: unparseable output for $dir" >&2; continue; }
  FINDINGS="$(jq --argjson disabled "$DISABLED_RULES" '[.[] | select(.rule as $r | $disabled | index($r) | not)]' <<<"$OUTPUT")"
  COUNT="$(jq 'length' <<<"$FINDINGS")"
  [ "$COUNT" -eq 0 ] && continue
  TOTAL=$((TOTAL + COUNT))
  FILES_AFFECTED=$((FILES_AFFECTED + 1))
  REL="${dir#"$REPO_ROOT"/}"
  jq -r --arg rel "$REL" '.[] | "\($rel)/\(.file):\(.line // "?")  [\(.rule)]  \(.message)"' <<<"$FINDINGS"
done

echo ""
echo "lint-skills: ${TOTAL} violation(s) in ${FILES_AFFECTED} of ${#TARGETS[@]} skill(s)"
[ "$DEEP" -eq 0 ] && echo "lint-skills: static rules only (use --deep with ANTHROPIC_API_KEY for LLM rules)"

if [ "$ENFORCE" -eq 1 ] && [ "$TOTAL" -gt 0 ]; then
  exit 1
fi
exit 0
