#!/bin/bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"

FORCE=0
SCOPE="local"
WORKSPACE_WAS_OMITTED=0

usage() {
  cat <<'EOF'
Usage:
  ./scripts/install-plugin.sh [--scope local|global] <target[,target...]> [workspace]
  ./scripts/install-plugin.sh [--scope local|global] all [workspace]

Targets:
  copilot
  cursor
  gemini
  getting-started
  windsurf
  opencode
  all

Examples:
  ./scripts/install-plugin.sh cursor ~/code/my-app
  ./scripts/install-plugin.sh --scope global gemini
  ./scripts/install-plugin.sh copilot,opencode ~/code/my-app
  ./scripts/install-plugin.sh all .

Options:
  --scope   Install into a project (`local`) or a home-level tool directory (`global`)
  --force   Overwrite files that already exist
  -h, --help  Show this help message
EOF
}

log() {
  echo "$*" >&2
}

fail() {
  log "Error: $*"
  exit 1
}

infer_target_from_path() {
  local path="$1"
  case "$path" in
    */.config/opencode/*)
      printf '%s\n' "OpenCode"
      ;;
    *)
      printf '%s\n' "the target tool"
      ;;
  esac
}

handle_existing_file_conflict() {
  local src="$1"
  local dest="$2"

  if [[ "$(basename "$dest")" == "AGENTS.md" ]]; then
    local target_tool
    target_tool="$(infer_target_from_path "$dest")"
    log "Conflict: existing file differs: $dest"
    log "The installed AGENTS.md differs from the source copy."
    log "Replace it with the version from $target_tool?"
    log "  source: $src"
    if confirm "Replace $dest?"; then
      cp "$src" "$dest"
      return 0
    fi
  fi

  fail "Refusing to overwrite existing file: $dest (rerun with --force)"
}

confirm() {
  local prompt="$1"
  local reply
  read -r -p "$prompt [y/N] " reply
  case "$reply" in
    y|Y|yes|YES)
      return 0
      ;;
    *)
      fail "Aborted"
      ;;
  esac
}

require_local_scope() {
  local target="$1"
  if [[ "$SCOPE" != "local" ]]; then
    fail "Target '$target' only supports --scope local"
  fi
}

scope_root() {
  local local_root="$1"
  local global_root="$2"
  if [[ "$SCOPE" == "global" ]]; then
    printf '%s\n' "$global_root"
  else
    printf '%s\n' "$local_root"
  fi
}

same_file_content() {
  local src="$1"
  local dest="$2"
  [[ -f "$dest" ]] && cmp -s "$src" "$dest"
}

copy_file() {
  local src="$1"
  local dest="$2"
  mkdir -p "$(dirname "$dest")"

  if same_file_content "$src" "$dest"; then
    return 0
  fi

  if [[ -e "$dest" && "$FORCE" -ne 1 ]]; then
    handle_existing_file_conflict "$src" "$dest"
    return 0
  fi

  cp "$src" "$dest"
}

copy_path() {
  local src="$1"
  local dest="$2"

  if [[ -d "$src" ]]; then
    if [[ -e "$dest" && ! -d "$dest" ]]; then
      if [[ "$FORCE" -ne 1 ]]; then
        fail "Refusing to overwrite existing file with directory: $dest (rerun with --force)"
      fi
      rm -f "$dest"
    fi

    mkdir -p "$dest"

    local entry
    for entry in "$src"/*; do
      copy_path "$entry" "$dest/$(basename "$entry")"
    done
    return 0
  fi

  copy_file "$src" "$dest"
}

copy_dir_contents() {
  local src_dir="$1"
  local dest_dir="$2"

  mkdir -p "$dest_dir"

  local entry
  for entry in "$src_dir"/*; do
    local name
    name="$(basename "$entry")"
    local dest="$dest_dir/$name"
    copy_path "$entry" "$dest"
  done
}

write_file() {
  local dest="$1"
  local content="$2"

  mkdir -p "$(dirname "$dest")"

  if [[ -f "$dest" ]] && printf '%s' "$content" | cmp -s - "$dest"; then
    return 0
  fi

  if [[ -e "$dest" && "$FORCE" -ne 1 ]]; then
    fail "Refusing to overwrite existing file: $dest (rerun with --force)"
  fi

  printf '%s' "$content" > "$dest"
}

install_copilot() {
  local workspace="$1"
  require_local_scope "copilot"
  log "Installing for GitHub Copilot in $workspace"

  copy_file \
    "$REPO_ROOT/skills/test-driven-development/SKILL.md" \
    "$workspace/.github/skills/test-driven-development/SKILL.md"
  copy_file \
    "$REPO_ROOT/skills/code-review-and-quality/SKILL.md" \
    "$workspace/.github/skills/code-review-and-quality/SKILL.md"
  copy_file \
    "$REPO_ROOT/agents/code-reviewer.md" \
    "$workspace/.github/agents/code-reviewer.md"
  copy_file \
    "$REPO_ROOT/agents/test-engineer.md" \
    "$workspace/.github/agents/test-engineer.md"
  copy_file \
    "$REPO_ROOT/agents/security-auditor.md" \
    "$workspace/.github/agents/security-auditor.md"
}

install_cursor() {
  local workspace="$1"
  require_local_scope "cursor"
  log "Installing for Cursor in $workspace"

  copy_file \
    "$REPO_ROOT/skills/test-driven-development/SKILL.md" \
    "$workspace/.cursor/rules/test-driven-development.md"
  copy_file \
    "$REPO_ROOT/skills/code-review-and-quality/SKILL.md" \
    "$workspace/.cursor/rules/code-review-and-quality.md"
  copy_file \
    "$REPO_ROOT/skills/incremental-implementation/SKILL.md" \
    "$workspace/.cursor/rules/incremental-implementation.md"
}

install_gemini() {
  local workspace="$1"
  local dest_dir
  dest_dir="$(scope_root "$workspace/.gemini/skills" "$HOME/.gemini/skills")"
  log "Installing for Gemini CLI in $dest_dir"

  copy_dir_contents "$REPO_ROOT/skills" "$dest_dir"
}

install_getting_started() {
  local workspace="$1"
  local base_dir
  base_dir="$(scope_root "$workspace/.agents" "$HOME/.agents")"
  log "Installing a generic agent-skills workspace in $base_dir"

  copy_dir_contents "$REPO_ROOT/skills" "$base_dir/skills"
  copy_dir_contents "$REPO_ROOT/agents" "$base_dir/agents"
  copy_dir_contents "$REPO_ROOT/references" "$base_dir/references"
}

install_windsurf() {
  local workspace="$1"
  require_local_scope "windsurf"
  local rules_dir="$workspace/.windsurf/rules"
  log "Installing for Windsurf in $rules_dir"

  copy_file \
    "$REPO_ROOT/skills/test-driven-development/SKILL.md" \
    "$rules_dir/test-driven-development.md"
  copy_file \
    "$REPO_ROOT/skills/incremental-implementation/SKILL.md" \
    "$rules_dir/incremental-implementation.md"
  copy_file \
    "$REPO_ROOT/skills/code-review-and-quality/SKILL.md" \
    "$rules_dir/code-review-and-quality.md"
}

install_opencode() {
  local workspace="$1"
  local agents_dest
  local skills_dest
  agents_dest="$(scope_root "$workspace/AGENTS.md" "$HOME/.config/opencode/AGENTS.md")"
  skills_dest="$(scope_root "$workspace/.opencode/skills" "$HOME/.config/opencode/skills")"
  log "Installing for OpenCode in $(dirname "$agents_dest")"

  copy_file "$REPO_ROOT/AGENTS.md" "$agents_dest"
  copy_dir_contents "$REPO_ROOT/skills" "$skills_dest"
}

run_target() {
  local target="$1"
  local workspace="$2"

  case "$target" in
    copilot) install_copilot "$workspace" ;;
    cursor) install_cursor "$workspace" ;;
    gemini) install_gemini "$workspace" ;;
    getting-started) install_getting_started "$workspace" ;;
    windsurf) install_windsurf "$workspace" ;;
    opencode) install_opencode "$workspace" ;;
    *)
      fail "Unknown target: $target"
      ;;
  esac
}

TARGETS=()
WORKSPACE=""

while [[ $# -gt 0 ]]; do
  case "$1" in
    --scope)
      shift
      [[ $# -gt 0 ]] || fail "Missing value for --scope"
      case "$1" in
        local|global)
          SCOPE="$1"
          ;;
        *)
          fail "Invalid scope: $1 (expected local or global)"
          ;;
      esac
      shift
      ;;
    --force)
      FORCE=1
      shift
      ;;
    -h|--help)
      usage
      exit 0
      ;;
    *)
      if [[ ${#TARGETS[@]} -eq 0 ]]; then
        IFS=',' read -r -a TARGETS <<< "$1"
      elif [[ -z "$WORKSPACE" ]]; then
        WORKSPACE="$1"
      else
        fail "Unexpected argument: $1"
      fi
      shift
      ;;
  esac
done

if [[ ${#TARGETS[@]} -eq 0 ]]; then
  usage
  exit 1
fi

if [[ "$SCOPE" == "global" && -n "$WORKSPACE" ]]; then
  fail "Do not pass a workspace when using --scope global"
fi

if [[ "$SCOPE" == "local" && -z "$WORKSPACE" ]]; then
  WORKSPACE_WAS_OMITTED=1
  WORKSPACE="."
fi

if [[ "$SCOPE" == "local" ]]; then
  mkdir -p "$WORKSPACE"
  WORKSPACE="$(cd "$WORKSPACE" && pwd)"

  if [[ "$WORKSPACE_WAS_OMITTED" -eq 1 ]]; then
    confirm "No workspace was provided. Install into the current directory: $WORKSPACE?"
  fi

  if [[ "$WORKSPACE" == "$REPO_ROOT" ]]; then
    fail "Refusing to install into the source repository itself. Pass a target project root, for example: ./scripts/install-plugin.sh opencode ~/code/my-app"
  fi
else
  WORKSPACE=""
fi

if [[ "${TARGETS[0]}" == "all" && ${#TARGETS[@]} -eq 1 ]]; then
  TARGETS=(copilot cursor gemini getting-started windsurf opencode)
fi

for target in "${TARGETS[@]}"; do
  run_target "$target" "$WORKSPACE"
done

log "Done."
