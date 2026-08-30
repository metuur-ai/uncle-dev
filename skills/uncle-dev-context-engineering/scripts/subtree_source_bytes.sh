#!/usr/bin/env bash
# Total bytes of source in a directory subtree.
#
# This is the shared definition of "how big is this subtree" used to decide
# whether a directory has crossed the node-placement threshold in
# uncle-dev-context-engineering (SKILL.md, Mode A Step 3). It lives here rather
# than inside any one caller so the hook and the CLI cannot drift apart on what
# counts as source — a threshold measured two different ways is two thresholds.
#
# Dual mode:
#   source subtree_source_bytes.sh   → defines subtree_source_bytes()
#   bash   subtree_source_bytes.sh D → prints the byte count for D
#
# Sourcing is what callers in a loop should do. The hook walks up to six
# directory levels per edit, and sourcing keeps that in-process instead of
# spawning a subprocess per level.
#
# File sizes come from stat, so no file contents are read — this is a metadata
# walk, not a content walk, and stays cheap on large trees.
#
# Scope note: this counts code only. estimate_tokens.sh deliberately counts a
# wider set (docs, JSON, YAML, TOML) because it answers "how much would an agent
# have to read here", which includes prose. Keep the two in mind as different
# questions rather than syncing one to the other.
#
# macOS compatibility: must run under /bin/bash 3.2. No mapfile, no associative
# arrays, no ${v,,}.

# stat prints file size with -f%z on BSD/macOS and -c%s on GNU/Linux. Resolved
# once at load so the per-call path stays free of probing.
if stat -f%z . >/dev/null 2>&1; then
  SUBTREE_STAT_CMD=(stat -f%z)
else
  SUBTREE_STAT_CMD=(stat -c%s)
fi

# ---------------------------------------------------------------------------
# subtree_source_bytes <dir>
#
# Emits the total size in bytes of source files in <dir> and below, excluding
# vendored, generated, and build-output trees. Prints 0 for a missing or empty
# directory rather than failing, so callers can compare the result numerically
# without guarding it.
# ---------------------------------------------------------------------------
subtree_source_bytes() {
  local dir="$1"
  find "$dir" \
    \( -name node_modules -o -name .git -o -name dist -o -name build \
    -o -name vendor -o -name coverage -o -name .next -o -name target \
    -o -name __pycache__ -o -name .venv -o -name .devlocal \) -prune -o \
    -type f \
    \( -name '*.ts'  -o -name '*.tsx' -o -name '*.js'  -o -name '*.jsx' \
    -o -name '*.py'  -o -name '*.go'  -o -name '*.rs'  -o -name '*.java' \
    -o -name '*.rb'  -o -name '*.kt'  -o -name '*.swift' -o -name '*.cs' \
    -o -name '*.c'   -o -name '*.cpp' -o -name '*.h'   -o -name '*.php' \
    -o -name '*.vue' -o -name '*.svelte' -o -name '*.astro' \
    -o -name '*.sql' -o -name '*.graphql' -o -name '*.prisma' \) \
    -print0 2>/dev/null \
    | xargs -0 "${SUBTREE_STAT_CMD[@]}" 2>/dev/null \
    | awk '{ total += $1 } END { print total + 0 }'
}

# Run as a CLI only when executed directly, so sourcing has no side effects.
if [ "${BASH_SOURCE[0]}" = "$0" ]; then
  if [ -z "$1" ]; then
    echo "usage: subtree_source_bytes.sh <directory>" >&2
    exit 2
  fi
  if [ ! -d "$1" ]; then
    echo "error: not a directory: $1" >&2
    exit 1
  fi
  subtree_source_bytes "$1"
fi
