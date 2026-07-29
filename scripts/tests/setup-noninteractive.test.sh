#!/bin/bash
# Tests for setup-project.sh non-interactive mode, the skill rename, the
# CLAUDE.md update guard, and agent_skills_root resolution.
#
# Acceptance: docs/ears/setup-noninteractive-and-skill-rename.md, Unit 7
# (R-7.1..R-7.16). IDs below are qualified with that slug because this repo also
# has an unrelated docs/ears/audit-remediation.md using R-x.y numbering.
#
# Two traps this suite must avoid, both of which would make it pass vacuously:
#
#   1. uncle-dev-config.sh resolves env -> session flag -> YAML -> default. The
#      tests export UNCLE_DEV_PREFERENCES_*, so any read-back must clear that
#      namespace or it echoes the value just supplied instead of the stored one.
#   2. Tool detection reads ~/.claude/plugins and aborts the whole run when
#      nothing is found, so HOME is stubbed rather than inherited.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/../.." && pwd)"
# Exercise the repository copy explicitly. The installed plugin cache may be
# byte-identical, which would make "did I test the repo or the install?"
# impossible to answer (R-7.11).
SETUP="${REPO_ROOT}/scripts/setup-project.sh"
CONFIG="${REPO_ROOT}/scripts/uncle-dev-config.sh"

PASS=0; FAIL=0
ok()   { echo "  PASS: $*"; ((PASS++)) || true; }
bad()  { echo "  FAIL: $*"; ((FAIL++)) || true; }

TMPROOT="$(mktemp -d)"
trap 'rm -rf "${TMPROOT}"' EXIT

# Stubbed HOME so tool detection finds Claude Code without depending on the host
# (R-7.8). scripts/tests/AGENTS.md forbids relying on a real $HOME.
FAKE_HOME="${TMPROOT}/home"
mkdir -p "${FAKE_HOME}/.claude/plugins"

checksum() {
  if command -v shasum >/dev/null 2>&1; then shasum "$1" | awk '{print $1}';
  else sha1sum "$1" | awk '{print $1}'; fi
}

# Read a stored preference through the helper, with the seeding variables and
# CLAUDE_PROJECT_DIR cleared so the file is what actually gets observed
# (R-7.12). Never parse the YAML directly — scripts/ is scanned by the
# single-reader boundary guard, and scripts/tests/ is inside it.
cfg() { # cfg PROJECT_DIR DOTTED_KEY
  ( cd "$1" && env \
      -u CLAUDE_PROJECT_DIR \
      -u UNCLE_DEV_PREFERENCES_SDD_MODE \
      -u UNCLE_DEV_PREFERENCES_SPEC_ANNOTATIONS \
      -u UNCLE_DEV_PREFERENCES_TDD_MODE \
      -u UNCLE_DEV_PREFERENCES_EXECUTION_PROFILE \
      -u UNCLE_DEV_PREFERENCES_GRAPHIFY \
      bash "${CONFIG}" "$2" "" 2>/dev/null || true )
}

# Full, valid preference set. execution_profile is deliberately 'fast' and
# tdd-mode 'lite' so at least one value differs from the interactive default,
# proving values are carried rather than defaulted (R-7.2).
FULL_ENV=(
  UNCLE_DEV_PREFERENCES_SDD_MODE=lid-ears
  UNCLE_DEV_PREFERENCES_SPEC_ANNOTATIONS=true
  UNCLE_DEV_PREFERENCES_TDD_MODE=lite
  UNCLE_DEV_PREFERENCES_EXECUTION_PROFILE=fast
  UNCLE_DEV_PREFERENCES_GRAPHIFY=false
)

run_setup() { # run_setup PROJECT_DIR "ENV=V ..." ARGS...
  local dir="$1" envs="$2"; shift 2
  local -a envarr
  # shellcheck disable=SC2206
  envarr=( ${envs} )
  ( cd "${dir}" && env HOME="${FAKE_HOME}" ${envarr[@]+"${envarr[@]}"} \
      bash "${SETUP}" "$@" </dev/null 2>&1 )
}

newdir() { local d; d="$(mktemp -d "${TMPROOT}/proj.XXXXXX")"; echo "${d}"; }

echo "── setup-noninteractive: non-interactive mode, rename, update guard ──"

# ── R-7.1 / R-7.2: first-time setup, stdin closed, values verbatim ────────────
# Also exercises the renamed template directory: this path is the only one that
# reads skills/uncle-dev-setup-local/uncle-dev-setup.template.yaml, so a missed
# rename shows up here and nowhere else.
D1="$(newdir)"
if run_setup "${D1}" "${FULL_ENV[*]}" --non-interactive >/dev/null 2>&1; then
  ok "first-time --non-interactive with stdin closed exits 0 (R-7.1)"
else
  bad "first-time --non-interactive failed (renamed template path? R-7.1)"
fi

for pair in "preferences.sdd_mode:lid-ears" "preferences.spec_annotations:true" \
            "preferences.tdd-mode:lite" "preferences.execution_profile:fast" \
            "preferences.graphify:false"; do
  key="${pair%%:*}"; want="${pair##*:}"
  got="$(cfg "${D1}" "${key}")"
  if [[ "${got}" == "${want}" ]]; then
    ok "${key} stored as '${want}'"
  else
    bad "${key} expected '${want}', reads '${got}'"
  fi
done

# ── R-7.3: fail-closed on a missing preference ───────────────────────────────
D2="$(newdir)"
PARTIAL="UNCLE_DEV_PREFERENCES_SDD_MODE=lid-ears UNCLE_DEV_PREFERENCES_SPEC_ANNOTATIONS=true UNCLE_DEV_PREFERENCES_EXECUTION_PROFILE=fast UNCLE_DEV_PREFERENCES_GRAPHIFY=false"
OUT="$(run_setup "${D2}" "${PARTIAL}" --non-interactive || true)"
RC=0; run_setup "${D2}" "${PARTIAL}" --non-interactive >/dev/null 2>&1 || RC=$?
[[ "${RC}" -ne 0 ]] \
  && ok "omitted preference exits non-zero (${RC}) (R-7.3)" \
  || bad "omitted preference exited 0"
echo "${OUT}" | grep -q 'UNCLE_DEV_PREFERENCES_TDD_MODE' \
  && ok "failure names the missing variable" \
  || bad "failure did not name the missing variable"
[[ ! -f "${D2}/.agents/uncle-dev-setup.yaml" ]] \
  && ok "nothing written when a preference is missing (R-7.3)" \
  || bad "config was written despite a missing preference"

# Invalid value.
D3="$(newdir)"
INVALID="UNCLE_DEV_PREFERENCES_SDD_MODE=lid-ears UNCLE_DEV_PREFERENCES_SPEC_ANNOTATIONS=true UNCLE_DEV_PREFERENCES_TDD_MODE=nonsense UNCLE_DEV_PREFERENCES_EXECUTION_PROFILE=fast UNCLE_DEV_PREFERENCES_GRAPHIFY=false"
RC=0; run_setup "${D3}" "${INVALID}" --non-interactive >/dev/null 2>&1 || RC=$?
[[ "${RC}" -ne 0 ]] \
  && ok "disallowed value exits non-zero (${RC}) (R-7.3)" \
  || bad "disallowed value exited 0"

# ── R-7.4: configured project runs with stdin closed, preferences unchanged ──
BEFORE="$(checksum "${D1}/.agents/uncle-dev-setup.yaml")"
if run_setup "${D1}" "${FULL_ENV[*]}" >/dev/null 2>&1; then
  ok "already-configured project exits 0 with stdin closed (R-7.4)"
else
  bad "already-configured project failed with stdin closed"
fi
for k in preferences.sdd_mode preferences.tdd-mode preferences.execution_profile; do
  [[ "$(cfg "${D1}" "${k}")" != "" ]] || bad "${k} lost after plain re-run"
done
[[ "$(cfg "${D1}" preferences.execution_profile)" == "fast" ]] \
  && ok "preferences preserved across a plain re-run (R-7.4)" \
  || bad "preferences changed on a plain re-run"

# ── R-7.9: --non-interactive refused against an existing config ──────────────
AFTER_SEED="$(checksum "${D1}/.agents/uncle-dev-setup.yaml")"
OUT="$(run_setup "${D1}" "${FULL_ENV[*]}" --non-interactive || true)"
RC=0; run_setup "${D1}" "${FULL_ENV[*]}" --non-interactive >/dev/null 2>&1 || RC=$?
[[ "${RC}" -ne 0 ]] \
  && ok "--non-interactive against an existing config exits non-zero (R-7.9)" \
  || bad "--non-interactive against an existing config exited 0"
echo "${OUT}" | grep -q -- '--update' \
  && ok "refusal names --update as the supported route" \
  || bad "refusal did not mention --update"
[[ "$(checksum "${D1}/.agents/uncle-dev-setup.yaml")" == "${AFTER_SEED}" ]] \
  && ok "config byte-unchanged after refusal (R-7.9)" \
  || bad "config mutated despite refusal"

# ── R-7.10: --update --non-interactive overwrites ────────────────────────────
CHANGED="UNCLE_DEV_PREFERENCES_SDD_MODE=openspec UNCLE_DEV_PREFERENCES_SPEC_ANNOTATIONS=false UNCLE_DEV_PREFERENCES_TDD_MODE=strict UNCLE_DEV_PREFERENCES_EXECUTION_PROFILE=strict UNCLE_DEV_PREFERENCES_GRAPHIFY=true"
if run_setup "${D1}" "${CHANGED}" --update --non-interactive >/dev/null 2>&1; then
  ok "--update --non-interactive exits 0 (R-7.10)"
else
  bad "--update --non-interactive failed"
fi
[[ "$(cfg "${D1}" preferences.tdd-mode)" == "strict" ]] \
  && ok "--update --non-interactive overwrote tdd-mode" \
  || bad "tdd-mode not overwritten by --update --non-interactive"
[[ "$(cfg "${D1}" preferences.sdd_mode)" == "openspec" ]] \
  && ok "--update --non-interactive overwrote sdd_mode" \
  || bad "sdd_mode not overwritten by --update --non-interactive"

# ── R-7.5: --help and unknown flag ───────────────────────────────────────────
HELP="$(bash "${SETUP}" --help 2>&1)" && HRC=0 || HRC=$?
[[ "${HRC}" -eq 0 ]] && ok "--help exits 0 (R-7.5)" || bad "--help exited ${HRC}"
echo "${HELP}" | grep -q -- '--non-interactive' \
  && ok "--help documents --non-interactive" \
  || bad "--help does not document --non-interactive"
[[ "$(echo "${HELP}" | grep -c 'UNCLE_DEV_PREFERENCES_')" -ge 5 ]] \
  && ok "--help documents all five variables" \
  || bad "--help does not list all five variables"
RC=0; bash "${SETUP}" --definitely-not-a-flag >/dev/null 2>&1 || RC=$?
[[ "${RC}" -ne 0 ]] && ok "unknown flag exits non-zero (R-7.5)" || bad "unknown flag exited 0"

# ── R-7.13 (Unit 2): the execution rule is stated in all three files ─────────
SKILL_MD="${REPO_ROOT}/skills/uncle-dev-setup-local/SKILL.md"
CMD_MD="${REPO_ROOT}/commands/uncle-dev-setup.md"
MIRROR_MD="${REPO_ROOT}/plugins/uncle-dev/commands/uncle-dev-setup.md"
MISSING=""
for f in "${SKILL_MD}" "${CMD_MD}" "${MIRROR_MD}"; do
  grep -q -- '--non-interactive' "${f}" || MISSING="${MISSING} ${f}"
done
[[ -z "${MISSING}" ]] \
  && ok "execution rule references --non-interactive in all three files (R-7.13)" \
  || bad "missing --non-interactive guidance in:${MISSING}"
cmp -s "${CMD_MD}" "${MIRROR_MD}" \
  && ok "command file and plugins/ mirror are byte-identical (R-7.13)" \
  || bad "command file and mirror have drifted"

# ── R-7.14 (Unit 4): agent_skills_root resolution ────────────────────────────
# A root that is NOT a checkout: it has skills/ but no scripts/install-claude.sh.
NONCHECKOUT="${TMPROOT}/notacheckout"
mkdir -p "${NONCHECKOUT}/scripts" "${NONCHECKOUT}/skills"
cp "${REPO_ROOT}/scripts/setup-project.sh" "${NONCHECKOUT}/scripts/"
cp "${REPO_ROOT}/scripts/uncle-dev-config.sh" "${NONCHECKOUT}/scripts/"
cp -R "${REPO_ROOT}/skills/uncle-dev-setup-local" "${NONCHECKOUT}/skills/"

D4="$(newdir)"
( cd "${D4}" && env HOME="${FAKE_HOME}" CLAUDE_PLUGIN_ROOT=/fake/plugin/root \
    ${FULL_ENV[@]+"${FULL_ENV[@]}"} bash "${SETUP}" --non-interactive </dev/null >/dev/null 2>&1 )
[[ "$(cfg "${D4}" tool.agent_skills_root)" == "${REPO_ROOT}" ]] \
  && ok "checkout outranks CLAUDE_PLUGIN_ROOT (R-7.14)" \
  || bad "checkout did not win: $(cfg "${D4}" tool.agent_skills_root)"

D5="$(newdir)"
( cd "${D5}" && env HOME="${FAKE_HOME}" CLAUDE_PLUGIN_ROOT=/fake/plugin/root \
    ${FULL_ENV[@]+"${FULL_ENV[@]}"} bash "${NONCHECKOUT}/scripts/setup-project.sh" \
    --non-interactive </dev/null >/dev/null 2>&1 )
[[ "$(cfg "${D5}" tool.agent_skills_root)" == "/fake/plugin/root" ]] \
  && ok "non-checkout falls back to CLAUDE_PLUGIN_ROOT (R-7.14)" \
  || bad "CLAUDE_PLUGIN_ROOT not used: $(cfg "${D5}" tool.agent_skills_root)"

D6="$(newdir)"
# 'env' requires its options before any NAME=VALUE assignment, so -u leads.
( cd "${D6}" && env -u CLAUDE_PLUGIN_ROOT HOME="${FAKE_HOME}" \
    ${FULL_ENV[@]+"${FULL_ENV[@]}"} bash "${NONCHECKOUT}/scripts/setup-project.sh" \
    --non-interactive </dev/null >/dev/null 2>&1 )
[[ "$(cfg "${D6}" tool.agent_skills_root)" == "${NONCHECKOUT}" ]] \
  && ok "no env falls back to the script's parent (R-7.14)" \
  || bad "parent fallback wrong: $(cfg "${D6}" tool.agent_skills_root)"

# A plain re-run must not repoint an existing value.
run_setup "${D6}" "${FULL_ENV[*]}" >/dev/null 2>&1 || true
[[ "$(cfg "${D6}" tool.agent_skills_root)" == "${NONCHECKOUT}" ]] \
  && ok "plain re-run preserves agent_skills_root (R-7.14)" \
  || bad "plain re-run repointed agent_skills_root"

# ── R-7.15 (Unit 6): --update preserves project content in CLAUDE.md ─────────
D7="$(newdir)"
run_setup "${D7}" "${FULL_ENV[*]}" --non-interactive >/dev/null 2>&1
python3 - "${D7}/CLAUDE.md" <<'PY'
import sys
p = sys.argv[1]
t = open(p).read()
t = t.replace("<!-- /uncle-dev -->", """
## Project House Rules
Sentinel prose that the script did not author.

<!-- BEGIN GENERATED: commands-table -->
| /sentinel | sentinel-skill |
<!-- END GENERATED: commands-table -->
<!-- /uncle-dev -->""")
open(p, "w").write(t + "\n## Trailing Sentinel\nmust remain last\n")
PY
run_setup "${D7}" "${CHANGED}" --update --non-interactive >/dev/null 2>&1
# The region's own line count legitimately changes (the openspec section is
# shorter than the lid-ears one), so absolute line numbers are not the test.
# What must hold is that the region stayed put instead of being removed and
# re-appended at end of file: trailing content must still follow the closer.
CLOSER_LINE="$(grep -n -- '<!-- /uncle-dev -->' "${D7}/CLAUDE.md" | cut -d: -f1)"
TRAILING_LINE="$(grep -n 'Trailing Sentinel' "${D7}/CLAUDE.md" | cut -d: -f1)"

grep -q 'Sentinel prose that the script did not author' "${D7}/CLAUDE.md" \
  && ok "--update preserves project prose inside the region (R-7.15)" \
  || bad "--update destroyed project prose"
grep -q 'BEGIN GENERATED: commands-table' "${D7}/CLAUDE.md" \
  && grep -q 'sentinel-skill' "${D7}/CLAUDE.md" \
  && ok "--update preserves a nested GENERATED block and its content (R-7.15)" \
  || bad "--update destroyed the nested GENERATED block"
[[ -n "${CLOSER_LINE}" ]] && [[ -n "${TRAILING_LINE}" ]] && [[ "${TRAILING_LINE}" -gt "${CLOSER_LINE}" ]] \
  && ok "--update keeps the region in place, trailing content still after it (R-7.15)" \
  || bad "--update relocated the region (closer at ${CLOSER_LINE}, trailing at ${TRAILING_LINE})"
[[ "$(grep -c 'uncle-dev:generated' "${D7}/CLAUDE.md")" -eq 2 ]] \
  && ok "exactly one generated span after --update (R-7.15)" \
  || bad "generated span duplicated by --update"

# ── R-7.16: no live reference to the former skill directory ─────────────────
# This file necessarily contains the former path as a search pattern, so it is
# excluded from its own sweep.
STALE="$(cd "${REPO_ROOT}" && grep -rln 'skills/uncle-dev-setup/' \
  scripts commands skills hooks .claude-plugin plugins README.md CLAUDE.md 2>/dev/null \
  | grep -v 'scripts/tests/setup-noninteractive.test.sh' || true)"
[[ -z "${STALE}" ]] \
  && ok "no live reference to skills/uncle-dev-setup/ remains (R-7.16)" \
  || bad "stale references to the former skill directory:"$'\n'"${STALE}"

echo ""
echo "── Result ────────────────────────────────────────────────"
echo "  PASS: ${PASS}  FAIL: ${FAIL}"
[[ "${FAIL}" -eq 0 ]] || exit 1
