#!/usr/bin/env bash
# check-manifest.sh — drift guard.
#
# Fails (exit non-zero) when any hand-maintained copy of the asset inventory
# diverges from the canonical roots declared in scripts/lib/manifest.sh:
#   - .claude-plugin/marketplace.json  skills + agents lists
#   - plugins/uncle-dev/commands/      command file set
#   - README.md                        skill count + command count
#
# Canonical source of truth: scripts/lib/manifest.sh (ASSET_*_ROOT). This guard
# does NOT introduce a second source of truth — it reads those roots and compares.
# Intentional exclusions live in scripts/lib/manifest-allowlist.sh and are printed.
#
# Requirements: R-1.1..R-1.8 (docs/ears/ponytail-patterns-adoption.md, Unit 1).

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"

# shellcheck source=lib/manifest.sh
source "${SCRIPT_DIR}/lib/manifest.sh"
# shellcheck source=lib/manifest-allowlist.sh
source "${SCRIPT_DIR}/lib/manifest-allowlist.sh"
# shellcheck source=lib/instruction-adapter.sh
source "${SCRIPT_DIR}/lib/instruction-adapter.sh"

# Host-correct relative paths of every generated always-on instruction adapter
# (R-8.2). Kept in sync with install-plugin.sh's install_* targets. The guard
# (R-8.3) asserts each adapter's body equals the canonical AGENTS.md-derived
# content from lib/instruction-adapter.sh, so any hand-edit fails the suite.
ADAPTER_RULE_PATHS=(
  ".github/copilot-instructions.md"
  ".clinerules/uncle-dev.md"
  ".kiro/steering/uncle-dev.md"
  ".pi/rules/uncle-dev.md"
)

# --adapters <dir>: drift-guard mode for generated instruction adapters.
# Scans a target workspace produced by install-plugin.sh and asserts each
# present always-on adapter matches the AGENTS.md-derived body. Exits non-zero
# with a per-adapter message on any divergence (hand-edit). The default
# (no args) invocation never enters this mode and stays green on a clean tree.
if [[ "${1:-}" == "--adapters" ]]; then
  ADAPTER_DIR="${2:-}"
  [[ -n "$ADAPTER_DIR" ]] || { echo "Usage: check-manifest.sh --adapters <target-dir>" >&2; exit 2; }
  [[ -d "$ADAPTER_DIR" ]] || { echo "DRIFT: adapter dir not found: $ADAPTER_DIR" >&2; exit 1; }

  expected="$(adapter_rule_body "${REPO_ROOT}/AGENTS.md")"
  adapter_failures=0
  found=0
  echo "── instruction-adapter drift guard (R-8.3) ───────────────────"
  echo "Canonical rule source: AGENTS.md (derived via lib/instruction-adapter.sh)"
  for rel in "${ADAPTER_RULE_PATHS[@]}"; do
    path="${ADAPTER_DIR}/${rel}"
    [[ -f "$path" ]] || continue
    found=$((found + 1))
    if printf '%s' "$expected" | cmp -s - "$path"; then
      echo "  [OK] ${rel}"
    else
      echo "DRIFT: ${rel}: body diverges from AGENTS.md-derived always-on rule (hand-edit?)." >&2
      adapter_failures=$((adapter_failures + 1))
    fi
  done
  if [[ "$found" -eq 0 ]]; then
    echo "  (no instruction adapters present under ${ADAPTER_DIR})"
  fi
  if [[ "$adapter_failures" -gt 0 ]]; then
    echo "FAIL: ${adapter_failures} adapter(s) diverge from canonical AGENTS.md." >&2
    exit 1
  fi
  echo "OK: all present instruction adapters match canonical AGENTS.md."
  exit 0
fi

cd "${REPO_ROOT}"

MARKETPLACE=".claude-plugin/marketplace.json"
PLUGIN_COMMANDS_DIR="plugins/uncle-dev/commands"
README="README.md"

FAILURES=0
divergence() {
  FAILURES=$((FAILURES + 1))
  echo "DRIFT: $*" >&2
}

# --- helpers ---------------------------------------------------------------

# in_list <needle> <haystack...> -> 0 if present
in_list() {
  local needle="$1"; shift
  local item
  for item in "$@"; do
    [[ "$item" == "$needle" ]] && return 0
  done
  return 1
}

# Compute canonical skill dirs (bare names) minus allowlist, sorted.
canonical_skills() {
  local d name
  for d in "${ASSET_SKILLS_ROOT}"/*/SKILL.md; do
    [[ -e "$d" ]] || continue
    name="$(basename "$(dirname "$d")")"
    in_list "$name" "${ALLOWLIST_SKILLS[@]:-}" && continue
    echo "$name"
  done | sort
}

# Canonical agents (bare file names with .md), sorted.
canonical_agents() {
  local f
  for f in "${ASSET_AGENTS}"/*.md; do
    [[ -e "$f" ]] || continue
    basename "$f"
  done | sort
}

# Canonical commands (file names with .md) minus allowlist, sorted.
canonical_commands() {
  local f name
  for f in "${ASSET_COMMANDS_ROOT}"/*.md; do
    [[ -e "$f" ]] || continue
    name="$(basename "$f")"
    in_list "$name" "${ALLOWLIST_COMMANDS[@]:-}" && continue
    echo "$name"
  done | sort
}

# Marketplace skill names (strip ./skills/ prefix), sorted.
marketplace_skills() {
  python3 - "$MARKETPLACE" <<'PY'
import json, sys, os
d = json.load(open(sys.argv[1]))
p = d["plugins"][0]
for s in p.get("skills", []):
    print(os.path.basename(s.rstrip("/")))
PY
}

# Marketplace agent file names (basename), sorted.
marketplace_agents() {
  python3 - "$MARKETPLACE" <<'PY'
import json, sys, os
d = json.load(open(sys.argv[1]))
p = d["plugins"][0]
for a in p.get("agents", []):
    print(os.path.basename(a.rstrip("/")))
PY
}

# Plugin command file names (basename), sorted.
plugin_commands() {
  local f
  for f in "${PLUGIN_COMMANDS_DIR}"/*.md; do
    [[ -e "$f" ]] || continue
    basename "$f"
  done | sort
}

# Compare two sorted name-streams; report missing/extra against canonical.
# args: <label> <canonical-cmd> <copy-cmd>
compare_sets() {
  local label="$1" canon_fn="$2" copy_fn="$3"
  local tmp_canon tmp_copy missing extra
  tmp_canon="$(mktemp)"; tmp_copy="$(mktemp)"
  "$canon_fn" > "$tmp_canon"
  "$copy_fn" | sort > "$tmp_copy"
  missing="$(comm -23 "$tmp_canon" "$tmp_copy" | paste -sd ',' -)"
  extra="$(comm -13 "$tmp_canon" "$tmp_copy" | paste -sd ',' -)"
  rm -f "$tmp_canon" "$tmp_copy"
  if [[ -n "$missing" ]]; then
    divergence "${label}: missing from copy: ${missing}"
  fi
  if [[ -n "$extra" ]]; then
    divergence "${label}: extra in copy (not in canonical minus allowlist): ${extra}"
  fi
}

# Extract the integer the README claims for a noun ("skills" | "commands").
# Robust: finds the first "<N> <noun>" pattern (case-insensitive).
readme_count() {
  local noun="$1"
  python3 - "$README" "$noun" <<'PY'
import re, sys
text = open(sys.argv[1], encoding="utf-8").read()
noun = sys.argv[2]
m = re.search(r"(\d+)\s+" + re.escape(noun), text, re.IGNORECASE)
print(m.group(1) if m else "")
PY
}

# --- print honored allowlist (R-1.8) --------------------------------------

echo "── manifest drift guard ──────────────────────────────────────"
echo "Canonical roots (scripts/lib/manifest.sh):"
echo "  skills=${ASSET_SKILLS_ROOT}/  agents=${ASSET_AGENTS}/  commands=${ASSET_COMMANDS_ROOT}/"
echo "Honored allowlist (scripts/lib/manifest-allowlist.sh):"
if [[ "${#ALLOWLIST_SKILLS[@]:-0}" -eq 0 && "${#ALLOWLIST_COMMANDS[@]:-0}" -eq 0 ]]; then
  echo "  (empty — no intentional exclusions)"
else
  [[ "${#ALLOWLIST_SKILLS[@]:-0}" -gt 0 ]]   && echo "  skills excluded:   ${ALLOWLIST_SKILLS[*]}"
  [[ "${#ALLOWLIST_COMMANDS[@]:-0}" -gt 0 ]] && echo "  commands excluded: ${ALLOWLIST_COMMANDS[*]}"
fi
echo "───────────────────────────────────────────────────────────────"

# --- counts ----------------------------------------------------------------

SKILL_COUNT="$(canonical_skills | grep -c . || true)"
COMMAND_COUNT="$(canonical_commands | grep -c . || true)"

# --- R-1.2: marketplace skills + agents ------------------------------------

compare_sets "marketplace.json skills" canonical_skills marketplace_skills
compare_sets "marketplace.json agents" canonical_agents marketplace_agents

# --- R-1.4: plugin commands ------------------------------------------------

compare_sets "plugins/uncle-dev/commands" canonical_commands plugin_commands

# --- R-1.3: README counts --------------------------------------------------

readme_skills="$(readme_count "skills")"
readme_commands="$(readme_count "commands")"

if [[ -z "$readme_skills" ]]; then
  divergence "README.md: no skill count found (expected '${SKILL_COUNT} skills')"
elif [[ "$readme_skills" != "$SKILL_COUNT" ]]; then
  divergence "README.md: skill count is ${readme_skills}, canonical is ${SKILL_COUNT}"
fi

if [[ -z "$readme_commands" ]]; then
  divergence "README.md: no command count found (expected '${COMMAND_COUNT} commands')"
elif [[ "$readme_commands" != "$COMMAND_COUNT" ]]; then
  divergence "README.md: command count is ${readme_commands}, canonical is ${COMMAND_COUNT}"
fi

# --- verdict ---------------------------------------------------------------

echo "Canonical counts: ${SKILL_COUNT} skills, ${COMMAND_COUNT} commands, $(canonical_agents | grep -c . || true) agents."
if [[ "$FAILURES" -gt 0 ]]; then
  echo "FAIL: ${FAILURES} divergence(s) detected. Reconcile the copies above against scripts/lib/manifest.sh." >&2
  exit 1
fi
echo "OK: all copies match the canonical manifest."
