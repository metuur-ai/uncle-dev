#!/usr/bin/env bash
# split-skill-branch.sh — install-time mode-branch splitter (Unit 3, #9).
#
# Skills are static .md files the host loads verbatim; there is no "on skill
# read" hook, so dual-mode skills are trimmed at INSTALL time. Canonical sources
# keep BOTH branches, delimited by stable HTML-comment markers:
#
#   <!-- UNCLE_DEV:BRANCH:lid-ears:START --> ... <!-- UNCLE_DEV:BRANCH:lid-ears:END -->
#   <!-- UNCLE_DEV:BRANCH:openspec:START --> ... <!-- UNCLE_DEV:BRANCH:openspec:END -->
#
# split_skill_branch <src_file> <dest_file> <sdd_mode>
#   Writes <src_file> to <dest_file> with the INACTIVE branch's marked region
#   (START..END inclusive) removed. The active branch's marker lines are also
#   stripped so the installed copy reads cleanly.
#
#   <sdd_mode> is "lid-ears" or "openspec". The active branch is the one whose
#   name matches the mode; the other is dropped.
#
# Fail-loud (R-3.5): if a required marker pair is absent or unmatched, the
# function errors (returns non-zero) and writes NOTHING to dest — never a
# partially-trimmed copy. Source files that contain no branch markers at all are
# copied verbatim (a skill may legitimately have no two-branch split).
#
# This helper is sourced, not executed. It writes only to <dest_file>.

# Returns 0 if the file contains ALL four expected markers, 1 if it contains
# NONE, 2 (error) if it contains some-but-not-all (unmatched/partial markers).
_split_marker_state() {
  local src="$1"
  local le_s le_e os_s os_e count
  le_s=$(grep -cF '<!-- UNCLE_DEV:BRANCH:lid-ears:START -->' "$src")
  le_e=$(grep -cF '<!-- UNCLE_DEV:BRANCH:lid-ears:END -->' "$src")
  os_s=$(grep -cF '<!-- UNCLE_DEV:BRANCH:openspec:START -->' "$src")
  os_e=$(grep -cF '<!-- UNCLE_DEV:BRANCH:openspec:END -->' "$src")
  count=$((le_s + le_e + os_s + os_e))

  if [[ "$count" -eq 0 ]]; then
    return 1
  fi
  # All four markers must be present exactly once each for a well-formed
  # dual-branch skill. Anything else (a renamed/missing/duplicated marker) is a
  # partial state → fail loud.
  if [[ "$le_s" -eq 1 && "$le_e" -eq 1 && "$os_s" -eq 1 && "$os_e" -eq 1 ]]; then
    return 0
  fi
  return 2
}

split_skill_branch() {
  local src="$1"
  local dest="$2"
  local mode="$3"

  if [[ -z "$src" || -z "$dest" || -z "$mode" ]]; then
    echo "split_skill_branch: usage: split_skill_branch <src> <dest> <sdd_mode>" >&2
    return 1
  fi
  if [[ ! -f "$src" ]]; then
    echo "split_skill_branch: source not found: $src" >&2
    return 1
  fi

  local drop active
  case "$mode" in
    lid-ears) active="lid-ears"; drop="openspec" ;;
    openspec) active="openspec"; drop="lid-ears" ;;
    *)
      echo "split_skill_branch: unknown sdd_mode '$mode' (expected lid-ears|openspec)" >&2
      return 1
      ;;
  esac

  _split_marker_state "$src"
  local state=$?
  if [[ "$state" -eq 1 ]]; then
    # No branch markers at all — not a dual-branch skill. Copy verbatim.
    mkdir -p "$(dirname "$dest")"
    cp "$src" "$dest"
    return 0
  fi
  if [[ "$state" -eq 2 ]]; then
    echo "split_skill_branch: branch markers absent or unmatched in $src — refusing to ship a partially-trimmed copy" >&2
    return 1
  fi

  # state==0: well-formed dual-branch skill. Build the trimmed copy in a temp
  # file, then move into place so a failure never leaves a partial dest.
  local tmp
  tmp="$(mktemp)" || { echo "split_skill_branch: mktemp failed" >&2; return 1; }

  awk -v drop="$drop" -v active="$active" '
    BEGIN {
      drop_start  = "<!-- UNCLE_DEV:BRANCH:" drop ":START -->"
      drop_end    = "<!-- UNCLE_DEV:BRANCH:" drop ":END -->"
      act_start   = "<!-- UNCLE_DEV:BRANCH:" active ":START -->"
      act_end     = "<!-- UNCLE_DEV:BRANCH:" active ":END -->"
      in_drop = 0
    }
    index($0, drop_start) { in_drop = 1; next }   # drop the inactive region (inclusive)
    index($0, drop_end)   { in_drop = 0; next }
    in_drop               { next }
    index($0, act_start)  { next }                # strip active markers, keep content
    index($0, act_end)    { next }
    { print }
  ' "$src" > "$tmp" || { rm -f "$tmp"; echo "split_skill_branch: awk failed on $src" >&2; return 1; }

  mkdir -p "$(dirname "$dest")"
  mv "$tmp" "$dest" || { rm -f "$tmp"; echo "split_skill_branch: failed to write $dest" >&2; return 1; }
  return 0
}
