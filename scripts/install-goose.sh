#!/usr/bin/env bash
# install-goose.sh — install uncle-dev as a Goose plugin.
#
# Goose plugins provide skills and hooks only (no commands, no subagents).
# `goose plugin install` accepts git URLs only — there is no local-path install
# — so the default mode stages a Goose-shaped plugin tree and copies it into the
# same directory the CLI would have used:
#
#   user scope    : ~/.agents/plugins/uncle-dev/
#   project scope : <workspace>/.agents/plugins/uncle-dev/
#
# Agent personas ship separately as Goose recipes, because Goose subagents are
# recipe-based and recipes are NOT discovered inside plugin directories:
#
#   user scope    : ~/.config/goose/recipes/
#   project scope : <workspace>/.goose/recipes/
#
# Hooks are deliberately NOT installed — see goose/README.md for why.
#
# Constraints: macOS bash 3.2 (no mapfile, no associative arrays).

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"

# shellcheck source=lib/manifest.sh
source "${SCRIPT_DIR}/lib/manifest.sh"
# shellcheck source=lib/install-common.sh
source "${SCRIPT_DIR}/lib/install-common.sh"

PLUGIN_NAME="uncle-dev"
GOOSE_SRC="${REPO_ROOT}/${ASSET_GOOSE}"

SCOPE="user"
FORCE=0
DRY_RUN=0
FROM_GIT=0
AUTO_UPDATE=0
WITH_RULES=0
WITH_RECIPES=1
GIT_URL=""
WORKSPACE=""

usage() {
  cat <<'EOF'
Usage:
  ./scripts/install-goose.sh [options] [workspace]

Installs uncle-dev as a Goose plugin: plugin.json + the full skill library,
plus the 9 agent personas as Goose recipes. Slash commands and hooks are not
installed — see goose/README.md.

Options:
  --scope user|project   user (default) -> ~/.agents/plugins/uncle-dev/
                                           ~/.config/goose/recipes/
                         project        -> <workspace>/.agents/plugins/uncle-dev/
                                           <workspace>/.goose/recipes/
  --no-recipes           Skip the agent-persona recipes; install skills only.
  --rules                Also copy AGENTS.md / AGENT_RULES.md / CLAUDE.md into
                         the workspace root so Goose picks up project rules.
                         Requires a workspace argument.
  --from-git [URL]       Delegate to `goose plugin install` instead of copying.
                         URL defaults to this repo's origin remote.
  --auto-update          Pass --auto-update to `goose plugin install`.
                         Only valid with --from-git.
  --force                Replace an existing uncle-dev plugin install.
  --dry-run              Print what would happen, change nothing.
  -h, --help             Show this help.

Examples:
  ./scripts/install-goose.sh
  ./scripts/install-goose.sh --scope project ~/code/my-app
  ./scripts/install-goose.sh --rules ~/code/my-app
  ./scripts/install-goose.sh --from-git --auto-update

Verify:
  goose skills list | grep uncle-dev
EOF
}

# ── argument parsing ──────────────────────────────────────────────────────────

while [[ $# -gt 0 ]]; do
  case "$1" in
    --scope)
      [[ $# -ge 2 ]] || fail "--scope requires a value (user|project)"
      SCOPE="$2"
      shift 2
      ;;
    --rules)       WITH_RULES=1; shift ;;
    --no-recipes)  WITH_RECIPES=0; shift ;;
    --auto-update) AUTO_UPDATE=1; shift ;;
    --force)       FORCE=1; shift ;;
    --dry-run)     DRY_RUN=1; shift ;;
    --from-git)
      FROM_GIT=1
      shift
      # Optional URL argument — anything that is not another flag.
      if [[ $# -gt 0 && "$1" != --* ]]; then
        GIT_URL="$1"
        shift
      fi
      ;;
    -h|--help) usage; exit 0 ;;
    --*) fail "Unknown option: $1" ;;
    *)
      [[ -z "$WORKSPACE" ]] || fail "Unexpected extra argument: $1"
      WORKSPACE="$1"
      shift
      ;;
  esac
done

case "$SCOPE" in
  user|project) ;;
  *) fail "--scope must be 'user' or 'project' (got: ${SCOPE})" ;;
esac

[[ "$AUTO_UPDATE" -eq 1 && "$FROM_GIT" -eq 0 ]] && fail "--auto-update is only valid with --from-git"
[[ "$WITH_RULES" -eq 1 && -z "$WORKSPACE" ]] && fail "--rules requires a workspace argument"
[[ "$SCOPE" == "project" && -z "$WORKSPACE" ]] && fail "--scope project requires a workspace argument"

# ── git-backed install (delegates to the Goose CLI) ───────────────────────────

if [[ "$FROM_GIT" -eq 1 ]]; then
  command -v goose >/dev/null 2>&1 || fail "goose CLI not found in PATH — required for --from-git"

  if [[ -z "$GIT_URL" ]]; then
    GIT_URL="$(git -C "$REPO_ROOT" remote get-url origin 2>/dev/null || true)"
    [[ -n "$GIT_URL" ]] || fail "No origin remote found — pass the URL explicitly: --from-git <url>"
  fi

  GOOSE_CMD="goose plugin install"
  [[ "$AUTO_UPDATE" -eq 1 ]] && GOOSE_CMD="${GOOSE_CMD} --auto-update"
  GOOSE_CMD="${GOOSE_CMD} ${GIT_URL}"

  if [[ "$DRY_RUN" -eq 1 ]]; then
    log "DRY RUN: ${GOOSE_CMD}"
    exit 0
  fi

  log "Running: ${GOOSE_CMD}"
  # shellcheck disable=SC2086
  ${GOOSE_CMD}

  log ""
  log "Installed via Goose CLI. Verify with: goose skills list | grep uncle-dev"
  log "Note: the git-backed plugin carries skills only — the repo has no root"
  log "      plugin.json, so add one or use the default copy mode instead."
  exit 0
fi

# ── pre-flight ────────────────────────────────────────────────────────────────

command -v jq >/dev/null 2>&1 || fail "jq is required but not installed."

[[ -d "${REPO_ROOT}/${ASSET_SKILLS_ROOT}" ]] || fail "Missing skills tree: ${REPO_ROOT}/${ASSET_SKILLS_ROOT}"
[[ -f "${GOOSE_SRC}/plugin.json" ]]          || fail "Missing Goose manifest: ${GOOSE_SRC}/plugin.json"
[[ -f "${REPO_ROOT}/${ASSET_PLUGIN_META}" ]] || fail "Missing plugin manifest: ${REPO_ROOT}/${ASSET_PLUGIN_META}"

# Single source of truth for the version (R-9.4) — same pattern as install-hermes.sh.
PLUGIN_VERSION="$(jq -r '.version' "${REPO_ROOT}/${ASSET_PLUGIN_META}")"
[[ -n "$PLUGIN_VERSION" && "$PLUGIN_VERSION" != "null" ]] \
  || fail "Could not read .version from ${ASSET_PLUGIN_META}"

if [[ "$SCOPE" == "user" ]]; then
  PLUGIN_DEST="${HOME}/.agents/plugins/${PLUGIN_NAME}"
  RECIPES_DEST="${HOME}/.config/goose/recipes"
  RULES_ROOT=""
else
  [[ -d "$WORKSPACE" ]] || fail "Workspace not found: ${WORKSPACE}"
  WORKSPACE="$(cd "$WORKSPACE" && pwd)"
  [[ "$WORKSPACE" != "$REPO_ROOT" ]] || fail "Refusing to install into the source repository itself."
  PLUGIN_DEST="${WORKSPACE}/.agents/plugins/${PLUGIN_NAME}"
  RECIPES_DEST="${WORKSPACE}/.goose/recipes"
  RULES_ROOT="$WORKSPACE"
fi

if [[ "$WITH_RULES" -eq 1 ]]; then
  [[ -d "$WORKSPACE" ]] || fail "Workspace not found: ${WORKSPACE}"
  WORKSPACE="$(cd "$WORKSPACE" && pwd)"
  [[ "$WORKSPACE" != "$REPO_ROOT" ]] || fail "Refusing to write rules into the source repository itself."
  RULES_ROOT="$WORKSPACE"
fi

# ── existing-install guard ────────────────────────────────────────────────────
#
# The plugin directory is a generated artefact, so a re-install replaces it
# wholesale. Only replace a directory we can prove is ours.

if [[ -e "$PLUGIN_DEST" ]]; then
  [[ -d "$PLUGIN_DEST" ]] || fail "Destination exists and is not a directory: ${PLUGIN_DEST}"

  EXISTING_NAME=""
  if [[ -f "${PLUGIN_DEST}/plugin.json" ]]; then
    EXISTING_NAME="$(jq -r '.name // empty' "${PLUGIN_DEST}/plugin.json" 2>/dev/null || true)"
  fi
  [[ "$EXISTING_NAME" == "$PLUGIN_NAME" ]] \
    || fail "Refusing to replace ${PLUGIN_DEST} — it is not an uncle-dev plugin install."

  # --dry-run still previews; it reports the replace instead of refusing it.
  [[ "$FORCE" -eq 1 || "$DRY_RUN" -eq 1 ]] \
    || fail "${PLUGIN_NAME} is already installed at ${PLUGIN_DEST} (use --force to replace)"
fi

log "── install-goose.sh ────────────────────────────────────────"
log "  Plugin  : ${PLUGIN_NAME} v${PLUGIN_VERSION}"
log "  Scope   : ${SCOPE}"
log "  Dest    : ${PLUGIN_DEST}"
[[ "$WITH_RECIPES" -eq 1 ]] && log "  Recipes : ${RECIPES_DEST}"
[[ -n "$RULES_ROOT" && "$WITH_RULES" -eq 1 ]] && log "  Rules   : ${RULES_ROOT}"

if [[ "$DRY_RUN" -eq 1 ]]; then
  SKILL_COUNT="$(count_items "${REPO_ROOT}/${ASSET_SKILLS_ROOT}")"
  AGENT_COUNT="$(count_items "${REPO_ROOT}/${ASSET_AGENTS}")"
  log ""
  log "DRY RUN — nothing written."
  log "  Would write : ${PLUGIN_DEST}/plugin.json (version ${PLUGIN_VERSION})"
  log "  Would copy  : ${SKILL_COUNT} skills -> ${PLUGIN_DEST}/skills/"
  [[ "$WITH_RECIPES" -eq 1 ]] && log "  Would write : ${AGENT_COUNT} agent recipes -> ${RECIPES_DEST}/"
  [[ "$WITH_RULES" -eq 1 ]] && log "  Would copy  : ${ASSET_RULES[*]} -> ${RULES_ROOT}/"
  [[ -e "$PLUGIN_DEST" ]] && log "  Would replace existing install at ${PLUGIN_DEST}"
  exit 0
fi

# ── stage ─────────────────────────────────────────────────────────────────────
#
# Build the tree in a temp dir first so a failure mid-copy never leaves a
# half-written plugin where Goose can load it.

STAGE="$(mktemp -d)"
cleanup() { rm -rf "$STAGE"; }
trap cleanup EXIT

jq --arg v "$PLUGIN_VERSION" '.version = $v' "${GOOSE_SRC}/plugin.json" > "${STAGE}/plugin.json"

copy_dir_contents "${REPO_ROOT}/${ASSET_SKILLS_ROOT}" "${STAGE}/skills" 1

# scripts/ is not a Goose plugin component, but command recipes shell out to
# uncle-dev-load-skill.sh and uncle-dev-config.sh via ${CLAUDE_PLUGIN_ROOT}.
# Without it those recipes resolve nothing under Goose.
copy_dir_contents "${REPO_ROOT}/${ASSET_SCRIPTS}" "${STAGE}/scripts" 1

STAGED_SKILLS="$(count_items "${STAGE}/skills")"
[[ "$STAGED_SKILLS" -gt 0 ]] || fail "Staging produced no skills — aborting."
[[ -f "${STAGE}/scripts/uncle-dev-load-skill.sh" ]] || fail "Staging is missing the skill loader — aborting."

# ── publish ───────────────────────────────────────────────────────────────────

rm -rf "$PLUGIN_DEST"
mkdir -p "$(dirname "$PLUGIN_DEST")"
cp -R "$STAGE" "$PLUGIN_DEST"

# ── agent personas as Goose recipes ───────────────────────────────────────────
#
# Recipes are NOT discovered inside plugin directories, so they land in the
# shared recipe library instead. That directory may hold recipes we do not own,
# so files are copied individually (copy_file refuses to clobber without
# --force) rather than replaced wholesale like the plugin tree.

RECIPES_INSTALLED=0
RECIPES_AGENTS=0
RECIPES_COMMANDS=0
if [[ "$WITH_RECIPES" -eq 1 ]]; then
  RECIPE_STAGE="${STAGE}-recipes"
  mkdir -p "$RECIPE_STAGE"

  # Regenerated from agents/ and commands/ at install time — recipe YAML is
  # never checked in, so it cannot be stale.
  bash "${SCRIPT_DIR}/gen-goose-recipes.sh" \
    --out "$RECIPE_STAGE" \
    --plugin-root "$PLUGIN_DEST" \
    --quiet

  shopt -s nullglob
  for recipe in "$RECIPE_STAGE"/*.yaml; do
    copy_file "$recipe" "${RECIPES_DEST}/$(basename "$recipe")" "${FORCE}"
    RECIPES_INSTALLED=$((RECIPES_INSTALLED + 1))
    if grep -q "^# Source: ${ASSET_AGENTS}/" "$recipe"; then
      RECIPES_AGENTS=$((RECIPES_AGENTS + 1))
    else
      RECIPES_COMMANDS=$((RECIPES_COMMANDS + 1))
    fi
  done
  shopt -u nullglob

  rm -rf "$RECIPE_STAGE"

  [[ "$RECIPES_INSTALLED" -gt 0 ]] || fail "Recipe generation produced no files — aborting."
fi

# ── optional project rules ────────────────────────────────────────────────────

if [[ "$WITH_RULES" -eq 1 ]]; then
  for rule in "${ASSET_RULES[@]}"; do
    copy_file "${REPO_ROOT}/${rule}" "${RULES_ROOT}/${rule}" "${FORCE}"
  done
fi

# ── summary ───────────────────────────────────────────────────────────────────

log ""
log "── Goose install summary ───────────────────────────────────"
log "  Skills    : $(count_items "${PLUGIN_DEST}/skills") installed"
if [[ "$WITH_RECIPES" -eq 1 ]]; then
  log "  Agents    : ${RECIPES_AGENTS} recipes -> ${RECIPES_DEST}"
  log "  Commands  : ${RECIPES_COMMANDS} recipes -> ${RECIPES_DEST}"
else
  log "  Agents    : skipped (--no-recipes)"
  log "  Commands  : skipped (--no-recipes)"
fi
log "  Hooks     : not installed (see goose/README.md)"
if [[ "$WITH_RULES" -eq 1 ]]; then
  rules_found=""
  for rule in "${ASSET_RULES[@]}"; do
    [[ -f "${RULES_ROOT}/${rule}" ]] && rules_found="${rules_found} ${rule}"
  done
  log "  Rules     :${rules_found}"
fi
log ""

if command -v goose >/dev/null 2>&1; then
  log "Verify skills  : goose skills list | grep uncle-dev"
  [[ "$WITH_RECIPES" -eq 1 ]] && log "Verify recipes : goose recipe list"
else
  log "goose CLI not found in PATH — install it, then verify with:"
  log "  goose skills list | grep uncle-dev"
  [[ "$WITH_RECIPES" -eq 1 ]] && log "  goose recipe list"
fi

if [[ "$WITH_RECIPES" -eq 1 ]]; then
  log ""
  log "Run a persona:  goose run --recipe uncle-dev-agent-uncle-senior --params task=\"...\""
fi

if [[ "$WITH_RULES" -eq 0 ]]; then
  log ""
  log "Goose reads AGENTS.md / .goosehints from the project root. To have it read"
  log "this repo's CLAUDE.md too:"
  log "  export CONTEXT_FILE_NAMES='[\"AGENTS.md\",\"CLAUDE.md\",\".goosehints\"]'"
fi
