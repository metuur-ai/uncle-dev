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

# --dump — emit the entire config as JSON on stdout (for the interactive
# configurator to load current values). Missing file -> "{}". Reads only; the
# helper remains the sole reader of the YAML.
if [[ "${KEY_PATH}" == "--dump" ]]; then
  if [[ ! -f "${CONFIG_FILE}" ]]; then
    echo "{}"
    exit 0
  fi
  python3 - "${CONFIG_FILE}" <<'PYEOF'
import json
import sys

import yaml

with open(sys.argv[1], "r", encoding="utf-8") as f:
    data = yaml.safe_load(f) or {}
json.dump(data, sys.stdout)
PYEOF
  exit 0
fi

# --write-doc — read a full config document as JSON from stdin, validate it
# against the schema, and (only if valid) write it to the YAML file atomically.
# This is the SOLE writer of the YAML — the interactive configurator pipes here
# so no other script ever opens the file. Invalid input is rejected without
# touching the existing file.
if [[ "${KEY_PATH}" == "--write-doc" ]]; then
  if [[ ! -f "${SCHEMA_FILE}" ]]; then
    echo "invalid: missing ${SCHEMA_FILE}" >&2
    exit 1
  fi
  python3 - "${CONFIG_FILE}" "${SCHEMA_FILE}" <<'PYEOF'
import json
import os
import sys

import yaml
from jsonschema import ValidationError, validate

conf_file = sys.argv[1]
schema_file = sys.argv[2]

raw = sys.stdin.read()
try:
    config = json.loads(raw)
except json.JSONDecodeError as exc:
    print(f"invalid: stdin is not valid JSON: {exc}", file=sys.stderr)
    sys.exit(1)

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

header = (
    "# .agents/uncle-dev-setup.yaml\n"
    "# yaml-language-server: $schema=../scripts/uncle-dev-setup.schema.json\n"
    "# Uncle Dev project configuration.\n"
    "# Managed by scripts/uncle-dev-configure.py. Hand edits are fine; keep it\n"
    "# schema-valid (bash scripts/uncle-dev-config.sh --validate).\n\n"
)
body = yaml.safe_dump(
    config, sort_keys=False, default_flow_style=False, allow_unicode=True
)

os.makedirs(os.path.dirname(conf_file) or ".", exist_ok=True)
tmp = conf_file + ".tmp"
with open(tmp, "w", encoding="utf-8") as f:
    f.write(header)
    f.write(body)
os.replace(tmp, conf_file)
print("written")
PYEOF
  exit $?
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

# Env-var override tier (scalar lookups only): resolve UNCLE_DEV_<KEY> ahead of
# the YAML file, where <KEY> is the dotted path uppercased with dots->underscores
# (e.g. preferences.sdd_mode -> UNCLE_DEV_PREFERENCES_SDD_MODE). A set, non-empty
# value wins without touching the YAML; an unset/empty var falls through to the
# file. (--list mode handled above is intentionally not env-overridable.)
ENV_KEY="UNCLE_DEV_$(printf '%s' "${KEY_PATH}" | tr '.a-z' '_A-Z')"
if [[ -n "${!ENV_KEY:-}" ]]; then
  echo "${!ENV_KEY}"
  exit 0
fi

# Session-flag tier (execution_profile only): a developer can switch guard
# strictness mid-session via /uncle-dev-mode <strict|balanced|fast>, which writes
# the chosen profile to ${CLAUDE_PROJECT_DIR:-$PWD}/.uncle-dev/session-mode. That
# flag overrides the YAML execution_profile for this session WITHOUT touching the
# YAML (R-7.2, R-7.3). The flag file is not the YAML — reading it keeps the helper
# the sole YAML reader. Tier order: env -> session flag -> YAML -> default.
if [[ "${KEY_PATH}" == "preferences.execution_profile" ]]; then
  SESSION_MODE_FILE="${CLAUDE_PROJECT_DIR:-$PWD}/.uncle-dev/session-mode"
  if [[ -f "${SESSION_MODE_FILE}" ]]; then
    SESSION_MODE="$(head -n1 "${SESSION_MODE_FILE}" 2>/dev/null | tr -d '[:space:]')"
    case "${SESSION_MODE}" in
      strict|balanced|fast)
        echo "${SESSION_MODE}"
        exit 0
        ;;
    esac
  fi
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
