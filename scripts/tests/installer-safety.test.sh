#!/bin/bash
# Installer safety refusal tests — Unit 09 (R-9.1, R-9.2, R-9.7, R-9.8).
#
# R-9.1 / R-9.7: uninstall-hermes.sh refuses when the destination resolves
#   inside the plugin's own git checkout.
# R-9.2 / R-9.8: install-antigravity.sh refuses to overwrite an existing
#   installation without --force.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/../.." && pwd)"

UNINSTALL_HERMES="${SCRIPT_DIR}/../uninstall-hermes.sh"
INSTALL_ANTIGRAVITY="${SCRIPT_DIR}/../install-antigravity.sh"

PASS=0; FAIL=0

ok()  { echo "  PASS: $*"; ((PASS++)) || true; }
bad() { echo "  FAIL: $*"; ((FAIL++)) || true; }

TMPROOT="$(mktemp -d)"
trap 'rm -rf "${TMPROOT}"' EXIT

echo "── Unit 09: installer safety refusal tests ────────────────"

# ── R-9.1 / R-9.7: uninstall-hermes.sh repo-root guard ──────────────────────
#
# The guard must fire when the destination equals or is inside the repo's
# own plugins/uncle-dev/ directory.  We drive --scope local pointing at the
# repo root itself (which makes PLUGIN_DEST = ${REPO_ROOT}/plugins/uncle-dev).

echo ""
echo "── uninstall-hermes.sh: repo-root guard ──────────────────"

# Create the expected destination so the "nothing to remove" early-exit
# does not trigger before the guard (we want to hit the guard, not the
# missing-dir path).
FAKE_PLUGIN_DIR="${REPO_ROOT}/plugins/uncle-dev"
# The real plugins/uncle-dev exists in the repo, so no need to create it.
# If for some reason it doesn't exist in the sandbox, create a placeholder:
if [[ ! -d "${FAKE_PLUGIN_DIR}" ]]; then
  mkdir -p "${FAKE_PLUGIN_DIR}"
fi

REFUSAL_OUTPUT="$(
  bash "${UNINSTALL_HERMES}" --scope local "${REPO_ROOT}" <<< "y" 2>&1
)" && REFUSAL_EXIT=0 || REFUSAL_EXIT=$?

if [[ "$REFUSAL_EXIT" -ne 0 ]]; then
  ok "uninstall-hermes.sh exits non-zero when destination is inside repo (exit=${REFUSAL_EXIT})"
else
  bad "uninstall-hermes.sh should have exited non-zero but exited 0"
fi

# The script must refuse — check for keyword in stderr output.
if echo "$REFUSAL_OUTPUT" | grep -qi "refus\|Refusing\|abort\|protect"; then
  ok "uninstall-hermes.sh emits a refusal/protection message"
else
  bad "uninstall-hermes.sh did not emit a recognisable refusal message (output: ${REFUSAL_OUTPUT})"
fi

# Verify the tracked source was NOT deleted.
if [[ -d "${FAKE_PLUGIN_DIR}" ]]; then
  ok "plugins/uncle-dev/ still present after refused deletion"
else
  bad "plugins/uncle-dev/ was deleted — guard did not protect it!"
fi

# ── R-9.2 / R-9.8: install-antigravity.sh overwrite refusal ─────────────────
#
# An existing installation (a skills/ dir with at least one SKILL.md) must
# cause the installer to refuse without --force.

echo ""
echo "── install-antigravity.sh: overwrite refusal guard ───────"

FAKE_SKILLS_DIR="${TMPROOT}/antigravity/skills"
mkdir -p "${FAKE_SKILLS_DIR}/uncle-dev-spec-driven-development"
# Place a sentinel SKILL.md so the installer detects an existing install.
printf '# Sentinel\n' > "${FAKE_SKILLS_DIR}/uncle-dev-spec-driven-development/SKILL.md"

OVERWRITE_OUTPUT="$(
  bash "${INSTALL_ANTIGRAVITY}" --dest "${FAKE_SKILLS_DIR}" 2>&1
)" && OVERWRITE_EXIT=0 || OVERWRITE_EXIT=$?

if [[ "$OVERWRITE_EXIT" -ne 0 ]]; then
  ok "install-antigravity.sh exits non-zero when dest already has skills (exit=${OVERWRITE_EXIT})"
else
  bad "install-antigravity.sh should have refused but exited 0"
fi

if echo "$OVERWRITE_OUTPUT" | grep -qi "refus\|Refusing\|already\|--force"; then
  ok "install-antigravity.sh emits a refusal message mentioning --force"
else
  bad "install-antigravity.sh did not emit a refusal message (output: ${OVERWRITE_OUTPUT})"
fi

# With --force the same install MUST succeed.
FORCE_OUTPUT="$(
  bash "${INSTALL_ANTIGRAVITY}" --dest "${FAKE_SKILLS_DIR}" --force 2>&1
)" && FORCE_EXIT=0 || FORCE_EXIT=$?

if [[ "$FORCE_EXIT" -eq 0 ]]; then
  ok "install-antigravity.sh succeeds with --force on existing dest (exit=0)"
else
  bad "install-antigravity.sh failed even with --force (exit=${FORCE_EXIT}, output: ${FORCE_OUTPUT})"
fi

# R-9.3: success message must not promise commands.
if echo "$FORCE_OUTPUT" | grep -qi "skills installed\|commands are not supported"; then
  ok "install-antigravity.sh success message states skills-only (no commands)"
else
  bad "install-antigravity.sh success message may still promise commands (output: ${FORCE_OUTPUT})"
fi

echo ""
echo "── Result ────────────────────────────────────────────────"
echo "  PASS: ${PASS}  FAIL: ${FAIL}"
[[ "${FAIL}" -eq 0 ]] || exit 1
