#!/usr/bin/env bash
# uncle-dev-config-write.sh — read/write helper for the interactive configurator.
#
# This is a SEPARATE helper from uncle-dev-config.sh (the read helper used by
# every skill/command/hook). Keeping the write path here means the shared read
# helper stays untouched. Only the interactive TUI (uncle-dev-configure.py)
# calls this script.
#
# Usage:
#   bash uncle-dev-config-write.sh --dump                  # whole config as JSON
#   echo '<json>' | bash uncle-dev-config-write.sh --write-doc   # validate + write
#
# --dump      emits the entire config as JSON on stdout ("{}" if the file is
#             missing) so the TUI can load current values.
# --write-doc reads a full config document as JSON on stdin, validates it
#             against the schema, and writes it to the YAML file atomically —
#             only if valid. Invalid input is rejected and the existing file is
#             left untouched.
#
# Exit: 0 on success, 1 on invalid input / missing schema / bad usage.

set -euo pipefail

MODE="${1:-}"
# CONFIG_FILE is relative to cwd (the project being configured). SCHEMA_FILE
# defaults to the repo layout but can be overridden with an absolute path when
# the schema is bundled elsewhere (e.g. installed as a plugin) — the TUI sets
# UNCLE_DEV_SCHEMA_FILE so validation works from any project directory.
CONFIG_FILE="${UNCLE_DEV_CONFIG_FILE:-.agents/uncle-dev-setup.yaml}"
SCHEMA_FILE="${UNCLE_DEV_SCHEMA_FILE:-scripts/uncle-dev-setup.schema.json}"

case "${MODE}" in
  --dump)
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
    ;;

  --write-doc)
    if [[ ! -f "${SCHEMA_FILE}" ]]; then
      echo "invalid: missing ${SCHEMA_FILE}" >&2
      exit 1
    fi
    # Read the piped document into a bash var first: the heredoc below occupies
    # python's stdin (it carries the program), so the JSON is handed over via an
    # env var instead of stdin.
    DOC_JSON="$(cat)"
    UNCLE_DEV_DOC_JSON="${DOC_JSON}" python3 - "${CONFIG_FILE}" "${SCHEMA_FILE}" <<'PYEOF'
import json
import os
import sys

import yaml
from jsonschema import ValidationError, validate

conf_file = sys.argv[1]
schema_file = sys.argv[2]

raw = os.environ.get("UNCLE_DEV_DOC_JSON", "")
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
    ;;

  *)
    echo "Usage: uncle-dev-config-write.sh --dump | --write-doc" >&2
    exit 1
    ;;
esac
