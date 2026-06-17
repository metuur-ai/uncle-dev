#!/usr/bin/env bash
# run.sh — execute the Unit 9 benchmark and emit the comparison table.
#
# 1. Requires ANTHROPIC_API_KEY (fails loud with a clear message if absent).
# 2. Runs `npx promptfoo eval` with the pinned config, writing results/latest.json.
# 3. Renders the stable arms x tasks Markdown table via report.py.
#
# Usage:
#   ./run.sh              # run the live eval, then print the table
#   ./run.sh --report     # only re-render the table from the last results JSON
set -euo pipefail

BENCH_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "${BENCH_DIR}"

RESULTS_DIR="${BENCH_DIR}/results"
RESULTS_JSON="${RESULTS_DIR}/latest.json"
mkdir -p "${RESULTS_DIR}"

if [[ "${1:-}" == "--report" ]]; then
  if [[ ! -f "${RESULTS_JSON}" ]]; then
    echo "error: ${RESULTS_JSON} not found. Run ./run.sh (without --report) first." >&2
    exit 1
  fi
  python3 report.py "${RESULTS_JSON}"
  exit 0
fi

if [[ -z "${ANTHROPIC_API_KEY:-}" ]]; then
  cat >&2 <<'MSG'
error: ANTHROPIC_API_KEY is not set.

The benchmark runs live Claude evals and needs an Anthropic API key:

    export ANTHROPIC_API_KEY=sk-ant-...
    ./run.sh

To only re-render the table from an existing results file (no API call):

    ./run.sh --report
MSG
  exit 1
fi

echo "Running promptfoo eval (pinned model + version)..." >&2
npx --yes promptfoo eval \
  -c promptfooconfig.yaml \
  --no-progress-bar \
  -o "${RESULTS_JSON}"

echo "" >&2
echo "── Comparison table (arms x tasks) ───────────────────────" >&2
python3 report.py "${RESULTS_JSON}"
