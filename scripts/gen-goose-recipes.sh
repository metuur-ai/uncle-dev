#!/usr/bin/env bash
# gen-goose-recipes.sh — convert uncle-dev agents and commands into Goose recipes.
#
# Goose has no plugin-level format for either subagents or slash commands: both
# are recipes, discovered from ~/.config/goose/recipes/, <project>/.goose/recipes/,
# or GOOSE_RECIPE_PATH. This script is the bridge — agents/ and commands/ stay
# the single source of truth and the YAML is generated straight into a Goose
# install directory.
#
# --out is REQUIRED and must live outside this repository. Generated recipes are
# never checked in: install-goose.sh regenerates them on every run, so a
# committed copy could only ever be stale.
#
# Mapping (agents/<stem>.md -> uncle-dev-agent-<name>.yaml):
#   frontmatter name        -> title
#   frontmatter description -> description
#   markdown body           -> instructions
#   (synthesised)           -> prompt "{{ task }}" + a `task` parameter
#
# Mapping (commands/<stem>.md -> <stem>.yaml):
#   <stem>                  -> title            (mirrors the /<stem> slash command)
#   frontmatter description -> description
#   markdown body           -> instructions
#   frontmatter argument-hint -> `arguments` parameter description
#   (synthesised)           -> prompt referencing "{{ arguments }}"
#
# Three body transforms are applied, in this order:
#   1. Literal `{{` / `{%` are escaped so Goose's Jinja renderer treats them as
#      text (commands/uncle-dev-design-docs.md documents {{segment}} placeholders).
#   2. `$ARGUMENTS` becomes `{{ arguments }}` (commands only).
#   3. `${CLAUDE_PLUGIN_ROOT}` / `${CLAUDE_PLUGIN_ROOT:-}` gain the installed
#      plugin root as their default, so the skill loader and bundled Python
#      scripts resolve under Goose, where that variable is never set.
#
# Constraints: macOS bash 3.2 (no mapfile, no associative arrays).

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"

# shellcheck source=lib/manifest.sh
source "${SCRIPT_DIR}/lib/manifest.sh"

OUT_DIR=""
PLUGIN_ROOT=""
DO_AGENTS=1
DO_COMMANDS=1
QUIET=0

usage() {
  cat <<'EOF'
Usage:
  ./scripts/gen-goose-recipes.sh --out DIR --plugin-root DIR [options]

Generates one Goose recipe YAML per agent persona and per slash command.

Recipes are a runtime artefact, never a source file. --out is required and must
point outside this repository — typically a Goose recipe directory:

  ~/.config/goose/recipes          (user scope)
  <workspace>/.goose/recipes       (project scope)

--plugin-root is the installed plugin directory (e.g. ~/.agents/plugins/uncle-dev).
Command recipes bake it in so the bundled skill loader and Python helpers resolve
under Goose, which never sets CLAUDE_PLUGIN_ROOT.

install-goose.sh calls this script for you; run it directly only to inspect or
refresh recipes in an existing Goose install.

Options:
  --out DIR           Output directory (required, must be outside this repo)
  --plugin-root DIR   Installed plugin root (required unless --agents-only)
  --agents-only       Generate agent-persona recipes only
  --commands-only     Generate slash-command recipes only
  --quiet             Suppress per-file output
  -h, --help          Show this help
EOF
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --out)
      [[ $# -ge 2 ]] || { echo "Error: --out requires a directory" >&2; exit 1; }
      OUT_DIR="$2"; shift 2 ;;
    --plugin-root)
      [[ $# -ge 2 ]] || { echo "Error: --plugin-root requires a directory" >&2; exit 1; }
      PLUGIN_ROOT="$2"; shift 2 ;;
    --agents-only)   DO_COMMANDS=0; shift ;;
    --commands-only) DO_AGENTS=0; shift ;;
    --quiet)         QUIET=1; shift ;;
    -h|--help)       usage; exit 0 ;;
    *) echo "Error: unknown option: $1" >&2; exit 1 ;;
  esac
done

say() { [[ "$QUIET" -eq 1 ]] || echo "$*" >&2; }

# ── output-directory validation ───────────────────────────────────────────────

if [[ -z "$OUT_DIR" ]]; then
  echo "Error: --out is required." >&2
  echo "       Recipes are a runtime artefact — generate them into a Goose" >&2
  echo "       recipe directory, not into this repository. For example:" >&2
  echo "         --out ~/.config/goose/recipes" >&2
  echo "         --out <workspace>/.goose/recipes" >&2
  exit 1
fi

if [[ "$DO_COMMANDS" -eq 1 && -z "$PLUGIN_ROOT" ]]; then
  echo "Error: --plugin-root is required when generating command recipes." >&2
  echo "       Commands reference \${CLAUDE_PLUGIN_ROOT}, which Goose never sets;" >&2
  echo "       the installed plugin path is baked in as its default." >&2
  echo "       Pass --plugin-root ~/.agents/plugins/uncle-dev, or --agents-only." >&2
  exit 1
fi

# Resolve a path to absolute without creating it, by walking up to the nearest
# existing ancestor. (bash 3.2: no realpath dependency.)
resolve_abs() {
  local p="$1" suffix=""
  while [[ ! -d "$p" && "$p" != "/" && "$p" != "." ]]; do
    suffix="/$(basename "$p")${suffix}"
    p="$(dirname "$p")"
  done
  printf '%s%s\n' "$(cd "$p" && pwd -P)" "$suffix"
}

OUT_ABS="$(resolve_abs "$OUT_DIR")"
REPO_ABS="$(cd "$REPO_ROOT" && pwd -P)"

case "$OUT_ABS" in
  "$REPO_ABS"|"$REPO_ABS"/*)
    echo "Error: refusing to generate recipes inside the source repository:" >&2
    echo "         ${OUT_ABS}" >&2
    echo "       Generated YAML belongs in a Goose install directory, not in git." >&2
    exit 1
    ;;
esac

OUT_DIR="$OUT_ABS"
[[ -n "$PLUGIN_ROOT" ]] && PLUGIN_ROOT="$(resolve_abs "$PLUGIN_ROOT")"

command -v jq >/dev/null 2>&1 || { echo "Error: jq is required but not installed." >&2; exit 1; }
PLUGIN_VERSION="$(jq -r '.version' "${REPO_ROOT}/${ASSET_PLUGIN_META}")"
[[ -n "$PLUGIN_VERSION" && "$PLUGIN_VERSION" != "null" ]] \
  || { echo "Error: could not read .version from ${ASSET_PLUGIN_META}" >&2; exit 1; }

# ── frontmatter / body extraction ─────────────────────────────────────────────

# fm_get KEY FILE — value of a single-line frontmatter key, empty if absent.
# Surrounding double quotes are stripped (argument-hint is quoted in source).
fm_get() {
  awk -v key="$1" '
    NR == 1 && $0 == "---" { inside = 1; next }
    inside && $0 == "---"  { exit }
    inside {
      prefix = key ": "
      if (index($0, prefix) == 1) {
        v = substr($0, length(prefix) + 1)
        if (substr(v, 1, 1) == "\"" && substr(v, length(v), 1) == "\"")
          v = substr(v, 2, length(v) - 2)
        print v
        exit
      }
    }
  ' "$2"
}

# body_raw FILE — everything after the closing ---, leading blank lines dropped.
body_raw() {
  awk '
    NR == 1 && $0 == "---" { inside = 1; next }
    inside && $0 == "---"  { inside = 0; started = 1; next }
    !started { next }
    started && !seen && $0 ~ /^[[:space:]]*$/ { next }
    { seen = 1; print }
  ' "$1"
}

# indent2 — indent stdin two spaces, leaving blank lines truly blank so the
# result nests cleanly under a YAML literal block scalar.
indent2() {
  awk '{ if (length($0) > 0) print "  " $0; else print "" }'
}

# escape_jinja — neutralise literal {{ and {% so Goose's template renderer emits
# them as text. Only the opening delimiter needs escaping: `{{'{{'}}segment}}`
# renders as `{{segment}}`. sed does not rescan its own replacement text, so the
# `{{` introduced by the replacement is not re-matched.
escape_jinja() {
  sed -e "s|{{|{{'{{'}}|g" -e "s|{%|{{'{%'}}|g"
}

# ── recipe emitters ───────────────────────────────────────────────────────────

WRITTEN=0
UNCHANGED=0
SKIPPED=0
AGENT_COUNT=0
COMMAND_COUNT=0

TMP="$(mktemp -d)"
cleanup() { rm -rf "$TMP"; }
trap cleanup EXIT

# publish STAGED_FILE DEST_NAME — copy if changed, tally the result.
publish() {
  local staged="$1" dest="${OUT_DIR}/$2"
  if [[ -f "$dest" ]] && cmp -s "$staged" "$dest"; then
    UNCHANGED=$((UNCHANGED + 1))
  else
    cp "$staged" "$dest"
    WRITTEN=$((WRITTEN + 1))
    say "  WRITTEN : $2"
  fi
}

mkdir -p "$OUT_DIR"

say "── gen-goose-recipes.sh ────────────────────────────────────"
say "Output : ${OUT_DIR}"
[[ -n "$PLUGIN_ROOT" ]] && say "Plugin : ${PLUGIN_ROOT}"

shopt -s nullglob

# ── agent personas ────────────────────────────────────────────────────────────

if [[ "$DO_AGENTS" -eq 1 ]]; then
  AGENTS_DIR="${REPO_ROOT}/${ASSET_AGENTS}"
  [[ -d "$AGENTS_DIR" ]] || { echo "Error: agents dir not found: ${AGENTS_DIR}" >&2; exit 1; }

  for src in "$AGENTS_DIR"/*.md; do
    stem="$(basename "$src" .md)"
    name="$(fm_get name "$src")"
    description="$(fm_get description "$src")"
    model="$(fm_get model "$src")"
    tools="$(fm_get tools "$src")"

    if [[ -z "$name" || -z "$description" ]]; then
      say "  SKIP    : ${ASSET_AGENTS}/${stem}.md (missing name or description)"
      SKIPPED=$((SKIPPED + 1))
      continue
    fi

    # Namespaced so agent and command recipes cannot collide: agents/uncle-senior.md
    # and commands/uncle-senior.md would otherwise both want uncle-senior.yaml.
    out_name="uncle-dev-agent-${name}.yaml"
    staged="${TMP}/${out_name}"

    {
      echo "# GENERATED by scripts/gen-goose-recipes.sh — do not edit."
      echo "# Source: ${ASSET_AGENTS}/${stem}.md"
      [[ -n "$model" ]] && echo "# Claude model hint (no portable Goose equivalent): ${model}"
      [[ -n "$tools" ]] && echo "# Claude tool allowlist (not enforced by this recipe): ${tools}"
      echo "version: ${PLUGIN_VERSION}"
      echo "title: ${name}"
      echo "description: |-"
      printf '  %s\n' "$description"
      echo "instructions: |"
      body_raw "$src" | escape_jinja | indent2
      echo "prompt: |"
      echo "  {{ task }}"
      echo "parameters:"
      echo "  - key: task"
      echo "    input_type: string"
      echo "    requirement: user_prompt"
      echo "    description: |-"
      printf '      What you want %s to work on.\n' "$name"
      echo "activities:"
      echo "  - \"message: uncle-dev ${name} — see the recipe description for scope.\""
    } > "$staged"

    publish "$staged" "$out_name"
    AGENT_COUNT=$((AGENT_COUNT + 1))
  done
fi

# ── slash commands ────────────────────────────────────────────────────────────

if [[ "$DO_COMMANDS" -eq 1 ]]; then
  COMMANDS_DIR="${REPO_ROOT}/${ASSET_COMMANDS_ROOT}"
  [[ -d "$COMMANDS_DIR" ]] || { echo "Error: commands dir not found: ${COMMANDS_DIR}" >&2; exit 1; }

  for src in "$COMMANDS_DIR"/*.md; do
    stem="$(basename "$src" .md)"
    description="$(fm_get description "$src")"
    arg_hint="$(fm_get argument-hint "$src")"

    if [[ -z "$description" ]]; then
      say "  SKIP    : ${ASSET_COMMANDS_ROOT}/${stem}.md (missing description)"
      SKIPPED=$((SKIPPED + 1))
      continue
    fi

    [[ -n "$arg_hint" ]] || arg_hint="Optional arguments for /${stem} (leave empty for none)."

    out_name="${stem}.yaml"
    staged="${TMP}/${out_name}"

    {
      echo "# GENERATED by scripts/gen-goose-recipes.sh — do not edit."
      echo "# Source: ${ASSET_COMMANDS_ROOT}/${stem}.md"
      echo "# Claude Code equivalent: /${stem}"
      echo "version: ${PLUGIN_VERSION}"
      echo "title: ${stem}"
      echo "description: |-"
      printf '  %s\n' "$description"
      echo "instructions: |"
      body_raw "$src" \
        | escape_jinja \
        | sed -e 's|\$ARGUMENTS|{{ arguments }}|g' \
              -e "s|\${CLAUDE_PLUGIN_ROOT:-}|\${CLAUDE_PLUGIN_ROOT:-${PLUGIN_ROOT}}|g" \
              -e "s|\${CLAUDE_PLUGIN_ROOT}|\${CLAUDE_PLUGIN_ROOT:-${PLUGIN_ROOT}}|g" \
        | indent2
      echo "prompt: |"
      printf '  Run the /%s workflow exactly as described in your instructions.\n' "$stem"
      echo "  Arguments: {{ arguments }}"
      echo "parameters:"
      echo "  - key: arguments"
      echo "    input_type: string"
      echo "    requirement: optional"
      echo "    default: \"\""
      echo "    description: |-"
      printf '      %s\n' "$arg_hint"
      echo "activities:"
      echo "  - \"message: uncle-dev /${stem} — see the recipe description for scope.\""
    } > "$staged"

    publish "$staged" "$out_name"
    COMMAND_COUNT=$((COMMAND_COUNT + 1))
  done
fi

# ── prune stale recipes ───────────────────────────────────────────────────────
#
# Only files this script generated are candidates — the recipe directory is
# shared and may hold recipes we do not own.

REMOVED=0
for stale in "$OUT_DIR"/*.yaml; do
  head -1 "$stale" 2>/dev/null | grep -q '^# GENERATED by scripts/gen-goose-recipes.sh' || continue
  [[ -f "${TMP}/$(basename "$stale")" ]] && continue
  # A partial run (--agents-only / --commands-only) must not prune the other kind.
  if [[ "$DO_AGENTS" -eq 0 || "$DO_COMMANDS" -eq 0 ]]; then
    grep -q "^# Source: ${ASSET_AGENTS}/" "$stale" && [[ "$DO_AGENTS" -eq 0 ]] && continue
    grep -q "^# Source: ${ASSET_COMMANDS_ROOT}/" "$stale" && [[ "$DO_COMMANDS" -eq 0 ]] && continue
  fi
  rm "$stale"
  REMOVED=$((REMOVED + 1))
  say "  REMOVED : $(basename "$stale")"
done

shopt -u nullglob

say "───────────────────────────────────────────────────────────"
say "Done: ${AGENT_COUNT} agents, ${COMMAND_COUNT} commands (${WRITTEN} written, ${UNCHANGED} unchanged, ${REMOVED} removed, ${SKIPPED} skipped)."
