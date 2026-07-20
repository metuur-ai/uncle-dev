#!/bin/bash
# Round-trip test: plan template → next-task parser (Unit 06).
#
# Acceptance (EARS Unit 6, R-6.1, R-6.2, R-6.3, R-6.9):
#   (a) Generate a plan file from the fixed template with ≥2 stories and
#       [mutex:] / [depends:] annotations — matching what /uncle-dev-plan now emits.
#   (b) Run the next-task parsing logic against that file.
#   (c) Assert both story IDs match the grammar ^[0-9]+(\.[0-9]+)*$ (R-6.1).
#   (d) Assert the mutex story does NOT appear in the ready set when its
#       dependency is unresolved (R-6.3 mutex semantics).
#
# The "parsing logic" is the bash-native subset described in
# skills/uncle-dev-next-task/parsing-and-annotations.md:
#   - Story header regex:  "^### Story ([0-9]+(\.[0-9]+)*): "
#   - Annotations line:    "^\*\*Annotations:\*\*"
#   - mutex key:           "[mutex: Story-X.Y]"
#   - depends key:         "[depends: Story-X.Y]"
#   - Story is complete when it has no unchecked "- [ ]" acceptance boxes
#   - Ready set: unchecked story whose deps are all complete and
#     whose mutex partner is NOT also unresolved
#
# Compatibility: bash 3.2 (macOS system bash), set -uo pipefail.
# Uses only space-delimited string variables — no associative arrays, no mapfile.
# grep calls use -e pattern or -- separator where pattern starts with a dash.
set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

PASS=0; FAIL=0
ok()   { echo "  PASS: $*"; ((PASS++)) || true; }
bad()  { echo "  FAIL: $*"; ((FAIL++)) || true; }

echo "── Unit 06: plan→next-task round-trip ────────────────────"

# ── (a) Generate a plan file from the fixed template ─────────────────────────
TMPROOT="$(mktemp -d)"
trap 'rm -rf "${TMPROOT}"' EXIT

PLAN_FILE="${TMPROOT}/tasks.md"

# Story 1.1 is pending (has unchecked acceptance criteria).
# Story 1.2 depends on Story-1.1 and has a [mutex: Story-1.1] annotation.
# While Story-1.1 is unresolved, Story-1.2 must not be in the ready set.
cat > "${PLAN_FILE}" << 'PLAN_EOF'
# Feature: Config Loader — Tasks

## Stories

### Story 1.1: Add base config module

**Why:** The config loader is needed by all other modules; it must exist first.

**Outcome:** A `config.ts` module that reads environment variables and returns typed config.

**Acceptance criteria:**
- [ ] `config.ts` exports a `loadConfig()` function
- [ ] Unit tests cover missing-env-var error path

**Verification:**
- [ ] `npm test -- config` passes
- [ ] `npm run build` succeeds

**Dependencies:** None

**Annotations:** [files: src/config.ts, src/config.test.ts] [mutex: none] [depends: none]

### Story 1.2: Wire config into logger middleware

**Why:** Logger must read log level from config; this story wires the two together.

**Outcome:** `logger.ts` reads its `LOG_LEVEL` from `loadConfig()` instead of `process.env`.

**Acceptance criteria:**
- [ ] `logger.ts` imports `loadConfig` and reads `LOG_LEVEL` from it
- [ ] Integration test verifies logger respects config change at startup

**Verification:**
- [ ] `npm test -- logger` passes
- [ ] `npm run build` succeeds

**Dependencies:** Story 1.1

**Annotations:** [files: src/logger.ts, src/logger.test.ts] [mutex: Story-1.1] [depends: Story-1.1]
PLAN_EOF

if [[ ! -f "${PLAN_FILE}" ]]; then
  bad "plan file not created at ${PLAN_FILE}"
  echo ""; echo "  PASS: ${PASS}  FAIL: ${FAIL}"; exit 1
fi
ok "plan file generated from fixed template"

# ── (b)+(c) Parse story IDs and verify grammar ────────────────────────────────
# Extract IDs into a space-delimited string (avoids bash 3.2 array set -u issues)
STORY_IDS_STR=""
while IFS= read -r line; do
  if echo "${line}" | grep -qE '^### Story [0-9]+(\.[0-9]+)*: '; then
    id="$(echo "${line}" | sed 's/^### Story \([0-9.]*\):.*/\1/')"
    STORY_IDS_STR="${STORY_IDS_STR} ${id}"
  fi
done < "${PLAN_FILE}"
STORY_IDS_STR="$(echo "${STORY_IDS_STR}" | sed 's/^ //')"

STORY_COUNT=0
for id in ${STORY_IDS_STR:-}; do
  STORY_COUNT=$((STORY_COUNT + 1))
done

if [[ "${STORY_COUNT}" -ge 2 ]]; then
  ok "plan file contains ${STORY_COUNT} stories (≥2 required)"
else
  bad "plan file must contain ≥2 stories; found ${STORY_COUNT}"
fi

# (c) Verify each extracted ID matches the grammar ^[0-9]+(\.[0-9]+)*$
for id in ${STORY_IDS_STR:-}; do
  if echo "${id}" | grep -qE '^[0-9]+(\.[0-9]+)*$'; then
    ok "story ID '${id}' matches grammar ^[0-9]+(\\.[0-9]+)*\$ (R-6.1)"
  else
    bad "story ID '${id}' does NOT match grammar ^[0-9]+(\\.[0-9]+)*\$ (R-6.1)"
  fi
done

# ── Verify Annotations: line is present in the generated file (R-6.2) ─────────
ANNOTATION_COUNT="$(grep -cE '^\*\*Annotations:\*\*' "${PLAN_FILE}" || true)"
if [[ "${ANNOTATION_COUNT}" -ge 2 ]]; then
  ok "plan file has ${ANNOTATION_COUNT} **Annotations:** lines (one per story, R-6.2)"
else
  bad "plan file must have ≥2 **Annotations:** lines; found ${ANNOTATION_COUNT} (R-6.2)"
fi

# ── (b) Parse annotations for each story ─────────────────────────────────────
# Space-delimited "ID:value" token strings — bash 3.2 safe, no associative arrays.
declare_story_ids=""
declare_story_deps=""
declare_story_mutex=""
declare_story_complete=""

current_id=""
story_unchecked=0

while IFS= read -r line; do
  # Detect new story header — finalize previous story before switching
  if echo "${line}" | grep -qE '^### Story [0-9]+(\.[0-9]+)*: '; then
    if [[ -n "${current_id}" ]]; then
      if [[ "${story_unchecked}" -eq 0 ]]; then
        declare_story_complete="${declare_story_complete} ${current_id}:yes"
      else
        declare_story_complete="${declare_story_complete} ${current_id}:no"
      fi
    fi
    current_id="$(echo "${line}" | sed 's/^### Story \([0-9.]*\):.*/\1/')"
    declare_story_ids="${declare_story_ids} ${current_id}"
    story_unchecked=0
    continue
  fi

  if [[ -z "${current_id}" ]]; then
    continue
  fi

  # Count unchecked acceptance criteria boxes.
  # Use -e flag form to avoid BSD grep treating '- [ ]' pattern as flags.
  if echo "${line}" | grep -qF -e '- [ ]'; then
    story_unchecked=1
  fi

  # Parse Annotations line
  if echo "${line}" | grep -qE '^\*\*Annotations:\*\*'; then
    # Extract depends: value; strip Story- prefix
    dep_val="none"
    if echo "${line}" | grep -qE '\[depends: '; then
      dep_val="$(echo "${line}" | sed 's/.*\[depends: *\([^]]*\)\].*/\1/')"
      dep_val="$(echo "${dep_val}" | sed 's/Story-//g')"
    fi
    declare_story_deps="${declare_story_deps} ${current_id}:${dep_val}"

    # Extract mutex: value; strip Story- prefix
    mutex_val="none"
    if echo "${line}" | grep -qE '\[mutex: '; then
      mutex_val="$(echo "${line}" | sed 's/.*\[mutex: *\([^]]*\)\].*/\1/')"
      mutex_val="$(echo "${mutex_val}" | sed 's/Story-//g')"
    fi
    declare_story_mutex="${declare_story_mutex} ${current_id}:${mutex_val}"
  fi
done < "${PLAN_FILE}"

# Finalize the last story
if [[ -n "${current_id}" ]]; then
  if [[ "${story_unchecked}" -eq 0 ]]; then
    declare_story_complete="${declare_story_complete} ${current_id}:yes"
  else
    declare_story_complete="${declare_story_complete} ${current_id}:no"
  fi
fi

ok "parsed story metadata from plan file"

# ── Helpers: lookup and completeness check ────────────────────────────────────

# lookup <story-id> <space-delimited-"ID:val"-string>  → prints the value or "none"
lookup() {
  local story_id="$1"
  local data="$2"
  local token tid tval
  for token in ${data:-}; do
    tid="${token%%:*}"
    tval="${token#*:}"
    if [[ "${tid}" == "${story_id}" ]]; then
      echo "${tval}"
      return
    fi
  done
  echo "none"
}

# is_complete <story-id>  → returns 0 if complete, 1 otherwise
is_complete() {
  local sid="$1"
  local val
  val="$(lookup "${sid}" "${declare_story_complete}")"
  [[ "${val}" == "yes" ]]
}

# ── (d) Compute the ready set and verify mutex semantics (R-6.3) ──────────────
# Ready set pass 1: include unchecked stories whose deps are all complete.
READY_SET=""
for id in ${declare_story_ids:-}; do
  is_complete "${id}" && continue   # skip complete stories

  deps_val="$(lookup "${id}" "${declare_story_deps}")"
  deps_ok=1

  if [[ "${deps_val}" != "none" && "${deps_val}" != "" ]]; then
    # Comma-separated dep IDs; iterate with IFS trick (bash 3.2 safe)
    old_IFS="${IFS}"; IFS=','; set -- ${deps_val}; IFS="${old_IFS}"
    for dep in "$@"; do
      dep="$(echo "${dep}" | tr -d ' ')"
      if [[ -n "${dep}" && "${dep}" != "none" ]]; then
        if ! is_complete "${dep}"; then
          deps_ok=0
          break
        fi
      fi
    done
  fi

  if [[ "${deps_ok}" -eq 0 ]]; then
    continue  # blocked by unsatisfied dep
  fi

  READY_SET="${READY_SET} ${id}"
done

# Ready set pass 2: apply mutex filter — exclude stories whose mutex partner
# is not complete (unresolved dependency means the partner is still pending).
FINAL_READY=""
for id in ${READY_SET:-}; do
  mutex_val="$(lookup "${id}" "${declare_story_mutex}")"
  mutex_ok=1

  if [[ "${mutex_val}" != "none" && "${mutex_val}" != "" ]]; then
    old_IFS="${IFS}"; IFS=','; set -- ${mutex_val}; IFS="${old_IFS}"
    for m in "$@"; do
      m="$(echo "${m}" | tr -d ' ')"
      if [[ -n "${m}" && "${m}" != "none" ]]; then
        if ! is_complete "${m}"; then
          mutex_ok=0
          break
        fi
      fi
    done
  fi

  if [[ "${mutex_ok}" -eq 1 ]]; then
    FINAL_READY="${FINAL_READY} ${id}"
  fi
done

FINAL_READY="$(echo "${FINAL_READY}" | sed 's/^ *//' | sed 's/ *$//')"

# Assert Story 1.1 IS in the ready set (unchecked, no deps, no mutex partner)
if echo " ${FINAL_READY} " | grep -qE '(^| )1\.1( |$)'; then
  ok "Story 1.1 is in the ready set (unchecked, no deps, no mutex) (R-6.3)"
else
  bad "Story 1.1 should be in the ready set; ready set is: '${FINAL_READY}'"
fi

# Assert Story 1.2 is NOT in the ready set (dep 1.1 unresolved + mutex 1.1)
if echo " ${FINAL_READY} " | grep -qE '(^| )1\.2( |$)'; then
  bad "Story 1.2 must NOT be in the ready set when dep 1.1 is unresolved (R-6.3)"
else
  ok "Story 1.2 excluded from ready set — dep 1.1 unresolved, mutex holds (R-6.3)"
fi

# ── Verify audit grep checks from docs/audit/06-*.md Verification block ───────
REPO_ROOT="$(cd "${SCRIPT_DIR}/../.." && pwd)"

# No "## Story STORY-" in the planning skill (old h2 format must be gone, R-6.1)
OLD_STORY_HITS="$(grep -n '## Story STORY-' \
  "${REPO_ROOT}/skills/uncle-dev-planning-and-task-breakdown/SKILL.md" 2>/dev/null || true)"
if [[ -z "${OLD_STORY_HITS}" ]]; then
  ok "no '## Story STORY-' in planning skill template (R-6.1)"
else
  bad "planning skill still contains old '## Story STORY-' h2 format (R-6.1):"
  echo "${OLD_STORY_HITS}"
fi

# Annotations: present in the planning skill template (R-6.2)
ANNO_HITS="$(grep -n 'Annotations:' \
  "${REPO_ROOT}/skills/uncle-dev-planning-and-task-breakdown/SKILL.md" 2>/dev/null || true)"
if [[ -n "${ANNO_HITS}" ]]; then
  ok "**Annotations:** present in planning skill template (R-6.2)"
else
  bad "planning skill template has no **Annotations:** line (R-6.2)"
fi

# No handoff.md creation in commands/uncle-dev-spec.md (R-6.4)
HANDOFF_HITS="$(grep -n 'handoff\.md' \
  "${REPO_ROOT}/commands/uncle-dev-spec.md" 2>/dev/null || true)"
if [[ -z "${HANDOFF_HITS}" ]]; then
  ok "no handoff.md creation in commands/uncle-dev-spec.md (R-6.4)"
else
  bad "commands/uncle-dev-spec.md still references handoff.md (R-6.4):"
  echo "${HANDOFF_HITS}"
fi

# No non-conforming PF-001 change-ID example in next-task SKILL.md (R-6.6)
PF_HITS="$(grep -n 'PF-001' \
  "${REPO_ROOT}/skills/uncle-dev-next-task/SKILL.md" 2>/dev/null || true)"
if [[ -z "${PF_HITS}" ]]; then
  ok "no non-conforming 'PF-001' change-ID example in next-task skill (R-6.6)"
else
  bad "next-task SKILL.md still contains 'PF-001' non-conforming change-ID (R-6.6):"
  echo "${PF_HITS}"
fi

# MANUAL CHECK label present in ship command for EARS R-x.y (R-6.7)
MANUAL_HITS="$(grep -n 'MANUAL CHECK' \
  "${REPO_ROOT}/commands/uncle-dev-ship.md" 2>/dev/null || true)"
if [[ -n "${MANUAL_HITS}" ]]; then
  ok "ship command labels EARS R-x.y coverage as MANUAL CHECK (R-6.7)"
else
  bad "ship command must label EARS R-x.y coverage as MANUAL CHECK (R-6.7)"
fi

# ── Summary ───────────────────────────────────────────────────────────────────
echo ""
echo "── Unit 06 results: ${PASS} passed, ${FAIL} failed ──────────"
if [[ "${FAIL}" -gt 0 ]]; then
  exit 1
fi
exit 0
