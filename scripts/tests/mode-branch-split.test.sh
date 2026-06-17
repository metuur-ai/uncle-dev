#!/bin/bash
# Tests for the install-time mode-branch split (Unit 3, #9).
#
# Acceptance (EARS Unit 3, R-3.1..R-3.7):
#   a. Each dual-branch skill source contains BOTH branch markers (R-3.1, R-3.7).
#   b. Splitting with lid-ears yields a copy with the lid-ears region and NOT the
#      openspec region (and vice-versa) (R-3.2, R-3.3).
#   c. Fail-loud: a renamed/missing marker makes the splitter error and write no
#      partial file (R-3.5).
#   d. Split disabled (default) ⇒ installed copy byte-identical to canonical (R-3.6).
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/../.." && pwd)"
SPLITTER="${REPO_ROOT}/scripts/lib/split-skill-branch.sh"
SKILLS_DIR="${REPO_ROOT}/skills"

# Dual-branch skills that carry both branch markers (subset of LLD #9's list).
# uncle-dev-wrap is intentionally EXCLUDED: on inspection it has no mode-specific
# branch to drop — it merely references both lid-ears and openspec artifact paths
# side-by-side and works identically in either mode. The splitter copies it
# verbatim (no markers ⇒ verbatim), which is the correct behavior. See
# MARKER_FREE_SKILLS below for the verbatim assertion.
AFFECTED_SKILLS=(
  uncle-dev-spec-driven-development
  uncle-dev-next-task
  uncle-dev-planning-and-task-breakdown
  uncle-dev-acknowledge
  uncle-dev-knowledge-capture
  uncle-dev-shipping-and-launch
)

# Listed in LLD #9 but has no genuine two-branch split; must be copied verbatim.
MARKER_FREE_SKILLS=(
  uncle-dev-wrap
)

PASS=0; FAIL=0
ok()   { echo "  PASS: $*"; ((PASS++)) || true; }
bad()  { echo "  FAIL: $*"; ((FAIL++)) || true; }

# shellcheck source=../lib/split-skill-branch.sh
. "${SPLITTER}"

LE_START='<!-- UNCLE_DEV:BRANCH:lid-ears:START -->'
LE_END='<!-- UNCLE_DEV:BRANCH:lid-ears:END -->'
OS_START='<!-- UNCLE_DEV:BRANCH:openspec:START -->'
OS_END='<!-- UNCLE_DEV:BRANCH:openspec:END -->'

TMPROOT="$(mktemp -d)"
trap 'rm -rf "${TMPROOT}"' EXIT

echo "── Unit 3: install-time mode-branch split ────────────────"

# ── Acceptance (a): every affected source has both branch marker pairs ────────
for skill in "${AFFECTED_SKILLS[@]}"; do
  src="${SKILLS_DIR}/${skill}/SKILL.md"
  if [[ ! -f "$src" ]]; then
    bad "${skill}: SKILL.md not found"
    continue
  fi
  miss=""
  grep -qF "$LE_START" "$src" || miss+=" lid-ears:START"
  grep -qF "$LE_END"   "$src" || miss+=" lid-ears:END"
  grep -qF "$OS_START" "$src" || miss+=" openspec:START"
  grep -qF "$OS_END"   "$src" || miss+=" openspec:END"
  [[ -z "$miss" ]] \
    && ok "${skill}: contains both branch markers" \
    || bad "${skill}: missing markers:${miss}"
done

# LLD #9 skills with no genuine two-branch split: must round-trip verbatim.
for skill in "${MARKER_FREE_SKILLS[@]}"; do
  src="${SKILLS_DIR}/${skill}/SKILL.md"
  out="${TMPROOT}/${skill}-verbatim.md"
  if split_skill_branch "$src" "$out" "lid-ears" && cmp -s "$src" "$out"; then
    ok "${skill}: no branch split (copied verbatim) — intentionally excluded"
  else
    bad "${skill}: expected verbatim copy (no markers), but it changed"
  fi
done

# ── Acceptance (b): split drops the inactive region, keeps the active one ─────
# Use one representative affected skill end-to-end for both modes.
REP="${SKILLS_DIR}/uncle-dev-spec-driven-development/SKILL.md"

dest_le="${TMPROOT}/lid-ears.md"
split_skill_branch "$REP" "$dest_le" "lid-ears" \
  && ok "split(lid-ears) returned success" \
  || bad "split(lid-ears) returned non-zero"
# lid-ears branch CONTENT must survive (a phrase unique to the lid-ears region).
if grep -qF "Phase 0-LID — LID+EARS Documentation Chain" "$dest_le"; then
  ok "lid-ears copy keeps the lid-ears branch content"
else
  bad "lid-ears copy dropped the lid-ears branch content"
fi
# openspec branch CONTENT must be gone, and so must its markers.
if grep -qF "OpenSpec Mode" "$dest_le" || grep -qF "$OS_START" "$dest_le" || grep -qF "$OS_END" "$dest_le"; then
  bad "lid-ears copy still contains the openspec region"
else
  ok "lid-ears copy dropped the openspec region (content + markers)"
fi
# Active markers themselves are stripped for a clean read.
if grep -qF "$LE_START" "$dest_le" || grep -qF "$LE_END" "$dest_le"; then
  bad "lid-ears copy still contains its own branch markers"
else
  ok "lid-ears copy stripped the active-branch markers"
fi

dest_os="${TMPROOT}/openspec.md"
split_skill_branch "$REP" "$dest_os" "openspec" \
  && ok "split(openspec) returned success" \
  || bad "split(openspec) returned non-zero"
if grep -qF "OpenSpec Mode" "$dest_os"; then
  ok "openspec copy keeps the openspec branch content"
else
  bad "openspec copy dropped the openspec branch content"
fi
if grep -qF "Phase 0-LID — LID+EARS Documentation Chain" "$dest_os" || grep -qF "$LE_START" "$dest_os" || grep -qF "$LE_END" "$dest_os"; then
  bad "openspec copy still contains the lid-ears region"
else
  ok "openspec copy dropped the lid-ears region (content + markers)"
fi

# ── Acceptance (c): fail-loud on a renamed/missing marker ─────────────────────
broken="${TMPROOT}/broken-SKILL.md"
# Rename the lid-ears END marker so the pairing is unmatched/partial.
sed 's/UNCLE_DEV:BRANCH:lid-ears:END/UNCLE_DEV:BRANCH:lid-ears:ENDXXX/' "$REP" > "$broken"
out_dest="${TMPROOT}/should-not-exist.md"
rm -f "$out_dest"
if split_skill_branch "$broken" "$out_dest" "lid-ears" 2>/dev/null; then
  bad "splitter accepted a renamed/unmatched marker (should fail loud)"
else
  ok "splitter failed loud on a renamed/unmatched marker"
fi
if [[ -e "$out_dest" ]]; then
  bad "splitter wrote a partial file despite failing"
else
  ok "splitter wrote NO partial file on failure"
fi

# A source with NO markers at all is a legitimate non-dual skill → verbatim copy.
nomarker="${TMPROOT}/no-markers.md"
printf '# Plain skill\n\nNo branches here.\n' > "$nomarker"
nm_dest="${TMPROOT}/no-markers-out.md"
if split_skill_branch "$nomarker" "$nm_dest" "lid-ears" && cmp -s "$nomarker" "$nm_dest"; then
  ok "marker-free source copied verbatim"
else
  bad "marker-free source not copied verbatim"
fi

# ── Acceptance (d): split disabled ⇒ install copy byte-identical ──────────────
# Drive the real installer with the flag OFF and assert the installed skill
# matches canonical byte-for-byte. Use the 'getting-started' target (copies the
# whole skills tree, no host-tool dependencies).
WS="${TMPROOT}/ws-default"
mkdir -p "$WS"
( cd "$REPO_ROOT" && UNCLE_DEV_SPLIT_SKILLS=0 bash scripts/install-plugin.sh getting-started "$WS" >/dev/null 2>&1 ) \
  || bad "installer (split OFF) exited non-zero"
installed="${WS}/.agents/skills/uncle-dev-spec-driven-development/SKILL.md"
if [[ -f "$installed" ]] && cmp -s "$REP" "$installed"; then
  ok "split disabled: installed copy byte-identical to canonical"
else
  bad "split disabled: installed copy differs from canonical (or missing)"
fi

# ── End-to-end with the flag ON: installer trims to the active branch ─────────
WS2="${TMPROOT}/ws-split"
mkdir -p "$WS2"
MODE="$( cd "$REPO_ROOT" && bash scripts/uncle-dev-config.sh preferences.sdd_mode lid-ears 2>/dev/null || echo lid-ears )"
( cd "$REPO_ROOT" && UNCLE_DEV_SPLIT_SKILLS=1 bash scripts/install-plugin.sh getting-started "$WS2" >/dev/null 2>&1 ) \
  || bad "installer (split ON) exited non-zero"
installed2="${WS2}/.agents/skills/uncle-dev-spec-driven-development/SKILL.md"
if [[ -f "$installed2" ]] && ! cmp -s "$REP" "$installed2"; then
  ok "split enabled: installed copy was trimmed (differs from canonical, mode=${MODE})"
else
  bad "split enabled: installed copy not trimmed (mode=${MODE})"
fi

echo ""
echo "── Result ────────────────────────────────────────────────"
echo "  PASS: ${PASS}  FAIL: ${FAIL}"
[[ "${FAIL}" -eq 0 ]] || exit 1
