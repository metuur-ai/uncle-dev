#!/bin/bash
# spec-coherence-guard — PreToolUse Edit|Write|Bash
#
# Two modes:
#   1. Edit|Write: extracts @spec IDs from new content, validates each ID
#      exists in docs/specs/. Blocks (exit 2) on unknown IDs.
#   2. Bash: when the command is `git commit*`, runs the full scanner.
#      Blocks (exit 2) on non-zero scanner exit.
#
# Skips silently when docs/specs/ does not exist (graceful adoption).

set -uo pipefail

# shellcheck source=lib/hook-contract.sh
source "${BASH_SOURCE%/*}/lib/hook-contract.sh"

hook_read_input

REPO_ROOT="$(pwd)"
SPECS_DIR="$REPO_ROOT/docs/specs"
CFG_SCRIPT="${CLAUDE_PLUGIN_ROOT:-}/scripts/uncle-dev-config.sh"
[ -f "$CFG_SCRIPT" ] || CFG_SCRIPT="$REPO_ROOT/scripts/uncle-dev-config.sh"

# Honor hooks.spec_coherence toggle (R-2.6): exit 0 if disabled in project config.
[[ "$(bash "$CFG_SCRIPT" hooks.spec_coherence true 2>/dev/null || echo true)" == "false" ]] && exit 0

EXEC_PROFILE="$(bash "$CFG_SCRIPT" preferences.execution_profile balanced 2>/dev/null || echo "balanced")"

# Graceful no-op: repos without a spec catalog aren't blocked.
[ -d "$SPECS_DIR" ] || exit 0

# ---------------------------------------------------------------------------
# Helpers
# ---------------------------------------------------------------------------

# Build the canonical spec ID set. Uses ripgrep when available, falls back to grep.
spec_id_set() {
  if command -v rg >/dev/null 2>&1; then
    rg --no-line-number --no-filename -o '\*\*[A-Z][A-Z0-9-]*-[0-9]+\*\*' "$SPECS_DIR" 2>/dev/null \
      | sed 's/^\*\*//; s/\*\*$//' | sort -u || true
  else
    grep -rhEo '\*\*[A-Z][A-Z0-9-]*-[0-9]+\*\*' "$SPECS_DIR" 2>/dev/null \
      | sed 's/^\*\*//; s/\*\*$//' | sort -u || true
  fi
}

# Extract @spec IDs from arbitrary text passed on stdin.
extract_spec_ids() {
  grep -oE '@spec[[:space:]]+[A-Z][A-Z0-9,[:space:]-]+' \
    | sed 's/^@spec[[:space:]]*//' \
    | tr ',' ' ' \
    | tr -s '[:space:]' '\n' \
    | grep -E '^[A-Z][A-Z0-9-]*-[0-9]+$' \
    | sort -u || true
}

# ---------------------------------------------------------------------------
# Mode 1 — Edit / Write (validate new content)
# ---------------------------------------------------------------------------

handle_edit_or_write() {
  [ -z "$HOOK_FILE_PATH" ] && exit 0

  # Only check files that look like source code or tests.
  case "$HOOK_FILE_PATH" in
    *.ts|*.tsx|*.js|*.jsx|*.mjs|*.cjs|*.py|*.go|*.rs|*.java|*.kt|*.html|*.htm|*.vue|*.svelte) ;;
    *) exit 0 ;;
  esac

  # Determine the new content. Write provides full content; Edit provides new_string.
  local new_content="${HOOK_CONTENT:-${HOOK_NEW_STRING:-}}"
  [ -z "$new_content" ] && exit 0

  # Quick reject: no @spec, no work.
  case "$new_content" in
    *@spec*) ;;
    *) exit 0 ;;
  esac

  local cited_ids
  cited_ids="$(printf '%s' "$new_content" | extract_spec_ids)"
  [ -z "$cited_ids" ] && exit 0

  local known_ids
  known_ids="$(spec_id_set)"

  local unknown=""
  while IFS= read -r id; do
    [ -z "$id" ] && continue
    if ! printf '%s\n' "$known_ids" | grep -qx "$id" >/dev/null 2>&1; then
      unknown="${unknown}${unknown:+, }${id}"
    fi
  done <<< "$cited_ids"

  if [ -n "$unknown" ]; then
    local msg="spec-coherence-guard: BLOCKED edit to $HOOK_FILE_PATH

  Unknown spec IDs cited via @spec: $unknown

  These IDs are not defined in docs/specs/.
  Fix one of:
    - Add the missing IDs to docs/specs/<segment>-specs.md
    - Correct the @spec annotation to cite an existing ID
    - Remove the @spec annotation if this code does not implement product behavior

  Run /uncle-dev-spec-scan for the full coherence report."
    if [ "$EXEC_PROFILE" = "strict" ]; then
      hook_block "$msg"
    else
      hook_advise "${msg/BLOCKED/WARN}"
    fi
  fi
  exit 0
}

# ---------------------------------------------------------------------------
# Mode 2 — Bash (intercept git commit, run full scanner)
# ---------------------------------------------------------------------------

handle_bash() {
  [ -z "$HOOK_COMMAND" ] && exit 0

  # Only fire for commit-like commands.
  case "$HOOK_COMMAND" in
    *"git commit"*) ;;
    *) exit 0 ;;
  esac

  # Locate the scanner. Try installed plugin path first, then sibling repo path.
  local scanner=""
  for candidate in \
    "${CLAUDE_PLUGIN_ROOT:-}/skills/uncle-dev-spec-annotations/scan-spec-coherence.py" \
    "$HOME/.claude/plugins/cache/uncle-dev-agent-skills/uncle-dev/skills/uncle-dev-spec-annotations/scan-spec-coherence.py" \
    "$REPO_ROOT/skills/uncle-dev-spec-annotations/scan-spec-coherence.py"
  do
    if [ -n "$candidate" ] && [ -f "$candidate" ]; then
      scanner="$candidate"
      break
    fi
  done
  [ -z "$scanner" ] && exit 0

  local report
  report="$(python3 "$scanner" --root "$REPO_ROOT" --no-tree-sitter --quiet --format text 2>&1)" || true
  local rc=$?

  if [ $rc -ne 0 ]; then
    local msg="spec-coherence-guard: BLOCKED git commit

$(python3 "$scanner" --root "$REPO_ROOT" --no-tree-sitter --format text 2>&1 || true)

  Fix the orphan @spec citations above before committing.
  Run /uncle-dev-spec-scan locally to iterate."
    if [ "$EXEC_PROFILE" = "strict" ] || [ "$EXEC_PROFILE" = "balanced" ]; then
      hook_block "$msg"
    else
      hook_advise "${msg/BLOCKED/WARN}"
    fi
  fi
  exit 0
}

# ---------------------------------------------------------------------------
# Dispatch on HOOK_TOOL_NAME (populated from stdin JSON by hook_read_input)
# ---------------------------------------------------------------------------

case "$HOOK_TOOL_NAME" in
  Edit|Write) handle_edit_or_write ;;
  Bash)       handle_bash ;;
  *)          exit 0 ;;
esac
