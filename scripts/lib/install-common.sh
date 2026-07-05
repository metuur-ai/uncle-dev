#!/usr/bin/env bash
# Shared utilities for all uncle-dev install scripts.
# Source this file after sourcing manifest.sh.

log()  { echo "$*" >&2; }
fail() { log "Error: $*"; exit 1; }

# ── core copy helpers ─────────────────────────────────────────────────────────

# copy_file SRC DEST FORCE
# Copies SRC to DEST. Skips if identical. Fails on conflict unless FORCE=1.
copy_file() {
  local src="$1" dest="$2" force="${3:-0}"

  [[ -f "$src" ]] || { log "  SKIP (not found): $src"; return 0; }

  mkdir -p "$(dirname "$dest")"

  if [[ -f "$dest" ]] && cmp -s "$src" "$dest"; then
    return 0
  fi

  if [[ -e "$dest" && "$force" -ne 1 ]]; then
    fail "Refusing to overwrite: $dest (use --force)"
  fi

  cp "$src" "$dest"
}

# copy_dir_contents SRC_DIR DEST_DIR FORCE
# Recursively copies every file in SRC_DIR into DEST_DIR, preserving structure.
copy_dir_contents() {
  local src_dir="$1" dest_dir="$2" force="${3:-0}"

  [[ -d "$src_dir" ]] || { log "  SKIP dir (not found): $src_dir"; return 0; }

  mkdir -p "$dest_dir"

  local nullglob_was_set=0
  shopt -q nullglob && nullglob_was_set=1
  shopt -s nullglob

  local entry name
  for entry in "$src_dir"/*; do
    name="$(basename "$entry")"
    if [[ -d "$entry" ]]; then
      copy_dir_contents "$entry" "$dest_dir/$name" "$force"
    else
      copy_file "$entry" "$dest_dir/$name" "$force"
    fi
  done

  [[ "$nullglob_was_set" -eq 1 ]] || shopt -u nullglob
}

# ── pre-flight validation ─────────────────────────────────────────────────────

# validate_sources REPO_ROOT
# Checks that every mandatory asset source exists. Exits 1 if any are missing.
validate_sources() {
  local root="$1"
  local ok=1

  for asset_dir in "${ASSET_SKILLS_ROOT}" "${ASSET_AGENTS}" "${ASSET_COMMANDS_ROOT}"; do
    [[ -d "${root}/${asset_dir}" ]] || { log "Missing required dir: ${root}/${asset_dir}"; ok=0; }
  done

  [[ -f "${root}/${ASSET_PLUGIN_META}" ]] || { log "Missing plugin manifest: ${root}/${ASSET_PLUGIN_META}"; ok=0; }

  for rule in "${ASSET_RULES[@]}"; do
    [[ -f "${root}/${rule}" ]] || log "  Warning: rules file not found (will be skipped): ${root}/${rule}"
  done

  [[ "$ok" -eq 1 ]] || fail "Pre-flight validation failed — check missing sources above."
}

# ── post-install summary ──────────────────────────────────────────────────────

# count_items PATH
# Returns the number of immediate children (files or dirs) under PATH.
count_items() {
  local path="$1"
  [[ -d "$path" ]] || { echo 0; return; }
  find "$path" -mindepth 1 -maxdepth 1 | wc -l | tr -d ' '
}

# summarize_install DEST_ROOT TOOL_NAME
# Prints a post-install summary with counts for each asset category.
summarize_install() {
  local dest="$1" tool="$2"

  log ""
  log "── ${tool} install summary ──────────────────────────────"
  [[ -d "${dest}/skills" ]]   && log "  Skills    : $(count_items "${dest}/skills") installed"
  [[ -d "${dest}/agents" ]]   && log "  Agents    : $(count_items "${dest}/agents") installed"
  if [[ -d "${dest}/commands" ]]; then
    local top_cmds opsx_cmds
    top_cmds="$(find "${dest}/commands" -maxdepth 1 -name '*.md' | wc -l | tr -d ' ')"
    opsx_cmds=0
    [[ -d "${dest}/commands/opsx" ]] && opsx_cmds="$(count_items "${dest}/commands/opsx")"
    log "  Commands  : ${top_cmds} top-level + ${opsx_cmds} opsx"
  fi
  [[ -d "${dest}/hooks" ]]    && log "  Hooks     : $(count_items "${dest}/hooks") files"

  local rules_found=()
  for rule in "${ASSET_RULES[@]}"; do
    [[ -f "${dest}/${rule}" ]] && rules_found+=("$rule")
  done
  [[ ${#rules_found[@]} -gt 0 ]] && log "  Rules     : ${rules_found[*]}"
  log ""
}
