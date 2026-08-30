#!/usr/bin/env bash
# release.sh — cut a release end to end: bump, commit, tag, push, publish.
#
# Usage:
#   bash scripts/release.sh <major|minor|patch|X.Y.Z> [flags]
#
# Runs, in order:
#   1. scripts/bump-version.sh <target> --tag
#        → writes every manifest, promotes the CHANGELOG [Unreleased] section,
#          commits as "chore(release): vX.Y.Z", creates annotated tag vX.Y.Z
#   2. git push <remote> <branch>
#   3. git push <remote> vX.Y.Z
#   4. gh release create vX.Y.Z  (notes taken from the CHANGELOG section)
#
# Steps 2-4 publish outward and are irreversible in practice — a pushed tag and
# a published release are visible to everyone immediately. They run only after
# an interactive confirmation, or with --yes. Everything before the prompt is
# local and undoable; the prompt tells you exactly how.
#
# Flags:
#   --dry-run            print the plan and stop. Nothing is written or pushed.
#   --yes                skip the confirmation prompt (for CI)
#   --draft              create the GitHub release as a draft
#   --prerelease         mark the GitHub release as a prerelease
#   --remote <name>      git remote to push to (default: origin)
#   --allow-any-branch   permit releasing from a non-default branch
#
# Requires: git, jq, gh (authenticated).
#
# Constraints: macOS bash 3.2 (no mapfile, no declare -A, no ${var,,}).

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"

BUMP="${SCRIPT_DIR}/bump-version.sh"
CHANGELOG="${REPO_ROOT}/CHANGELOG.md"

log()  { echo "$*" >&2; }
fail() { log "Error: $*"; exit 1; }

TARGET=""
DRY_RUN=0
ASSUME_YES=0
DRAFT=0
PRERELEASE=0
REMOTE="origin"
ALLOW_ANY_BRANCH=0

# Print the header comment block, stopping at the first non-comment line so the
# usage text can never drift out of sync with the banner above.
usage() {
  awk 'NR == 1 { next } /^#/ { sub(/^# ?/, ""); print; next } { exit }' "$0"
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --dry-run)          DRY_RUN=1; shift ;;
    --yes|-y)           ASSUME_YES=1; shift ;;
    --draft)            DRAFT=1; shift ;;
    --prerelease)       PRERELEASE=1; shift ;;
    --allow-any-branch) ALLOW_ANY_BRANCH=1; shift ;;
    --remote)           [[ $# -ge 2 ]] || fail "--remote requires a name"; REMOTE="$2"; shift 2 ;;
    -h|--help)          usage; exit 0 ;;
    -*)                 fail "Unknown flag: $1" ;;
    *)
      [[ -z "${TARGET}" ]] || fail "Unexpected extra argument: $1"
      TARGET="$1"; shift ;;
  esac
done

[[ -n "${TARGET}" ]] || { usage >&2; exit 1; }

cd "${REPO_ROOT}"

# ── preflight ────────────────────────────────────────────────────────────────
# Every check here runs BEFORE anything is written. A release that fails halfway
# leaves the repo in a state someone has to reason about, so we front-load it.

log "── preflight ─────────────────────────────────────────────"

command -v git >/dev/null 2>&1 || fail "git is required"
command -v jq  >/dev/null 2>&1 || fail "jq is required"
command -v gh  >/dev/null 2>&1 || fail "gh is required (https://cli.github.com)"
[[ -x "${BUMP}" || -f "${BUMP}" ]] || fail "Missing ${BUMP}"

git rev-parse --git-dir >/dev/null 2>&1 || fail "Not a git repository"

gh auth status >/dev/null 2>&1 \
  || fail "gh is not authenticated — run: gh auth login"

BRANCH="$(git rev-parse --abbrev-ref HEAD)"
[[ "${BRANCH}" != "HEAD" ]] || fail "Detached HEAD — check out a branch first"

# Default branch as GitHub sees it; fall back to the remote's HEAD, then main.
DEFAULT_BRANCH="$(gh repo view --json defaultBranchRef --jq '.defaultBranchRef.name' 2>/dev/null || true)"
if [[ -z "${DEFAULT_BRANCH}" ]]; then
  DEFAULT_BRANCH="$(git symbolic-ref --quiet --short "refs/remotes/${REMOTE}/HEAD" 2>/dev/null | sed "s#^${REMOTE}/##" || true)"
fi
DEFAULT_BRANCH="${DEFAULT_BRANCH:-main}"

if [[ "${BRANCH}" != "${DEFAULT_BRANCH}" && "${ALLOW_ANY_BRANCH}" -eq 0 ]]; then
  fail "On branch '${BRANCH}', not the default branch '${DEFAULT_BRANCH}'.
       Releases normally cut from '${DEFAULT_BRANCH}'. Pass --allow-any-branch to override."
fi

# A dirty tree blocks a real release, but not a preview: the whole point of
# --dry-run is to see the plan before deciding to commit anything.
if [[ -n "$(git status --porcelain)" ]]; then
  if [[ "${DRY_RUN}" -eq 1 ]]; then
    log "  note: working tree is dirty — a real run would stop here"
  else
    fail "Working tree is not clean — commit or stash first"
  fi
fi

git remote get-url "${REMOTE}" >/dev/null 2>&1 \
  || fail "No such remote: ${REMOTE}"

log "  fetching ${REMOTE}..."
git fetch --quiet "${REMOTE}" --tags \
  || fail "Could not fetch from ${REMOTE}"

# Refuse to release a branch that is behind or diverged: the tag would omit
# commits already on the remote.
UPSTREAM="${REMOTE}/${BRANCH}"
if git rev-parse --quiet --verify "refs/remotes/${UPSTREAM}" >/dev/null 2>&1; then
  BEHIND="$(git rev-list --count "HEAD..${UPSTREAM}")"
  [[ "${BEHIND}" -eq 0 ]] \
    || fail "Local ${BRANCH} is ${BEHIND} commit(s) behind ${UPSTREAM} — pull first"
else
  log "  note: ${UPSTREAM} does not exist yet; it will be created on push"
fi

# Manifests must already agree, otherwise the bump starts from an unclear state.
bash "${BUMP}" --check >/dev/null 2>&1 \
  || fail "Version drift across manifests — run: bash scripts/bump-version.sh --sync"

CURRENT="$(bash "${BUMP}" --current)"
NEW="$(bash "${BUMP}" --next "${TARGET}")"
TAG="v${NEW}"

# The manifests may already sit at the target — someone ran bump-version.sh
# separately, reviewed the diff, and committed it. That is a normal split of the
# flow, so release from it instead of refusing: there is nothing to bump and
# nothing to commit, only a tag to place on the existing HEAD.
ALREADY_AT_TARGET=0
[[ "${CURRENT}" == "${NEW}" ]] && ALREADY_AT_TARGET=1

git rev-parse -q --verify "refs/tags/${TAG}" >/dev/null 2>&1 \
  && fail "Tag ${TAG} already exists locally"
[[ -z "$(git ls-remote --tags "${REMOTE}" "refs/tags/${TAG}" 2>/dev/null)" ]] \
  || fail "Tag ${TAG} already exists on ${REMOTE}"

if gh release view "${TAG}" >/dev/null 2>&1; then
  fail "A GitHub release ${TAG} already exists"
fi

log "  [OK] authenticated, on ${BRANCH}, ${TAG} is free"

# ── plan ─────────────────────────────────────────────────────────────────────

log ""
log "── plan ──────────────────────────────────────────────────"
if [[ "${ALREADY_AT_TARGET}" -eq 1 ]]; then
  log "  version : already at ${NEW} — no bump, tagging the current commit"
else
  log "  version : ${CURRENT} → ${NEW}"
fi
log "  branch  : ${BRANCH} → ${REMOTE}"
log "  tag     : ${TAG}"
[[ "${DRAFT}" -eq 1 ]]      && log "  release : DRAFT"
[[ "${PRERELEASE}" -eq 1 ]] && log "  release : PRERELEASE"

if [[ "${DRY_RUN}" -eq 1 ]]; then
  log ""
  if [[ "${ALREADY_AT_TARGET}" -eq 1 ]]; then
    log "  No manifest changes needed — every file is already at ${NEW}."
    log ""
    log "  Would then run:"
    log "    git tag -a ${TAG} -m ${TAG}"
  else
    bash "${BUMP}" "${TARGET}" --dry-run
    log ""
    log "  Would then run:"
  fi
  log "    git push ${REMOTE} ${BRANCH}"
  log "    git push ${REMOTE} ${TAG}"
  log "    gh release create ${TAG} ..."
  log ""
  log "  Dry run — nothing written or pushed."
  exit 0
fi

# ── local: bump, commit, tag ─────────────────────────────────────────────────

log ""
if [[ "${ALREADY_AT_TARGET}" -eq 1 ]]; then
  log "── tag ───────────────────────────────────────────────────"
  # Preflight already proved the tree is clean and the mirrors agree, so HEAD
  # is the commit carrying ${NEW}. Nothing to write, nothing to commit.
  log "  manifests already at ${NEW} — tagging HEAD"
  git tag -a "${TAG}" -m "${TAG}"
  log "  Created annotated tag ${TAG}."
else
  log "── bump, commit, tag ─────────────────────────────────────"
  bash "${BUMP}" "${TARGET}" --tag
fi

# ── release notes from the CHANGELOG section just promoted ───────────────────
# Falls back to a bare title if the section is missing or empty, so a thin
# CHANGELOG never blocks the release.

NOTES_FILE="$(mktemp)"
trap 'rm -f "${NOTES_FILE}"' EXIT

if [[ -f "${CHANGELOG}" ]]; then
  awk -v v="${NEW}" '
    $0 ~ "^## \\[" v "\\]" { grab = 1; next }
    grab && /^## \[/       { exit }
    grab                   { print }
  ' "${CHANGELOG}" > "${NOTES_FILE}"
fi

if [[ ! -s "${NOTES_FILE}" ]]; then
  log ""
  log "  note: no CHANGELOG section for ${NEW} — publishing with a bare title"
  printf 'Release %s\n' "${TAG}" > "${NOTES_FILE}"
fi

# ── confirmation gate ────────────────────────────────────────────────────────
# Everything above is local. Everything below is public and cannot be quietly
# undone, so this is the last exit.

if [[ "${ASSUME_YES}" -eq 0 ]]; then
  log ""
  log "── about to publish ──────────────────────────────────────"
  log "  git push ${REMOTE} ${BRANCH}"
  log "  git push ${REMOTE} ${TAG}"
  log "  gh release create ${TAG}"
  log ""
  log "  Nothing has left this machine yet. To abandon instead:"
  log "    git tag -d ${TAG}"
  # Only offer the reset when this run actually created the bump commit.
  [[ "${ALREADY_AT_TARGET}" -eq 0 ]] && log "    git reset --hard HEAD~1"
  log ""
  printf '  Publish %s? [y/N] ' "${TAG}" >&2
  REPLY=""
  read -r REPLY || true
  case "${REPLY}" in
    y|Y|yes|YES) ;;
    *)
      log ""
      if [[ "${ALREADY_AT_TARGET}" -eq 1 ]]; then
        log "  Aborted. Tag ${TAG} is still here, unpushed."
      else
        log "  Aborted. The bump commit and tag ${TAG} are still here, unpushed."
      fi
      log "  Re-run with --yes to publish, or undo with the command(s) above."
      exit 1
      ;;
  esac
fi

# ── publish ──────────────────────────────────────────────────────────────────

log ""
log "── publish ───────────────────────────────────────────────"

log "  pushing ${BRANCH}..."
git push "${REMOTE}" "${BRANCH}" \
  || fail "Push of ${BRANCH} failed — tag ${TAG} is committed locally but nothing was published"

log "  pushing ${TAG}..."
git push "${REMOTE}" "${TAG}" \
  || fail "Push of ${TAG} failed — ${BRANCH} was pushed; retry with: git push ${REMOTE} ${TAG}"

GH_ARGS="";  [[ "${DRAFT}" -eq 1 ]]      && GH_ARGS="${GH_ARGS} --draft"
             [[ "${PRERELEASE}" -eq 1 ]] && GH_ARGS="${GH_ARGS} --prerelease"

log "  creating GitHub release..."
# shellcheck disable=SC2086
gh release create "${TAG}" --title "${TAG}" --notes-file "${NOTES_FILE}" ${GH_ARGS} \
  || fail "gh release create failed — ${TAG} is pushed; retry with:
       gh release create ${TAG} --title ${TAG} --notes-file <file>"

log ""
log "  Released ${TAG}."
gh release view "${TAG}" --json url --jq '"  " + .url' >&2 || true
