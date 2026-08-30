#!/bin/bash
# code-context pre-edit hook — PreToolUse Edit|Write
#
# Three jobs, in priority order:
#   1. AGENTS.md exists for the target directory  → remind the agent to read it,
#      and flag any paths it names that no longer exist (staleness).
#   2. No AGENTS.md covers the target directory   → name the BOUNDARY that
#      should own a node and tell the agent to create it there.
#   3. Anything else                              → silent exit 0.
#
# Nodes belong at boundaries, not in every directory. Where a boundary is comes
# from uncle-dev-context-engineering (SKILL.md, "When to create a child node"):
# a subtree at/above 20k tokens, or a point where responsibility shifts — of
# which a package root is the explicit form. Below that, no node, no advisory.
#
# Reads the file_path from the JSON tool input on stdin (Claude Code contract).
#
# macOS compatibility: must run under /bin/bash 3.2. No mapfile, no associative
# arrays, no ${v,,}.

# shellcheck source=lib/hook-contract.sh
source "${BASH_SOURCE%/*}/lib/hook-contract.sh"

# subtree_source_bytes() is owned by the uncle-dev-context-engineering skill so
# the hook and the CLI measure the threshold the same way. Sibling path first —
# hooks/ and skills/ ship together, the same assumption hook-contract.sh above
# already makes — then the installed-plugin and repo-root layouts.
SUBTREE_LIB=""
for _candidate in \
  "${BASH_SOURCE%/*}/../skills/uncle-dev-context-engineering/scripts/subtree_source_bytes.sh" \
  "${CLAUDE_PLUGIN_ROOT:-}/skills/uncle-dev-context-engineering/scripts/subtree_source_bytes.sh" \
  "$HOME/.claude/plugins/cache/uncle-dev-agent-skills/uncle-dev/skills/uncle-dev-context-engineering/scripts/subtree_source_bytes.sh"
do
  if [ -n "$_candidate" ] && [ -f "$_candidate" ]; then
    SUBTREE_LIB="$_candidate"
    break
  fi
done
# shellcheck source=../skills/uncle-dev-context-engineering/scripts/subtree_source_bytes.sh
[ -n "$SUBTREE_LIB" ] && source "$SUBTREE_LIB"

hook_read_input

[ -z "$HOOK_FILE_PATH" ] && exit 0

DIR="$(dirname "$HOOK_FILE_PATH")"
AGENTS_MD="$DIR/AGENTS.md"

# Resolved here rather than in Case 2 because Case 1 needs it too: the root
# node is exempt from the line cap, and Case 1 cannot tell root from child
# without it. Assignment only — the "is this an uncle-dev project" gate stays
# in Case 2, so Case 1 keeps behaving the same outside uncle-dev repos.
PROJECT_ROOT="${PROJECT_DIR:-${CLAUDE_PROJECT_DIR:-$(pwd)}}"

# Max stale paths listed in one advisory — enough to prove the file has drifted
# without pasting an entire dead file map into context.
STALE_REPORT_LIMIT=5

# Hard cap on node size, from uncle-dev-context-engineering (SKILL.md, Mode A
# Step 4). A node is read before every edit in its directory, so an oversized
# one gets skimmed rather than read — it is less effective, not more thorough.
# Over the cap the fix is always to reword, never to raise the number.
NODE_MAX_LINES=60

# Node-placement threshold, taken from the uncle-dev-context-engineering skill
# (SKILL.md "When to create a child node") and estimate_tokens.sh:
#   < 20k tokens  → no node needed
#   20–64k tokens → one node
#   > 64k tokens  → split into child nodes
# Tokens are estimated at ~4 bytes each, so 20k tokens ≈ 80000 bytes of source.
# Measured over the directory's whole subtree by subtree_source_bytes(), which
# the skill owns (scripts/subtree_source_bytes.sh) and this hook sources above.
NODE_THRESHOLD_BYTES=80000

# How far up the tree to look for the boundary that should own the node.
# Bounded so a deep path cannot turn one edit into an unbounded walk.
MAX_WALK_DEPTH=6

# ---------------------------------------------------------------------------
# find_stale_paths <agents_md>
#
# Emits, one per line, each backtick-quoted relative path in the AGENTS.md that
# has an extension and no longer resolves on disk. A file map that names files
# which moved is worse than no file map: the agent goes looking for them.
#
# Only backtick-quoted tokens containing a dot and no spaces are considered, so
# prose is never mistaken for a path. Absolute paths, URLs, and globs are
# skipped — they are not this directory's claims to verify.
# ---------------------------------------------------------------------------
find_stale_paths() {
  local md="$1"
  local md_dir
  md_dir="$(dirname "$md")"

  grep -o '`[^`]*`' "$md" 2>/dev/null \
    | tr -d '`' \
    | while IFS= read -r token; do
        case "$token" in
          ""|*" "*|/*|*"://"*|*"*"*|*"?"*|*/) continue ;;
        esac
        # The FINAL segment must carry an extension. Without this, a directory
        # reference in an anti-pattern rule (`../internal/`) is read as a file
        # claim and reported as drift, which it is not.
        case "${token##*/}" in
          *.*) ;;
          *) continue ;;
        esac
        # Strip a leading ./ so ./db/client.ts and db/client.ts both resolve.
        token="${token#./}"
        if [ ! -e "${md_dir}/${token}" ]; then
          printf '%s\n' "$token"
        fi
      done
}

# (coverage and boundary resolution are a single upward walk — see
#  resolve_context_action below. They cannot be separate checks: a root node
#  would otherwise suppress the advisory for an uncovered package beneath it.)

# ---------------------------------------------------------------------------
# is_project_root <dir> <root>
#
# True when <dir> is the project root. Compared after resolving both to
# physical paths, because the tool input may hand us a relative path while
# PROJECT_DIR is absolute, and a string compare would then miss the root and
# wrongly apply the child-node line cap to it.
# ---------------------------------------------------------------------------
is_project_root() {
  local dir="$1" root="$2"
  [ "$dir" = "$root" ] && return 0
  local rd rr
  rd="$(cd "$dir" 2>/dev/null && pwd -P)" || return 1
  rr="$(cd "$root" 2>/dev/null && pwd -P)" || return 1
  [ -n "$rd" ] && [ "$rd" = "$rr" ]
}

# ---------------------------------------------------------------------------
# hook_can_measure_subtree
#
# True when the skill's subtree_source_bytes() was sourced successfully. Guards
# the size branch so an unresolvable library degrades the hook to package-root
# detection instead of erroring on every edit.
# ---------------------------------------------------------------------------
hook_can_measure_subtree() {
  command -v subtree_source_bytes >/dev/null 2>&1
}

# ---------------------------------------------------------------------------
# is_package_root <dir>
#
# True when the directory carries a package manifest. The skill treats a shift
# in responsibility at a directory boundary as node-worthy independent of size,
# and a package root is that boundary made explicit. This is what catches a
# newly created package before it has grown past the token threshold.
# ---------------------------------------------------------------------------
is_package_root() {
  local dir="$1"
  [ -f "${dir}/package.json" ] || [ -f "${dir}/Cargo.toml" ] \
    || [ -f "${dir}/go.mod" ] || [ -f "${dir}/pyproject.toml" ]
}

# ---------------------------------------------------------------------------
# resolve_context_action <dir> <root>
#
# One upward walk from <dir> toward <root>, stopping at whichever comes first:
#
#   a node        → echoes nothing (the path is covered; stay silent)
#   a boundary    → echoes that directory (it should own a node)
#   the root      → echoes nothing (nothing on this path warrants a node)
#
# Order matters and is why this is one walk rather than two checks. Asking
# "is anything above me covered?" first would let a root node silence an
# uncovered package below it — exactly the state that let three packages sit
# at zero coverage. The nearest node above wins; failing that, the nearest
# boundary is the one that needs a node.
#
# Walking up at all is what keeps nodes at boundaries rather than leaves: a
# 6k-token directory inside a large package never gets its own node, the
# package root above it does.
# ---------------------------------------------------------------------------
resolve_context_action() {
  local dir="$1"
  local root="$2"
  local depth=0

  while [ -n "$dir" ] && [ "$dir" != "/" ] && [ "$depth" -lt "$MAX_WALK_DEPTH" ]; do
    # Covered by a node at this level.
    [ -f "${dir}/AGENTS.md" ] && return 0
    # At the project root, CLAUDE.md is the root context node — detect_state.sh
    # resolves the root file the same way.
    [ "$dir" = "$root" ] && [ -f "${dir}/CLAUDE.md" ] && return 0

    # Uncovered. Is this level a boundary that should own one?
    # If the skill's measurement library was unreachable, fall back to the
    # package-root signal alone: a quieter hook is the right failure mode for
    # a missing dependency, and duplicating the size logic here to cover that
    # case would reintroduce the drift the shared library exists to prevent.
    if is_package_root "$dir" \
       || { hook_can_measure_subtree \
            && [ "$(subtree_source_bytes "$dir")" -ge "$NODE_THRESHOLD_BYTES" ]; }; then
      printf '%s\n' "$dir"
      return 0
    fi

    [ "$dir" = "$root" ] && return 0
    dir="$(dirname "$dir")"
    depth=$((depth + 1))
  done
  return 0
}

# ---------------------------------------------------------------------------
# Case 1 — a node exists. Remind, then append any defects found in the node
# itself. hook_advise exits, so everything the agent needs must be composed
# into one message rather than emitted as several.
# ---------------------------------------------------------------------------
if [ -f "$AGENTS_MD" ]; then
  ADVISORY="code-context: AGENTS.md exists for the directory you are about to edit.
Read it before making changes: ${AGENTS_MD}"

  # awk over wc -l: awk counts a final line with no trailing newline, which
  # wc -l does not, and an off-by-one at the cap boundary is exactly the case
  # this check exists to catch.
  # The root node is exempt. It carries what applies project-wide — stack,
  # commands, conventions, boundaries, the index of child nodes — and in an
  # OpenCode or Codex project it is the only rules file there is. The cap
  # exists to stop a *child* node from sprawling, and capping the root would
  # push that content somewhere worse.
  NODE_LINES="$(awk 'END { print NR }' "$AGENTS_MD" 2>/dev/null || echo 0)"
  if [ "$NODE_LINES" -gt "$NODE_MAX_LINES" ] \
     && ! is_project_root "$DIR" "$PROJECT_ROOT"; then
    ADVISORY="${ADVISORY}

OVERSIZED — this node is ${NODE_LINES} lines, over the ${NODE_MAX_LINES}-line cap.
Reword it to fit in this turn. Do NOT raise the cap. In order:
  1. Delete file listings — usually the whole overage, and they rot anyway
  2. Delete anti-patterns with no real incident behind them
  3. Still over? It covers two areas — split it into child nodes at the
     next boundary down
Target 20-40 lines. Purpose, contracts, and invariants are what must survive."
  fi

  STALE="$(find_stale_paths "$AGENTS_MD" | head -n "$STALE_REPORT_LIMIT")"
  if [ -n "$STALE" ]; then
    STALE_COUNT="$(printf '%s\n' "$STALE" | wc -l | tr -d ' ')"
    ADVISORY="${ADVISORY}

STALE — this file names ${STALE_COUNT}+ path(s) that no longer exist:
$(printf '%s\n' "$STALE" | sed 's/^/  - /')

Treat its file references as unreliable. Fix the drift in this turn: remove the
dead entries, or replace the listing with durable invariants that do not rot."
  fi

  hook_advise "$ADVISORY"
fi

# ---------------------------------------------------------------------------
# Case 2 — no node. Advise creating one, but only for real, uncovered source
# directories inside an uncle-dev project.
# ---------------------------------------------------------------------------
[ -d "$DIR" ] || exit 0

# Outside an uncle-dev project this hook stays fully silent (R-1.14 spirit):
# no config file means no opinion about that repo's context layer.
[ -f "${PROJECT_ROOT}/.agents/uncle-dev-setup.yaml" ] || exit 0

# Vendored, generated, and build output never gets a node.
case "$DIR" in
  *"/node_modules/"*|*"/node_modules"|*"/dist/"*|*"/dist"|*"/build/"*|*"/build" \
  |*"/.git/"*|*"/vendor/"*|*"/coverage/"*|*"/.next/"*|*"/target/"* \
  |*"/__pycache__"*|*"/.venv/"*|*"/.devlocal/"*)
    exit 0 ;;
esac

# Not every uncovered directory wants a node. Ask where the boundary is; stay
# silent when the path is already covered, or when nothing on it warrants a node.
BOUNDARY="$(resolve_context_action "$DIR" "$PROJECT_ROOT")"
[ -n "$BOUNDARY" ] || exit 0

hook_advise "code-context: no AGENTS.md covers ${DIR} (or any parent up to the project root).

The boundary that should own the node is ${BOUNDARY} — it is a package root or
its subtree is at/above the 20k-token threshold from uncle-dev-context-engineering.
Create ${BOUNDARY}/AGENTS.md before editing. Do NOT add a node to every directory;
nodes belong at boundaries, and the directory you are editing may not be one.

Write durable content — purpose (owns / does NOT own), entry points, contracts
and invariants, anti-patterns. Do NOT write an exhaustive file listing: it goes
stale on the next rename and misleads whoever reads it. Template: the
uncle-dev-context-engineering skill, agents-md-guide.md."
