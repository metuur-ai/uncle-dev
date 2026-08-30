#!/usr/bin/env bash
# bump-version.sh — set the release version across every manifest that carries one.
#
# Usage:
#   bash scripts/bump-version.sh --current            # print the canonical version
#   bash scripts/bump-version.sh --check              # verify all mirrors match canonical
#   bash scripts/bump-version.sh --sync               # re-propagate canonical to mirrors
#   bash scripts/bump-version.sh <major|minor|patch>  # bump and propagate
#   bash scripts/bump-version.sh <X.Y.Z>              # set an explicit version
#
# Flags (bump mode only):
#   --dry-run        show what would change; write nothing
#   --tag            commit the bump as "chore(release): vX.Y.Z" and create the
#                    annotated tag vX.Y.Z. Requires a clean tree up front, so the
#                    release commit contains the bump and nothing else.
#   --no-changelog   skip promoting the CHANGELOG [Unreleased] section
#
# Canonical source of truth is .claude-plugin/plugin.json (ASSET_PLUGIN_META in
# scripts/lib/manifest.sh). Every installer reads the version from there —
# install-claude.sh:27, install-goose.sh:163, gen-goose-recipes.sh:145,
# install-hermes.sh:11 — so the other manifests are mirrors that must not drift.
#
# NOT touched by this script:
#   .agents/uncle-dev-setup.yaml       project config instance, written by
#                                      /uncle-dev-setup — not a release artifact.
#   scripts/tests/hook-toggles.test.sh a fixture value; its literal is arbitrary.
# --check reports both as informational only and does not fail on them.
#
# Never pushes and never creates a GitHub release: both are outward-facing and
# stay an explicit human step. See the tail of a successful run for the commands.
#
# Constraints: macOS bash 3.2 (no mapfile, no declare -A, no ${var,,}).

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"

# shellcheck source=lib/manifest.sh
source "${SCRIPT_DIR}/lib/manifest.sh"
# shellcheck source=lib/install-common.sh
source "${SCRIPT_DIR}/lib/install-common.sh"

CANONICAL="${REPO_ROOT}/${ASSET_PLUGIN_META}"

# ── JSON mirrors: "<relative path>|<jq path expression>" ─────────────────────
# Parallel-array style (no declare -A on bash 3.2).
JSON_TARGETS=(
  "${ASSET_PLUGIN_META}|.version"
  "plugins/uncle-dev/.codex-plugin/plugin.json|.version"
  "goose/plugin.json|.version"
  '.agents/plugins/marketplace.json|(.plugins[] | select(.name == "uncle-dev") | .version)'
)

# ── YAML mirrors: top-level `version:` line, edited with awk to preserve the
# surrounding comment blocks (a yaml round-trip would strip them).
YAML_TARGETS=(
  "skills/uncle-dev-setup-local/uncle-dev-setup.template.yaml"
)

CHANGELOG="CHANGELOG.md"

# Informational-only drift sources (reported by --check, never written).
INFO_TARGETS=(
  ".agents/uncle-dev-setup.yaml"
)

# ── helpers ──────────────────────────────────────────────────────────────────

command -v jq >/dev/null 2>&1 || fail "jq is required"

valid_semver() {
  [[ "$1" =~ ^[0-9]+\.[0-9]+\.[0-9]+(-[0-9A-Za-z.-]+)?$ ]]
}

read_canonical() {
  [[ -f "${CANONICAL}" ]] || fail "Missing canonical manifest: ${CANONICAL}"
  local v
  v="$(jq -r '.version // empty' "${CANONICAL}")"
  [[ -n "${v}" ]] || fail "Could not read .version from ${ASSET_PLUGIN_META}"
  echo "${v}"
}

# read_json_version REL_PATH JQ_PATH
read_json_version() {
  local rel="$1" jqpath="$2" abs="${REPO_ROOT}/$1"
  [[ -f "${abs}" ]] || { echo ""; return 0; }
  jq -r "${jqpath} // empty" "${abs}" 2>/dev/null || echo ""
}

# read_yaml_version REL_PATH — first top-level `version:` line.
read_yaml_version() {
  local abs="${REPO_ROOT}/$1"
  [[ -f "${abs}" ]] || { echo ""; return 0; }
  awk '/^version:[[:space:]]/ { gsub(/^version:[[:space:]]*"?|"?[[:space:]]*$/, ""); print; exit }' "${abs}"
}

# next_version CURRENT PART
next_version() {
  local current="$1" part="$2"
  local core="${current%%-*}"
  local major minor patch
  major="${core%%.*}"
  patch="${core##*.}"
  minor="${core#*.}"; minor="${minor%%.*}"

  case "${part}" in
    major) echo "$((major + 1)).0.0" ;;
    minor) echo "${major}.$((minor + 1)).0" ;;
    patch) echo "${major}.${minor}.$((patch + 1))" ;;
    *)     fail "Unknown bump part: ${part}" ;;
  esac
}

# write_json REL_PATH JQ_PATH NEW_VERSION
write_json() {
  local rel="$1" jqpath="$2" new="$3" abs="${REPO_ROOT}/$1"
  [[ -f "${abs}" ]] || { log "  SKIP (not found): ${rel}"; return 0; }
  local tmp="${abs}.tmp.$$"
  jq --arg v "${new}" "${jqpath} = \$v" "${abs}" > "${tmp}"
  mv "${tmp}" "${abs}"
}

# write_yaml REL_PATH NEW_VERSION — replaces only the FIRST top-level version: line.
write_yaml() {
  local rel="$1" new="$2" abs="${REPO_ROOT}/$1"
  [[ -f "${abs}" ]] || { log "  SKIP (not found): ${rel}"; return 0; }
  local tmp="${abs}.tmp.$$"
  awk -v v="${new}" '
    !done && /^version:[[:space:]]/ { print "version: \"" v "\""; done=1; next }
    { print }
  ' "${abs}" > "${tmp}"
  mv "${tmp}" "${abs}"
}

# promote_changelog NEW_VERSION — rename [Unreleased] to [NEW] - DATE and open a
# fresh empty [Unreleased] above it.
promote_changelog() {
  local new="$1" abs="${REPO_ROOT}/${CHANGELOG}"
  [[ -f "${abs}" ]] || { log "  SKIP (not found): ${CHANGELOG}"; return 0; }

  if ! grep -q '^## \[Unreleased\]' "${abs}"; then
    log "  WARN: no '## [Unreleased]' section in ${CHANGELOG} — left untouched"
    return 0
  fi
  if grep -q "^## \[${new}\]" "${abs}"; then
    log "  WARN: ${CHANGELOG} already has a [${new}] section — left untouched"
    return 0
  fi

  local today tmp
  today="$(date +%Y-%m-%d)"
  tmp="${abs}.tmp.$$"
  awk -v v="${new}" -v d="${today}" '
    !done && /^## \[Unreleased\]/ {
      print "## [Unreleased]"
      print ""
      print "## [" v "] - " d
      done=1
      next
    }
    { print }
  ' "${abs}" > "${tmp}"
  mv "${tmp}" "${abs}"
}

# ── --check ──────────────────────────────────────────────────────────────────

do_check() {
  local canonical drift=0 entry rel jqpath actual
  canonical="$(read_canonical)"

  echo "── version check ─────────────────────────────────────────"
  echo "  canonical (${ASSET_PLUGIN_META}): ${canonical}"
  echo ""

  for entry in "${JSON_TARGETS[@]}"; do
    rel="${entry%%|*}"
    jqpath="${entry#*|}"
    [[ "${rel}" == "${ASSET_PLUGIN_META}" ]] && continue
    actual="$(read_json_version "${rel}" "${jqpath}")"
    if [[ -z "${actual}" ]]; then
      echo "  [MISS] ${rel} — no version found"
      drift=1
    elif [[ "${actual}" == "${canonical}" ]]; then
      echo "  [OK]   ${rel}"
    else
      echo "  [DRIFT] ${rel}: ${actual} (expected ${canonical})"
      drift=1
    fi
  done

  for rel in "${YAML_TARGETS[@]}"; do
    actual="$(read_yaml_version "${rel}")"
    if [[ -z "${actual}" ]]; then
      echo "  [MISS] ${rel} — no version: line found"
      drift=1
    elif [[ "${actual}" == "${canonical}" ]]; then
      echo "  [OK]   ${rel}"
    else
      echo "  [DRIFT] ${rel}: ${actual} (expected ${canonical})"
      drift=1
    fi
  done

  echo ""
  echo "  informational (not managed by this script):"
  for rel in "${INFO_TARGETS[@]}"; do
    actual="$(read_yaml_version "${rel}")"
    [[ -n "${actual}" ]] && echo "    ${rel}: ${actual}"
  done

  echo ""
  if [[ "${drift}" -eq 0 ]]; then
    echo "  All managed manifests agree on ${canonical}."
    return 0
  fi
  echo "  Drift found. Run: bash scripts/bump-version.sh --sync"
  return 1
}

# ── main ─────────────────────────────────────────────────────────────────────

[[ $# -gt 0 ]] || { grep '^#' "$0" | sed -n '2,20p' | sed 's/^# \{0,1\}//' >&2; exit 1; }

TARGET_ARG=""
DRY_RUN=0
DO_TAG=0
DO_CHANGELOG=1
DO_SYNC=0

while [[ $# -gt 0 ]]; do
  case "$1" in
    --current) read_canonical; exit 0 ;;
    --check)   do_check; exit $? ;;
    --sync)    DO_SYNC=1; shift ;;
    --dry-run) DRY_RUN=1; shift ;;
    --tag)     DO_TAG=1; shift ;;
    --no-changelog) DO_CHANGELOG=0; shift ;;
    -h|--help) grep '^#' "$0" | sed -n '2,20p' | sed 's/^# \{0,1\}//'; exit 0 ;;
    -*)        fail "Unknown flag: $1" ;;
    *)
      [[ -z "${TARGET_ARG}" ]] || fail "Unexpected extra argument: $1"
      TARGET_ARG="$1"; shift ;;
  esac
done

CURRENT="$(read_canonical)"

if [[ "${DO_SYNC}" -eq 1 ]]; then
  # Re-propagate the canonical version to mirrors that drifted. No arithmetic,
  # no changelog promotion — the release itself has not changed.
  [[ -z "${TARGET_ARG}" ]] || fail "--sync takes no version argument (got: ${TARGET_ARG})"
  NEW="${CURRENT}"
  DO_CHANGELOG=0
  log "── sync mirrors to ${NEW} ─────────────────────────────────"
else
  [[ -n "${TARGET_ARG}" ]] || fail "Missing version argument (major|minor|patch|X.Y.Z)"

  case "${TARGET_ARG}" in
    major|minor|patch) NEW="$(next_version "${CURRENT}" "${TARGET_ARG}")" ;;
    *)
      valid_semver "${TARGET_ARG}" || fail "Not a valid version: ${TARGET_ARG} (expected X.Y.Z)"
      NEW="${TARGET_ARG}"
      ;;
  esac

  [[ "${NEW}" != "${CURRENT}" ]] \
    || fail "Version is already ${CURRENT} — use --sync to re-propagate it to mirrors"

  log "── bump ${CURRENT} → ${NEW} ───────────────────────────────"
fi
[[ "${DRY_RUN}" -eq 1 ]] && log "  (dry run — no files written)"

# --tag preconditions, checked BEFORE any file is written. The tree must be clean
# up front so the release commit contains the bump and nothing else — checking
# afterwards is useless, since our own writes would have dirtied it.
if [[ "${DO_TAG}" -eq 1 && "${DRY_RUN}" -eq 0 ]]; then
  git -C "${REPO_ROOT}" rev-parse --git-dir >/dev/null 2>&1 \
    || fail "--tag requested but this is not a git repository"

  ! git -C "${REPO_ROOT}" rev-parse -q --verify "refs/tags/v${NEW}" >/dev/null 2>&1 \
    || fail "Tag v${NEW} already exists"

  [[ -z "$(git -C "${REPO_ROOT}" status --porcelain)" ]] \
    || fail "--tag requires a clean working tree (commit or stash first)"
fi

# Files already carrying the target version are left byte-identical. Rewriting
# them would still reformat (jq normalizes whitespace and adds a trailing
# newline), producing diff noise in manifests the bump never actually changed.
for entry in "${JSON_TARGETS[@]}"; do
  rel="${entry%%|*}"
  jqpath="${entry#*|}"
  before="$(read_json_version "${rel}" "${jqpath}")"
  if [[ "${before}" == "${NEW}" ]]; then
    log "  ${rel}: ${NEW} (unchanged)"
    continue
  fi
  log "  ${rel}: ${before:-<none>} → ${NEW}"
  [[ "${DRY_RUN}" -eq 1 ]] || write_json "${rel}" "${jqpath}" "${NEW}"
done

for rel in "${YAML_TARGETS[@]}"; do
  before="$(read_yaml_version "${rel}")"
  if [[ "${before}" == "${NEW}" ]]; then
    log "  ${rel}: ${NEW} (unchanged)"
    continue
  fi
  log "  ${rel}: ${before:-<none>} → ${NEW}"
  [[ "${DRY_RUN}" -eq 1 ]] || write_yaml "${rel}" "${NEW}"
done

if [[ "${DO_CHANGELOG}" -eq 1 ]]; then
  log "  ${CHANGELOG}: promote [Unreleased] → [${NEW}]"
  [[ "${DRY_RUN}" -eq 1 ]] || promote_changelog "${NEW}"
fi

if [[ "${DRY_RUN}" -eq 1 ]]; then
  log ""
  log "  Dry run complete — nothing written."
  exit 0
fi

# Verify we actually converged before reporting success.
if ! do_check >/dev/null 2>&1; then
  log ""
  do_check || true
  fail "Post-bump check failed — manifests did not converge on ${NEW}"
fi

log ""
log "  All managed manifests now at ${NEW}."

if [[ "${DO_TAG}" -eq 1 ]]; then
  # The tree was verified clean above, so everything staged here is the bump.
  git -C "${REPO_ROOT}" commit -aqm "chore(release): v${NEW}"
  git -C "${REPO_ROOT}" tag -a "v${NEW}" -m "v${NEW}"
  log "  Committed the bump and created annotated tag v${NEW}."
else
  log ""
  log "  To release, commit the bump and tag it:"
  log "    git commit -am \"chore(release): v${NEW}\""
  log "    git tag -a v${NEW} -m \"v${NEW}\""
fi

if [[ "${DO_SYNC}" -eq 0 ]]; then
  log ""
  log "  Next (not run automatically — both publish outward):"
  log "    git push origin v${NEW}"
  log "    gh release create v${NEW} --notes-from-tag"
fi
