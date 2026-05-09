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

REPO_ROOT="$(pwd)"
SPECS_DIR="$REPO_ROOT/docs/specs"

# Graceful no-op: repos without a spec catalog aren't blocked.
[ -d "$SPECS_DIR" ] || exit 0

# ---------------------------------------------------------------------------
# Helpers
# ---------------------------------------------------------------------------

# Build the canonical spec ID set. Uses ripgrep when available, falls back to grep.
spec_id_set() {
  if command -v rg >/dev/null 2>&1; then
    rg --no-line-number --no-filename -o '\*\*[A-Z][A-Z0-9-]*-[0-9]+\*\*' "$SPECS_DIR" 2>/dev/null \
      | sed 's/^\*\*//; s/\*\*$//' | sort -u
  else
    grep -rhEo '\*\*[A-Z][A-Z0-9-]*-[0-9]+\*\*' "$SPECS_DIR" 2>/dev/null \
      | sed 's/^\*\*//; s/\*\*$//' | sort -u
  fi
}

# Extract @spec IDs from arbitrary text passed on stdin.
extract_spec_ids() {
  grep -oE '@spec[[:space:]]+[A-Z][A-Z0-9,[:space:]-]+' \
    | sed 's/^@spec[[:space:]]*//' \
    | tr ',' ' ' \
    | tr -s '[:space:]' '\n' \
    | grep -E '^[A-Z][A-Z0-9-]*-[0-9]+$' \
    | sort -u
}

block_with_message() {
  # Per Claude Code hook contract: stderr + exit 2 blocks the tool call.
  local msg="$1"
  printf '%s\n' "$msg" >&2
  exit 2
}

# ---------------------------------------------------------------------------
# Mode 1 — Edit / Write (validate new content)
# ---------------------------------------------------------------------------

handle_edit_or_write() {
  local file_path="${CLAUDE_TOOL_INPUT_file_path:-}"
  [ -z "$file_path" ] && exit 0

  # Only check files that look like source code or tests.
  case "$file_path" in
    *.ts|*.tsx|*.js|*.jsx|*.mjs|*.cjs|*.py|*.go|*.rs|*.java|*.kt|*.html|*.htm|*.vue|*.svelte) ;;
    *) exit 0 ;;
  esac

  # Determine the new content. Write provides full content; Edit provides new_string.
  local new_content="${CLAUDE_TOOL_INPUT_content:-${CLAUDE_TOOL_INPUT_new_string:-}}"
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
    if ! printf '%s\n' "$known_ids" | grep -qx "$id"; then
      unknown="${unknown}${unknown:+, }${id}"
    fi
  done <<< "$cited_ids"

  if [ -n "$unknown" ]; then
    block_with_message "spec-coherence-guard: BLOCKED edit to $file_path

  Unknown spec IDs cited via @spec: $unknown

  These IDs are not defined in docs/specs/.
  Fix one of:
    - Add the missing IDs to docs/specs/<segment>-specs.md
    - Correct the @spec annotation to cite an existing ID
    - Remove the @spec annotation if this code does not implement product behavior

  Run /uncle-dev-spec-scan for the full coherence report."
  fi
  exit 0
}

# ---------------------------------------------------------------------------
# Mode 2 — Bash (intercept git commit, run full scanner)
# ---------------------------------------------------------------------------

handle_bash() {
  local cmd="${CLAUDE_TOOL_INPUT_command:-}"
  [ -z "$cmd" ] && exit 0

  # Only fire for commit-like commands.
  case "$cmd" in
    *"git commit"*) ;;
    *) exit 0 ;;
  esac

  # Locate the scanner. Try installed plugin path first, then sibling repo path.
  local scanner=""
  for candidate in \
    "${CLAUDE_PLUGIN_ROOT:-}/skills/uncle-dev-spec-annotations/scan-spec-coherence.py" \
    "$HOME/.claude/plugins/cache/uncle-dev-agent-skills/uncle-dev-agent-skills/skills/uncle-dev-spec-annotations/scan-spec-coherence.py" \
    "$REPO_ROOT/skills/uncle-dev-spec-annotations/scan-spec-coherence.py"
  do
    if [ -n "$candidate" ] && [ -f "$candidate" ]; then
      scanner="$candidate"
      break
    fi
  done
  [ -z "$scanner" ] && exit 0

  local report
  report="$(python3 "$scanner" --root "$REPO_ROOT" --no-tree-sitter --quiet --format text 2>&1)"
  local rc=$?

  if [ $rc -ne 0 ]; then
    block_with_message "spec-coherence-guard: BLOCKED git commit

$(python3 "$scanner" --root "$REPO_ROOT" --no-tree-sitter --format text 2>&1)

  Fix the orphan @spec citations above before committing.
  Run /uncle-dev-spec-scan locally to iterate."
  fi
  exit 0
}

# ---------------------------------------------------------------------------
# Dispatch
# ---------------------------------------------------------------------------

TOOL_NAME="${CLAUDE_TOOL_NAME:-}"
case "$TOOL_NAME" in
  Edit|Write) handle_edit_or_write ;;
  Bash) handle_bash ;;
  *) exit 0 ;;
esac
