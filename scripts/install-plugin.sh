#!/bin/bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"

FORCE=0

usage() {
  cat <<'EOF'
Usage:
  ./scripts/install-plugin.sh <target[,target...]> [workspace]
  ./scripts/install-plugin.sh all [workspace]

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
  ./scripts/install-plugin.sh copilot,opencode ~/code/my-app
  ./scripts/install-plugin.sh all .

Options:
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

copy_file() {
  local src="$1"
  local dest="$2"
  mkdir -p "$(dirname "$dest")"

  if [[ -e "$dest" && "$FORCE" -ne 1 ]]; then
    fail "Refusing to overwrite existing file: $dest (rerun with --force)"
  fi

  cp "$src" "$dest"
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

    if [[ -e "$dest" && "$FORCE" -ne 1 ]]; then
      fail "Refusing to overwrite existing path: $dest (rerun with --force)"
    fi

    cp -R "$entry" "$dest"
  done
}

write_file() {
  local dest="$1"
  local content="$2"

  mkdir -p "$(dirname "$dest")"

  if [[ -e "$dest" && "$FORCE" -ne 1 ]]; then
    fail "Refusing to overwrite existing file: $dest (rerun with --force)"
  fi

  printf '%s' "$content" > "$dest"
}

install_copilot() {
  local workspace="$1"
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
  log "Installing for Gemini CLI in $workspace"

  copy_dir_contents "$REPO_ROOT/skills" "$workspace/.gemini/skills"
}

install_getting_started() {
  local workspace="$1"
  log "Installing a generic agent-skills workspace in $workspace"

  copy_dir_contents "$REPO_ROOT/skills" "$workspace/.agents/skills"
  copy_dir_contents "$REPO_ROOT/agents" "$workspace/.agents/agents"
  copy_dir_contents "$REPO_ROOT/references" "$workspace/.agents/references"
}

install_windsurf() {
  local workspace="$1"
  log "Installing for Windsurf in $workspace"

  local td
  td="$(cat "$REPO_ROOT/skills/test-driven-development/SKILL.md")"
  local ii
  ii="$(cat "$REPO_ROOT/skills/incremental-implementation/SKILL.md")"
  local cr
  cr="$(cat "$REPO_ROOT/skills/code-review-and-quality/SKILL.md")"

  write_file "$workspace/.windsurfrules" "# Essential agent-skills for this project

$td

---

$ii

---

$cr
"
}

install_opencode() {
  local workspace="$1"
  log "Installing for OpenCode in $workspace"

  copy_file "$REPO_ROOT/AGENTS.md" "$workspace/AGENTS.md"
  copy_dir_contents "$REPO_ROOT/skills" "$workspace/skills"
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

if [[ -z "$WORKSPACE" ]]; then
  WORKSPACE="."
fi

mkdir -p "$WORKSPACE"
WORKSPACE="$(cd "$WORKSPACE" && pwd)"

if [[ "${TARGETS[0]}" == "all" && ${#TARGETS[@]} -eq 1 ]]; then
  TARGETS=(copilot cursor gemini getting-started windsurf opencode)
fi

for target in "${TARGETS[@]}"; do
  run_target "$target" "$WORKSPACE"
done

log "Done."
