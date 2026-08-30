#!/bin/bash
# Tests for scripts/release.sh — end-to-end release orchestration.
#
# Each case builds a sandbox with a real local bare repo as "origin" and a stub
# `gh` on PATH that records its invocations to a log file. Nothing touches the
# network or a real GitHub repo.
#
# Covered:
#   1.  --dry-run writes nothing, pushes nothing, creates no tag
#   2.  --dry-run tolerates a dirty tree (preview before committing)
#   3.  full run: bump + commit + tag + push branch + push tag + gh release
#   4.  release notes come from the promoted CHANGELOG section
#   5.  declining the confirmation prompt publishes nothing but keeps the tag
#   6.  dirty tree is refused on a real run
#   7.  non-default branch is refused without --allow-any-branch
#   8.  an existing local tag is refused
#   9.  an existing GitHub release is refused
#   10. version drift across manifests is refused
#   11. --draft / --prerelease reach the gh invocation
set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/../.." && pwd)"

PASS=0; FAIL=0
ok()  { echo "  PASS: $*"; ((PASS++)) || true; }
bad() { echo "  FAIL: $*"; ((FAIL++)) || true; }

TMPROOT="$(mktemp -d)"
trap 'rm -rf "${TMPROOT}"' EXIT

# new_sandbox NAME [EXISTING_RELEASE_TAG]
# Echoes the working-clone path. A bare repo alongside it acts as origin, and a
# stub gh is placed in <sandbox>/bin (prepended to PATH by run_release).
new_sandbox() {
  local name="$1" existing_release="${2:-}"
  local base="${TMPROOT}/${name}"
  local work="${base}/work" bare="${base}/origin.git"

  mkdir -p "${work}/scripts" "${work}/.claude-plugin" \
           "${work}/plugins/uncle-dev/.codex-plugin" "${work}/goose" \
           "${work}/.agents/plugins" "${work}/skills/uncle-dev-setup-local" \
           "${base}/bin"

  cp "${REPO_ROOT}/scripts/bump-version.sh" "${REPO_ROOT}/scripts/release.sh" "${work}/scripts/"
  cp -R "${REPO_ROOT}/scripts/lib" "${work}/scripts/lib"

  printf '{\n  "name": "uncle-dev",\n  "version": "1.6.0",\n  "license": "MIT"\n}\n' \
    > "${work}/.claude-plugin/plugin.json"
  printf '{\n  "name": "uncle-dev",\n  "version": "1.6.0"\n}\n' \
    > "${work}/plugins/uncle-dev/.codex-plugin/plugin.json"
  printf '{\n  "name": "uncle-dev",\n  "version": "1.6.0"\n}\n' \
    > "${work}/goose/plugin.json"
  printf '{\n  "plugins": [ { "name": "uncle-dev", "version": "1.6.0" } ]\n}\n' \
    > "${work}/.agents/plugins/marketplace.json"
  printf '# config\nversion: "1.6.0"\nproject:\n  name: "__PROJECT_NAME__"\n' \
    > "${work}/skills/uncle-dev-setup-local/uncle-dev-setup.template.yaml"
  {
    printf '# Changelog\n\n'
    printf '## [Unreleased]\n\n'
    printf '### Added\n\n'
    printf -- '- shiny new thing\n\n'
    printf '## [1.5.0] - 2026-01-01\n'
  } > "${work}/CHANGELOG.md"

  # Stub gh: logs every invocation, answers the four subcommands release.sh uses.
  cat > "${base}/bin/gh" <<STUBEOF
#!/bin/bash
echo "\$@" >> "${base}/gh.log"
case "\$1 \$2" in
  "auth status") exit 0 ;;
  "repo view")   echo "main"; exit 0 ;;
  "release view")
    [[ "\$3" == "${existing_release}" && -n "${existing_release}" ]] && exit 0
    exit 1 ;;
  "release create") exit 0 ;;
  *) exit 0 ;;
esac
STUBEOF
  chmod +x "${base}/bin/gh"

  git init -q "${bare}" --bare
  (cd "${work}" \
    && git init -q . \
    && git config user.email t@t && git config user.name t \
    && git symbolic-ref HEAD refs/heads/main \
    && git remote add origin "${bare}" \
    && git add -A && git commit -qm init \
    && git push -q origin main 2>/dev/null) >/dev/null 2>&1

  echo "${work}"
}

# run_release SANDBOX_WORK_DIR ARGS...
run_release() {
  local work="$1"; shift
  local base; base="$(dirname "${work}")"
  (cd "${work}" && PATH="${base}/bin:${PATH}" bash scripts/release.sh "$@" </dev/null 2>&1)
}

ghlog() { cat "$(dirname "$1")/gh.log" 2>/dev/null || true; }

echo "── release.sh ─────────────────────────────────────────────"

# ── 1. --dry-run is inert ────────────────────────────────────────────────────
SB="$(new_sandbox dryrun)"
OUT="$(run_release "${SB}" patch --dry-run)"
V="$(cd "${SB}" && jq -r .version .claude-plugin/plugin.json)"
TAGS="$(cd "${SB}" && git tag)"
REMOTE_TAGS="$(cd "${SB}" && git ls-remote --tags origin 2>/dev/null)"
if [[ "${V}" == "1.6.0" && -z "${TAGS}" && -z "${REMOTE_TAGS}" ]] \
   && ! ghlog "${SB}" | grep -q 'release create'; then
  ok "--dry-run writes nothing, tags nothing, publishes nothing"
else
  bad "--dry-run side effects: version=${V} tags='${TAGS}' remote='${REMOTE_TAGS}'"
fi
echo "${OUT}" | grep -q '1.6.0 → 1.6.1' \
  && ok "--dry-run reports the computed target 1.6.1" \
  || bad "--dry-run did not report the target"

# ── 2. --dry-run tolerates a dirty tree ──────────────────────────────────────
echo dirt > "${SB}/dirt.txt"
OUT="$(run_release "${SB}" patch --dry-run)"; RC=$?
if [[ "${RC}" -eq 0 ]] && echo "${OUT}" | grep -q 'working tree is dirty'; then
  ok "--dry-run warns about a dirty tree but still previews"
else
  bad "--dry-run on dirty tree: rc=${RC}"
fi

# ── 3+4. full run ────────────────────────────────────────────────────────────
SB="$(new_sandbox full)"
OUT="$(run_release "${SB}" minor --yes)"; RC=$?
V="$(cd "${SB}" && jq -r .version .claude-plugin/plugin.json)"
TAGS="$(cd "${SB}" && git tag)"
SUBJ="$(cd "${SB}" && git log --format=%s -1)"
REMOTE_TAG="$(cd "${SB}" && git ls-remote --tags origin 'refs/tags/v1.7.0')"
REMOTE_MAIN="$(cd "${SB}" && git ls-remote --heads origin main)"
if [[ "${RC}" -eq 0 && "${V}" == "1.7.0" && "${TAGS}" == "v1.7.0" \
      && "${SUBJ}" == "chore(release): v1.7.0" \
      && -n "${REMOTE_TAG}" && -n "${REMOTE_MAIN}" ]]; then
  ok "full run: bumped, committed, tagged, pushed branch + tag"
else
  bad "full run: rc=${RC} v=${V} tags='${TAGS}' subj='${SUBJ}' rtag='${REMOTE_TAG}'"
fi

if ghlog "${SB}" | grep -q 'release create v1.7.0'; then
  ok "gh release create invoked for v1.7.0"
else
  bad "gh release create not invoked: $(ghlog "${SB}" | tr '\n' '; ')"
fi

# The pushed tag must point at the release commit.
POINTS="$(cd "${SB}" && git rev-list -n1 v1.7.0)"
HEAD_SHA="$(cd "${SB}" && git rev-parse HEAD)"
[[ "${POINTS}" == "${HEAD_SHA}" ]] \
  && ok "tag v1.7.0 points at the release commit" \
  || bad "tag points elsewhere"

# Notes are taken from the promoted CHANGELOG section, not a bare title.
NOTES_ARG="$(ghlog "${SB}" | grep 'release create' | sed 's/.*--notes-file //' | awk '{print $1}')"
if grep -q '^## \[1\.7\.0\]' "${SB}/CHANGELOG.md" \
   && grep -q 'shiny new thing' "${SB}/CHANGELOG.md"; then
  ok "CHANGELOG promoted to [1.7.0] carrying the Unreleased entries"
else
  bad "CHANGELOG not promoted correctly"
fi
[[ -n "${NOTES_ARG}" ]] \
  && ok "gh release create received --notes-file" \
  || bad "gh release create had no --notes-file"

# ── 5. declining the prompt ──────────────────────────────────────────────────
SB="$(new_sandbox decline)"
OUT="$(cd "${SB}" && PATH="$(dirname "${SB}")/bin:${PATH}" \
        bash scripts/release.sh patch <<< "n" 2>&1)"; RC=$?
TAGS="$(cd "${SB}" && git tag)"
REMOTE_TAGS="$(cd "${SB}" && git ls-remote --tags origin 2>/dev/null)"
if [[ "${RC}" -ne 0 && "${TAGS}" == "v1.6.1" && -z "${REMOTE_TAGS}" ]] \
   && ! ghlog "${SB}" | grep -q 'release create'; then
  ok "declining publishes nothing but keeps the local tag"
else
  bad "decline: rc=${RC} tags='${TAGS}' remote='${REMOTE_TAGS}'"
fi
echo "${OUT}" | grep -q 'git tag -d v1.6.1' \
  && ok "decline prints the undo commands" \
  || bad "decline did not print undo commands"

# ── 6. dirty tree refused on a real run ──────────────────────────────────────
SB="$(new_sandbox dirty)"
echo dirt > "${SB}/dirt.txt"
OUT="$(run_release "${SB}" patch --yes)"; RC=$?
TAGS="$(cd "${SB}" && git tag)"
if [[ "${RC}" -ne 0 && -z "${TAGS}" ]] && echo "${OUT}" | grep -q 'not clean'; then
  ok "dirty tree refused, nothing tagged"
else
  bad "dirty tree: rc=${RC} tags='${TAGS}'"
fi

# ── 7. non-default branch ────────────────────────────────────────────────────
SB="$(new_sandbox branch)"
(cd "${SB}" && git checkout -qb feature/x) >/dev/null 2>&1
OUT="$(run_release "${SB}" patch --yes)"; RC=$?
if [[ "${RC}" -ne 0 ]] && echo "${OUT}" | grep -q 'not the default branch'; then
  ok "non-default branch refused without --allow-any-branch"
else
  bad "branch guard: rc=${RC}, out='${OUT}'"
fi
OUT="$(run_release "${SB}" patch --dry-run --allow-any-branch)"; RC=$?
[[ "${RC}" -eq 0 ]] \
  && ok "--allow-any-branch permits a non-default branch" \
  || bad "--allow-any-branch still refused: ${OUT}"

# ── 8. existing local tag ────────────────────────────────────────────────────
SB="$(new_sandbox existingtag)"
(cd "${SB}" && git tag -a v1.6.1 -m v1.6.1) >/dev/null 2>&1
OUT="$(run_release "${SB}" patch --yes)"; RC=$?
if [[ "${RC}" -ne 0 ]] && echo "${OUT}" | grep -q 'already exists locally'; then
  ok "existing local tag refused"
else
  bad "existing tag guard: rc=${RC}, out='${OUT}'"
fi

# ── 9. existing GitHub release ───────────────────────────────────────────────
SB="$(new_sandbox existingrelease v1.6.1)"
OUT="$(run_release "${SB}" patch --yes)"; RC=$?
if [[ "${RC}" -ne 0 ]] && echo "${OUT}" | grep -q 'release v1.6.1 already exists'; then
  ok "existing GitHub release refused"
else
  bad "existing release guard: rc=${RC}, out='${OUT}'"
fi

# ── 10. manifest drift ───────────────────────────────────────────────────────
SB="$(new_sandbox drift)"
(cd "${SB}" && jq '.version = "1.4.1"' goose/plugin.json > t && mv t goose/plugin.json \
   && git add -A && git commit -qm drift) >/dev/null 2>&1
OUT="$(run_release "${SB}" patch --yes)"; RC=$?
if [[ "${RC}" -ne 0 ]] && echo "${OUT}" | grep -q 'drift'; then
  ok "manifest version drift refused"
else
  bad "drift guard: rc=${RC}, out='${OUT}'"
fi

# ── 11. --draft / --prerelease reach gh ──────────────────────────────────────
SB="$(new_sandbox draft)"
run_release "${SB}" patch --yes --draft --prerelease >/dev/null 2>&1
LINE="$(ghlog "${SB}" | grep 'release create' || true)"
if echo "${LINE}" | grep -q -- '--draft' && echo "${LINE}" | grep -q -- '--prerelease'; then
  ok "--draft and --prerelease are forwarded to gh release create"
else
  bad "flags not forwarded: '${LINE}'"
fi

echo ""
echo "── Result ────────────────────────────────────────────────"
echo "  PASS: ${PASS}  FAIL: ${FAIL}"
[[ "${FAIL}" -eq 0 ]] || exit 1
