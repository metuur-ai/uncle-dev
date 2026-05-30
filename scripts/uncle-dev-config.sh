#!/usr/bin/env bash
# uncle-dev-config.sh — look up any value from .agents/uncle-dev-setup.yaml
#
# Usage:
#   bash uncle-dev-config.sh <key.path> [default]
#   bash uncle-dev-config.sh --list <key.path> [subkey]
#   bash uncle-dev-config.sh --validate
#
# Scalar examples:
#   bash uncle-dev-config.sh preferences.sdd_mode openspec
#   bash uncle-dev-config.sh preferences.graphify false
#   bash uncle-dev-config.sh skills.overrides.uncle-dev-test-driven-development.path
#
# List examples:
#   bash uncle-dev-config.sh --list skills.companions.uncle-dev-test-driven-development path
#   bash uncle-dev-config.sh --list skills.companions.uncle-dev-test-driven-development
#
# Output: scalar — the value on stdout, or the default (empty string if not provided)
#         list — one subkey per line if subkey given; one compact-JSON object per line otherwise
# Exit:   0 for key lookup (callers should not fail on missing/invalid config)
#         0/1 for --validate

set -euo pipefail

KEY_PATH="${1:-}"
DEFAULT="${2:-}"
CONFIG_FILE=".agents/uncle-dev-setup.yaml"
SCHEMA_FILE="scripts/uncle-dev-setup.schema.json"

if [[ "${KEY_PATH}" == "--list" ]]; then
  LIST_KEY="${2:-}"
  LIST_SUBKEY="${3:-}"

  if [[ -z "${LIST_KEY}" ]]; then
    echo "Usage: uncle-dev-config.sh --list <key.path> [subkey]" >&2
    exit 1
  fi

  if [[ ! -f "${CONFIG_FILE}" ]]; then
    exit 0
  fi

  python3 - "${LIST_KEY}" "${LIST_SUBKEY}" "${CONFIG_FILE}" <<'PYEOF'
import json
import sys

import yaml

key_path = sys.argv[1]
subkey = sys.argv[2]
conf_file = sys.argv[3]
keys = key_path.split(".")

with open(conf_file, "r", encoding="utf-8") as f:
    data = yaml.safe_load(f) or {}

value = data
for key in keys:
    if isinstance(value, dict) and key in value:
        value = value[key]
    else:
        sys.exit(0)

if not isinstance(value, list):
    sys.exit(0)

for item in value:
    if subkey:
        if isinstance(item, dict):
            sub = item.get(subkey)
            if sub is None:
                print("")
            elif isinstance(sub, bool):
                print("true" if sub else "false")
            elif isinstance(sub, (dict, list)):
                print(json.dumps(sub, separators=(",", ":")))
            else:
                print(sub)
        else:
            print("")
    else:
        if isinstance(item, (dict, list)):
            print(json.dumps(item, separators=(",", ":")))
        elif isinstance(item, bool):
            print("true" if item else "false")
        elif item is None:
            print("")
        else:
            print(item)
PYEOF
  exit 0
fi

if [[ "${KEY_PATH}" == "--validate" ]]; then
  if [[ ! -f "${CONFIG_FILE}" ]]; then
    echo "invalid: missing ${CONFIG_FILE}" >&2
    exit 1
  fi

  if [[ ! -f "${SCHEMA_FILE}" ]]; then
    echo "invalid: missing ${SCHEMA_FILE}" >&2
    exit 1
  fi

  python3 - "${CONFIG_FILE}" "${SCHEMA_FILE}" <<'PYEOF'
import json
import sys

import yaml
from jsonschema import ValidationError, validate

conf_file = sys.argv[1]
schema_file = sys.argv[2]

with open(conf_file, "r", encoding="utf-8") as f:
    config = yaml.safe_load(f) or {}

with open(schema_file, "r", encoding="utf-8") as f:
    schema = json.load(f)

try:
    validate(instance=config, schema=schema)
except ValidationError as exc:
    path = ".".join(str(p) for p in exc.path)
    if path:
        print(f"invalid: {path}: {exc.message}", file=sys.stderr)
    else:
        print(f"invalid: {exc.message}", file=sys.stderr)
    sys.exit(1)

print("valid")
PYEOF
  exit $?
fi

if [[ -z "${KEY_PATH}" ]]; then
  echo "Usage: uncle-dev-config.sh <key.path> [default]" >&2
  echo "       uncle-dev-config.sh --validate" >&2
  exit 1
fi

if [[ ! -f "${CONFIG_FILE}" ]]; then
  echo "${DEFAULT}"
  exit 0
fi

# Validate config when schema exists. If invalid, return default for safety.
if [[ -f "${SCHEMA_FILE}" ]]; then
  if ! python3 - "${CONFIG_FILE}" "${SCHEMA_FILE}" <<'PYEOF'
import json
import sys

import yaml
from jsonschema import ValidationError, validate

conf_file = sys.argv[1]
schema_file = sys.argv[2]

with open(conf_file, "r", encoding="utf-8") as f:
    config = yaml.safe_load(f) or {}

with open(schema_file, "r", encoding="utf-8") as f:
    schema = json.load(f)

try:
    validate(instance=config, schema=schema)
except ValidationError as exc:
    path = ".".join(str(p) for p in exc.path)
    if path:
        print(f"invalid config: {path}: {exc.message}", file=sys.stderr)
    else:
        print(f"invalid config: {exc.message}", file=sys.stderr)
    sys.exit(1)
PYEOF
  then
    echo "${DEFAULT}"
    exit 0
  fi
fi

# Use Python for reliable YAML key traversal — no yq dependency.
python3 - "${KEY_PATH}" "${DEFAULT}" "${CONFIG_FILE}" <<'PYEOF'
import sys

import yaml

key_path = sys.argv[1]
default = sys.argv[2]
conf_file = sys.argv[3]
keys = key_path.split(".")

with open(conf_file, "r", encoding="utf-8") as f:
    data = yaml.safe_load(f) or {}

value = data
for key in keys:
    if isinstance(value, dict) and key in value:
        value = value[key]
    else:
        print(default)
        sys.exit(0)

if value is None:
    print(default)
elif isinstance(value, bool):
    print("true" if value else "false")
elif isinstance(value, (dict, list)):
    print(default)
else:
    print(value)
PYEOF
