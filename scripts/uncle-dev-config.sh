#!/usr/bin/env bash
# uncle-dev-config.sh — look up any value from .agents/uncle-dev-setup.yaml
#
# Usage:
#   bash uncle-dev-config.sh <key.path> [default]
#
# Examples:
#   bash uncle-dev-config.sh preferences.sdd_mode openspec
#   bash uncle-dev-config.sh preferences.graphify false
#   bash uncle-dev-config.sh project.language
#   bash uncle-dev-config.sh hooks.session_start true
#
# Output: the value on stdout, or the default (empty string if not provided)
# Exit:   0 always (callers should not fail on missing config)

set -euo pipefail

KEY_PATH="${1:-}"
DEFAULT="${2:-}"

if [[ -z "${KEY_PATH}" ]]; then
  echo "Usage: uncle-dev-config.sh <key.path> [default]" >&2
  exit 1
fi

CONFIG_FILE=".agents/uncle-dev-setup.yaml"

if [[ ! -f "${CONFIG_FILE}" ]]; then
  echo "${DEFAULT}"
  exit 0
fi

# Use Python for reliable YAML key traversal — no yq dependency.
python3 - "${KEY_PATH}" "${DEFAULT}" "${CONFIG_FILE}" <<'PYEOF'
import sys, re

key_path  = sys.argv[1]
default   = sys.argv[2]
conf_file = sys.argv[3]
keys      = key_path.split(".")

def strip_value(raw):
    """Strip quotes and inline comments from a YAML scalar."""
    v = raw.strip()
    if v.startswith('"') or v.startswith("'"):
        v = re.sub(r'^["\']|["\'].*$', '', v)
        return v.split('"')[0].split("'")[0].strip()
    # Remove inline comment
    m = re.match(r'^([^#]+)', v)
    return m.group(1).strip() if m else v

with open(conf_file) as f:
    lines = f.readlines()

# Walk the YAML line by line tracking indent depth.
# We match keys in order: keys[0] at root, keys[1] nested inside, etc.
depth      = 0          # how many keys we've matched so far
parent_ind = -1         # indent of the last matched parent key

for line in lines:
    stripped = line.rstrip()
    if not stripped or stripped.lstrip().startswith("#"):
        continue

    indent  = len(line) - len(line.lstrip())
    content = stripped.lstrip()

    # If we've gone back to or above the parent indent, reset depth
    if depth > 0 and indent <= parent_ind:
        depth      = 0
        parent_ind = -1

    target = keys[depth]
    pattern = re.compile(r'^' + re.escape(target) + r'\s*:(.*)')
    m = pattern.match(content)
    if not m:
        continue

    if depth == len(keys) - 1:
        # Final key — emit value
        value = m.group(1).strip()
        print(strip_value(value) if value else default)
        sys.exit(0)
    else:
        # Intermediate key — go deeper
        parent_ind = indent
        depth += 1

print(default)
PYEOF
