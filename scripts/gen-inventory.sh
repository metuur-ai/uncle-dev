#!/usr/bin/env bash
# gen-inventory.sh — Generate canonical command/skills inventories into marked blocks.
#
# Writes two marked blocks:
#   <!-- BEGIN GENERATED: commands --> ... <!-- END GENERATED: commands -->
#   <!-- BEGIN GENERATED: skills-by-phase --> ... <!-- END GENERATED: skills-by-phase -->
#
# Targets: CLAUDE.md (both blocks), README.md (commands count line).
#
# Usage:
#   bash scripts/gen-inventory.sh [--check]
#
# Without --check: regenerates the blocks in-place (idempotent, deterministic).
# With    --check: regenerates into a temp buffer and fails with diff if stale.
#
# macOS bash 3.2 compatible. No mapfile, no declare -A, no ${var,,}.
# Requirements: R-10.1, R-10.10.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"

CLAUDE_MD="${REPO_ROOT}/CLAUDE.md"
COMMANDS_DIR="${REPO_ROOT}/commands"

CHECK_ONLY=0
if [[ "${1:-}" == "--check" ]]; then
  CHECK_ONLY=1
fi

# ---------------------------------------------------------------------------
# Build sorted command list from commands/*.md
# ---------------------------------------------------------------------------
build_commands_list() {
  local f name
  for f in "${COMMANDS_DIR}"/*.md; do
    [[ -e "$f" ]] || continue
    name="$(basename "$f" .md)"
    echo "/${name}"
  done | LC_ALL=C sort
}

# ---------------------------------------------------------------------------
# Build skills-by-phase block from current disk state.
# Phase assignments are defined here; skills not listed fall into "Support".
# Update this table when adding new phases or moving skills.
# ---------------------------------------------------------------------------
build_skills_phase_block() {
  # Collect all skills from disk (sorted).
  local all_skills
  all_skills="$(ls -1d "${REPO_ROOT}/skills"/*/SKILL.md 2>/dev/null \
    | while read -r p; do basename "$(dirname "$p")"; done \
    | LC_ALL=C sort)"

  # Phase assignments — edit this list when skills change phases.
  # Format: one entry per line: "skill-name PHASE"
  local assignments
  assignments="uncle-dev-acknowledge Define
uncle-dev-api-and-interface-design Build
uncle-dev-brownfield Brownfield
uncle-dev-browser-testing-with-devtools Verify
uncle-dev-business-observability Support
uncle-dev-changelog Ship
uncle-dev-ci-cd-and-automation Ship
uncle-dev-code-context Support
uncle-dev-code-review-and-quality Review
uncle-dev-context-engineering Build
uncle-dev-custom-me Maintain
uncle-dev-debug-error Verify
uncle-dev-deprecation-and-migration Ship
uncle-dev-design-architecture-docs Define
uncle-dev-dev-code-simplification Review
uncle-dev-documentation-and-adrs Ship
uncle-dev-feature-map Brownfield
uncle-dev-frontend-ui-engineering Build
uncle-dev-git-workflow-and-versioning Ship
uncle-dev-graphify-aware-analysis Support
uncle-dev-grill Define
uncle-dev-idea-refine Define
uncle-dev-incremental-implementation Build
uncle-dev-initiative-map Support
uncle-dev-knowledge-capture Capture
uncle-dev-knowledge-maintenance Maintain
uncle-dev-mutation-testing Verify
uncle-dev-next-task Support
uncle-dev-over-engineering-audit Support
uncle-dev-performance-optimization Review
uncle-dev-planning-and-task-breakdown Plan
uncle-dev-pre-mortem Support
uncle-dev-research Define
uncle-dev-security-and-hardening Review
uncle-dev-setup-local Support
uncle-dev-shipping-and-launch Ship
uncle-dev-source-driven-development Build
uncle-dev-spec-annotations Build
uncle-dev-spec-driven-development Define
uncle-dev-speech Ship
uncle-dev-test-driven-development Build
uncle-dev-ubiquitous-language Define
uncle-dev-using-agent-skills Support
uncle-dev-verbalized-sampling Define
uncle-dev-wrap Handoff
uncle-senior Evaluate"

  # Collect skills per phase using indexed arrays (bash 3.2 safe).
  local phases
  phases="Define Brownfield Evaluate Plan Build Verify Review Ship Capture Handoff Maintain Support"

  # We'll build per-phase lists by grep-filtering the assignments.
  local phase
  for phase in $phases; do
    local skills_in_phase
    skills_in_phase="$(printf '%s\n' "$assignments" \
      | grep " ${phase}$" \
      | awk '{print $1}' \
      | LC_ALL=C sort \
      | python3 -c 'import sys; print(", ".join(l.rstrip() for l in sys.stdin if l.strip()))')"

    # Also include any disk skills not assigned to any phase (catch-all into Support).
    if [[ "$phase" == "Support" ]]; then
      local assigned_all
      assigned_all="$(printf '%s\n' "$assignments" | awk '{print $1}' | LC_ALL=C sort)"
      local unassigned
      unassigned="$(comm -23 \
        <(printf '%s\n' "$all_skills" | LC_ALL=C sort) \
        <(printf '%s\n' "$assigned_all"))"
      if [[ -n "$unassigned" ]]; then
        local extra
        extra="$(printf '%s\n' "$unassigned" \
          | python3 -c 'import sys; print(", ".join(l.rstrip() for l in sys.stdin if l.strip()))')"
        if [[ -n "$skills_in_phase" ]]; then
          skills_in_phase="${skills_in_phase}, ${extra}"
        else
          skills_in_phase="$extra"
        fi
      fi
    fi

    [[ -n "$skills_in_phase" ]] && echo "**${phase}:** ${skills_in_phase}"
  done
}

# ---------------------------------------------------------------------------
# Replace a marked block in a file.
# Usage: replace_block <file> <marker-key> <new-content-lines>
# Content is read from stdin.
# ---------------------------------------------------------------------------
replace_block_in_file() {
  local file="$1"
  local key="$2"
  local new_content
  new_content="$(cat)"  # read from stdin

  local begin="<!-- BEGIN GENERATED: ${key} -->"
  local end="<!-- END GENERATED: ${key} -->"

  # Build the replacement using python3 (available everywhere; awk is too fragile for
  # multi-line replacements across variable block sizes).
  python3 - "$file" "$begin" "$end" "$new_content" <<'PY'
import sys

fpath, begin, end, new_content = sys.argv[1], sys.argv[2], sys.argv[3], sys.argv[4]
with open(fpath, encoding="utf-8") as f:
    text = f.read()

start_idx = text.find(begin)
end_idx   = text.find(end)
if start_idx == -1 or end_idx == -1:
    # Block not found: insert at end (should not happen in normal use).
    sys.exit(0)

before = text[:start_idx]
after  = text[end_idx + len(end):]
replacement = begin + "\n" + new_content + "\n" + end
with open(fpath, "w", encoding="utf-8") as f:
    f.write(before + replacement + after)
PY
}

# ---------------------------------------------------------------------------
# Main
# ---------------------------------------------------------------------------

CMD_LIST="$(build_commands_list)"
CMD_COUNT="$(printf '%s\n' "$CMD_LIST" | grep -c . || true)"

# Build commands block content.
CMD_BLOCK_CONTENT="commands/ → Slash commands (${CMD_COUNT} total): $(printf '%s\n' "$CMD_LIST" | python3 -c 'import sys; print(", ".join(l.rstrip() for l in sys.stdin if l.strip()))')"

# Build skills-by-phase block content.
PHASE_BLOCK_CONTENT="$(build_skills_phase_block)"

if [[ "$CHECK_ONLY" -eq 1 ]]; then
  # Check mode: regenerate into temp files and diff.
  FAIL=0
  TMP_CLAUDE="$(mktemp)"
  cp "$CLAUDE_MD" "$TMP_CLAUDE"

  printf '%s' "$CMD_BLOCK_CONTENT" | replace_block_in_file "$TMP_CLAUDE" "commands"
  printf '%s' "$PHASE_BLOCK_CONTENT" | replace_block_in_file "$TMP_CLAUDE" "skills-by-phase"

  if ! diff -q "$CLAUDE_MD" "$TMP_CLAUDE" >/dev/null 2>&1; then
    echo "STALE: CLAUDE.md generated blocks are out of date — run: bash scripts/gen-inventory.sh" >&2
    diff "$CLAUDE_MD" "$TMP_CLAUDE" >&2 || true
    FAIL=1
  else
    echo "  [OK] CLAUDE.md generated blocks are current"
  fi
  python3 -c "import os; os.remove('${TMP_CLAUDE}')" 2>/dev/null || true

  if [[ "$FAIL" -ne 0 ]]; then
    exit 1
  fi
  exit 0
fi

# Write mode: update in-place.
printf '%s' "$CMD_BLOCK_CONTENT" | replace_block_in_file "$CLAUDE_MD" "commands"
printf '%s' "$PHASE_BLOCK_CONTENT" | replace_block_in_file "$CLAUDE_MD" "skills-by-phase"

echo "gen-inventory: CLAUDE.md updated (${CMD_COUNT} commands, skills-by-phase refreshed)."
