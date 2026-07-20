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

# Portable SHA-256 hash of a single file.  Returns the hex digest only.
# Precedence: sha256sum (Linux / GNU coreutils) → shasum -a 256 (macOS).
# Fails with a clear error if neither is present (R-3.3 portability binding).
sha256_of() {
  local path="$1"
  if command -v sha256sum >/dev/null 2>&1; then
    sha256sum "$path" | awk '{print $1}'
  elif command -v shasum >/dev/null 2>&1; then
    shasum -a 256 "$path" | awk '{print $1}'
  else
    echo "ERROR: neither sha256sum nor shasum found; cannot verify content hashes" >&2
    return 1
  fi
}

# Content-hash drift check: compare SHA-256 of each commands/*.md against
# its counterpart in plugins/uncle-dev/commands/*.md (R-3.3, R-3.5).
# Reports every diverging file and suggests running scripts/sync-plugin.sh.
check_command_content_hashes() {
  local canon_file fork_file name canon_hash fork_hash
  local drift_found=0
  for canon_file in "${ASSET_COMMANDS_ROOT}"/*.md; do
    [[ -e "$canon_file" ]] || continue
    name="$(basename "$canon_file")"
    fork_file="${PLUGIN_COMMANDS_DIR}/${name}"
    if [[ ! -f "$fork_file" ]]; then
      # Missing-file drift is already caught by compare_sets; skip here.
      continue
    fi
    canon_hash="$(sha256_of "$canon_file")" || return 1
    fork_hash="$(sha256_of "$fork_file")"   || return 1
    if [[ "$canon_hash" != "$fork_hash" ]]; then
      divergence "${name}: content hash mismatch — run scripts/sync-plugin.sh"
      drift_found=$((drift_found + 1))
    fi
  done
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

# --- R-3.3 / R-3.5: content-hash drift check --------------------------------
# Detects stale bytes in the fork even when the filename set matches.
# Fails naming the offending file and suggests running scripts/sync-plugin.sh.

check_command_content_hashes

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

# --- R-8.7: plugin-cache path recurrence guards (Unit 08) ------------------
# Both must return empty; failure names the offending file.

echo "── plugin-cache path recurrence guards (R-8.7) ───────────────────────"

# Pattern built via concatenation so this file does not match its own guard.
_mkt="uncle-dev-agent-skills"
_doubled_pat="${_mkt}/${_mkt}"
doubled_segment_hits="$(grep -rn "$_doubled_pat" commands/ hooks/ skills/ 2>/dev/null || true)"
if [[ -n "$doubled_segment_hits" ]]; then
  divergence "doubled cache segment '${_doubled_pat}' found — run Unit 08 remediation:
${doubled_segment_hits}"
else
  echo "  [OK] no doubled cache segment"
fi

hardcoded_version_hits="$(grep -rn 'cache/.*/[0-9]\.[0-9]' commands/ hooks/ 2>/dev/null || true)"
if [[ -n "$hardcoded_version_hits" ]]; then
  divergence "hardcoded version string in cache path found — replace with sort -V | tail -1:
${hardcoded_version_hits}"
else
  echo "  [OK] no hardcoded version strings in cache paths"
fi

# --- R-7.8: declared-vs-actual command count in marketplace.json ----------
# The metadata.commands_count field in .claude-plugin/marketplace.json must
# match the actual number of *.md files in commands/.  Degrades gracefully
# when jq is absent (skips the check with a notice rather than failing).

echo "── marketplace command count check (R-7.8) ───────────────────────────"

if command -v jq >/dev/null 2>&1; then
  declared_commands="$(jq -r '.metadata.commands_count // empty' "$MARKETPLACE" 2>/dev/null || true)"
  if [[ -z "$declared_commands" ]]; then
    echo "  NOTICE: metadata.commands_count not declared in marketplace.json — skipping count check."
  elif [[ "$declared_commands" != "$COMMAND_COUNT" ]]; then
    divergence "marketplace.json commands_count is ${declared_commands}, actual commands/ count is ${COMMAND_COUNT} — update metadata.commands_count"
    echo "  Expected: ${COMMAND_COUNT}  Declared: ${declared_commands}"
  else
    echo "  [OK] marketplace commands_count matches actual (${COMMAND_COUNT})"
  fi
else
  echo "  NOTICE: jq not available — skipping marketplace command count check."
fi

# --- R-7.4: plan-reviewer phantom check -----------------------------------
# grep -rn 'plan-reviewer' agents/ skills/ commands/ must return empty after
# remediation (or match only a real agent file).

echo "── plan-reviewer phantom check (R-7.4) ──────────────────────────────"
plan_reviewer_hits="$(grep -rn 'plan-reviewer' agents/ skills/ commands/ 2>/dev/null || true)"
if [[ -n "$plan_reviewer_hits" ]]; then
  divergence "phantom 'plan-reviewer' reference found — repoint to an existing agent:
${plan_reviewer_hits}"
else
  echo "  [OK] no phantom plan-reviewer references"
fi

# --- R-10.1: generated-inventory staleness check --------------------------
# Verifies that <!-- BEGIN/END GENERATED: ... --> blocks in CLAUDE.md are
# current. Regenerates into a temp copy and diffs; fails if stale.
# Skips if gen-inventory.sh is absent (non-fatal notice).

echo "── generated-inventory staleness check (R-10.1) ─────────────────────"
if [[ -f "${SCRIPT_DIR}/gen-inventory.sh" ]]; then
  if bash "${SCRIPT_DIR}/gen-inventory.sh" --check 2>/dev/null; then
    : # gen-inventory.sh --check prints its own [OK] line
  else
    divergence "CLAUDE.md generated blocks are stale — run: bash scripts/gen-inventory.sh"
  fi
else
  echo "  NOTICE: scripts/gen-inventory.sh not found — skipping inventory staleness check."
fi

# --- R-10.3: dead-link checker for relative .md paths in skills/ and commands/ ---
# Targets Finding B: dead references to `references/` subdirs and docs moved to
# docs/originals/. Checks only paths that are clearly plugin-internal (start with
# a known repo prefix: skills/, commands/, docs/, hooks/, scripts/, agents/, ./).
# Skips template paths, runtime/user-project dirs, and example filenames.

echo "── dead-link checker (R-10.3) ────────────────────────────────────────"
dead_link_failures=0

while IFS=: read -r src_file link_path; do
  # Only check paths that are clearly plugin-internal references.
  # Must start with a known repo prefix or ./ (explicit current-dir).
  case "$link_path" in
    skills/*|commands/*|hooks/*|scripts/*|agents/*|./*)
      : ;;  # plugin-internal — proceed
    docs/*)
      # docs/ has both plugin-internal subdirs (originals, hld, lld, ears, audit,
      # reference, tasks, drafts, v2, improved) AND project-level paths like
      # docs/ubiquitous-language.md, docs/high-level-design.md, docs/stakeholders.md
      # that users create in their own repos. Only flag docs/SUBDIR/... where SUBDIR
      # is a plugin-internal subdirectory.
      _docs_subdir="${link_path#docs/}"
      _docs_subdir="${_docs_subdir%%/*}"
      case "$_docs_subdir" in
        originals|hld|lld|ears|audit|reference|tasks|drafts|v2|improved|README*)
          : ;;  # plugin-internal docs dir — proceed
        *)
          continue  # project-level doc path — skip
          ;;
      esac
      ;;
    *)
      continue  # skip: project-level, example, or bare filename
      ;;
  esac

  # Skip template/placeholder paths (contain < > [ ] @ { } or *).
  case "$link_path" in
    *'<'*|*'>'*|*'*'*|*'['*|*']'*|*'@'*|*'{'*|*'}'*) continue ;;
  esac

  # Skip AGENTS.md example paths (used in agents-md-guide for illustration).
  case "$link_path" in
    *AGENTS.md) continue ;;
  esac

  # Resolve the link relative to the directory of the source file.
  src_dir="$(dirname "$src_file")"
  if [[ "$link_path" == ./* ]]; then
    resolved="${src_dir}/${link_path#./}"
  else
    # Repo-root-relative (skills/foo/bar.md, docs/originals/x.md, etc.)
    resolved="${REPO_ROOT}/${link_path}"
  fi
  if [[ ! -f "$resolved" ]]; then
    divergence "dead link in ${src_file}: '${link_path}' → '${resolved}' not found"
    dead_link_failures=$((dead_link_failures + 1))
  fi
done < <(
  # Extract relative .md paths from backtick references in skills/ and commands/.
  # Pattern: `path/to/something.md` (not http, not absolute).
  grep -rn --include="*.md" -o '`[^`]*\.md`' skills/ commands/ 2>/dev/null \
    | grep -v 'http' \
    | sed "s/\`//g" \
    | while IFS=: read -r file lineno content; do
        echo "${file}:${content}"
      done
)
if [[ "$dead_link_failures" -eq 0 ]]; then
  echo "  [OK] all relative .md references in skills/ and commands/ resolve"
fi

# --- R-10.6 / R-1.12: bash-3.2 compliance sweep ---------------------------
# hooks/ and scripts/ must contain no active bash 4+ features:
#   declare -A, mapfile, readarray, ${var,,}
# Lines that merely mention these in comments or documentation are excluded.

echo "── bash-3.2 compliance sweep (R-10.6 / R-1.12) ─────────────────────"
# Scan for actual bash 4+ feature *usage* (not mentions in comments or grep patterns).
# Exclude: pure comment lines, grep -e pattern arguments, echo/printf strings,
# and the sweep section itself (self-referential).
bash4_hits="$(grep -rn \
  -e 'declare -A' \
  -e 'mapfile ' \
  -e 'readarray ' \
  -e '\${[a-zA-Z_][a-zA-Z_0-9]*,,}' \
  hooks/ scripts/ 2>/dev/null \
  | grep -v " *#" \
  | grep -v "grep\b" \
  | grep -v "echo \|printf " \
  | grep -v "-e '" \
  || true)"
if [[ -n "$bash4_hits" ]]; then
  divergence "bash 4+ feature found in hooks/ or scripts/ (R-1.12):
${bash4_hits}"
else
  echo "  [OK] no bash 4+ features in hooks/ or scripts/"
fi

# --- verdict ---------------------------------------------------------------

echo "Canonical counts: ${SKILL_COUNT} skills, ${COMMAND_COUNT} commands, $(canonical_agents | grep -c . || true) agents."
if [[ "$FAILURES" -gt 0 ]]; then
  echo "FAIL: ${FAILURES} divergence(s) detected. Reconcile the copies above against scripts/lib/manifest.sh." >&2
  exit 1
fi
echo "OK: all copies match the canonical manifest."
