#!/bin/bash
# test-resource-guard — PostToolUse Bash
# After a test-runner command, counts orphaned runtime processes (parented to
# init because their spawner died) and advises when they accumulate.
#
# Why this exists: a test helper that spawns a server and tears it down with an
# uncatchable SIGKILL kills only the wrapper — the grandchild that actually holds
# the listening socket reparents to init and survives. Suites that allocate a
# fresh random port per server never raise EADDRINUSE, so the leak is silent and
# compounds across runs until the machine runs out of memory.
#
# This hook ADVISES ONLY. It never kills anything: orphaned runtime processes are
# indistinguishable from legitimately detached user processes (MCP servers, dev
# servers, dashboards), so the decision to kill belongs to a human.
#
# R-10.6: exit 0 silently if not an uncle-dev project (no .agents/uncle-dev-setup.yaml).

set -euo pipefail

command -v jq >/dev/null 2>&1 || exit 0

# shellcheck source=lib/hook-contract.sh
source "${BASH_SOURCE%/*}/lib/hook-contract.sh"

hook_read_input

# Resolve project dir from hook payload, then Claude env, then cwd.
HOOK_CWD=$(printf '%s' "$HOOK_INPUT" | jq -r '.cwd // empty' 2>/dev/null || echo "")
PROJECT_DIR="${HOOK_CWD:-${CLAUDE_PROJECT_DIR:-$PWD}}"

# R-10.6: scope to uncle-dev projects only — transparent in unrelated repos.
hook_require_project

[ -n "$HOOK_COMMAND" ] || exit 0

# Only react when a test runner was actually INVOKED, i.e. appears in command
# position. Matching the runner name anywhere in the string is wrong: it fires on
# `grep -rn vitest package.json` and `cat jest.config.ts`, which spawn nothing.
#
# Strategy: split the command on shell separators, then per segment strip leading
# env assignments and known wrappers (npx, timeout, env, ...), then anchor the
# runner match at ^.
is_test_command() {
  printf '%s' "$1" \
    | tr ';&|()' '\n\n\n\n\n' \
    | sed -E 's/^[[:space:]]+//' \
    | sed -E 's/^([A-Za-z_][A-Za-z0-9_]*=[^[:space:]]*[[:space:]]+)+//' \
    | sed -E 's/^(sudo|env|time|nice|exec|npx|bunx|uvx|timeout[[:space:]]+[0-9smhd.]+|pnpm[[:space:]]+(dlx|exec)|yarn[[:space:]]+dlx|uv[[:space:]]+run|poetry[[:space:]]+run)[[:space:]]+//' \
    | sed -E 's/^(sudo|env|time|nice|exec|npx|bunx|uvx)[[:space:]]+//' \
    | grep -Eq \
      '^(vitest|jest|mocha|ava|playwright|cypress|pytest|tox|rspec|phpunit)([[:space:]]|$)|^(npm|pnpm|yarn|bun|deno)[[:space:]]+(run[[:space:]]+)?test[A-Za-z0-9:_-]*([[:space:]]|$)|^(go|cargo)[[:space:]]+test([[:space:]]|$)|^mvn[[:space:]]+.*(test|verify)|^gradle[[:space:]]+.*test|^make[[:space:]]+.*test|^python[0-9.]*[[:space:]]+-m[[:space:]]+(pytest|unittest)'
}

is_test_command "$HOOK_COMMAND" || exit 0

CFG_SCRIPT="${CLAUDE_PLUGIN_ROOT:-}/scripts/uncle-dev-config.sh"
[ -f "$CFG_SCRIPT" ] || CFG_SCRIPT="$PROJECT_DIR/scripts/uncle-dev-config.sh"

HOOK_ENABLED="true"
THRESHOLD="40"
if [ -f "$CFG_SCRIPT" ]; then
  # cd to PROJECT_DIR so uncle-dev-config.sh resolves .agents/uncle-dev-setup.yaml
  # relative to the project root regardless of the shell's cwd (R-2.12).
  HOOK_ENABLED="$(cd "$PROJECT_DIR" && bash "$CFG_SCRIPT" hooks.test_resource_guard true 2>/dev/null || echo true)"
  THRESHOLD="$(cd "$PROJECT_DIR" && bash "$CFG_SCRIPT" preferences.test_resource_guard.orphan_threshold 40 2>/dev/null || echo 40)"
fi

[ "$HOOK_ENABLED" = "true" ] || exit 0
case "$THRESHOLD" in ''|*[!0-9]*) THRESHOLD=40 ;; esac

# Count orphaned language-runtime processes.
#
# NOTE ON PORTABILITY: this must be `ps -A`, never `ps -e`. On BSD/macOS `-e`
# means "show the environment", so `ps -eo ppid=,comm=` silently reports only a
# handful of processes instead of all of them. `-A` means "all processes" on both
# macOS and Linux.
#
# NOTE ON THE FILTER: PPID==1 alone is meaningless — on macOS launchd is the
# parent of ~1700 legitimate system daemons. Only a PPID==1 process whose
# executable is a language runtime is a plausible leaked test server.
count_orphan_runtimes() {
  ps -Ao ppid=,comm= 2>/dev/null | awk '
    $1 == 1 && $2 ~ /(^|\/)(node|bun|deno|python[0-9.]*|ruby|java|dotnet)$/ { n++ }
    END { print n + 0 }
  ' 2>/dev/null || echo 0
}

ORPHANS="$(count_orphan_runtimes)"
case "$ORPHANS" in ''|*[!0-9]*) exit 0 ;; esac
[ "$ORPHANS" -gt "$THRESHOLD" ] || exit 0

hook_advise "$(cat <<EOF
RESOURCE LEAK SUSPECTED: ${ORPHANS} orphaned runtime processes are alive (threshold ${THRESHOLD}).

A test suite just ran, and there are ${ORPHANS} language-runtime processes parented to
init — meaning whatever spawned them died without taking them down. This is the
signature of a test helper that spawns a server and stops it with SIGKILL: the
uncatchable signal kills the wrapper, and the grandchild holding the listening
socket survives and reparents to init.

Do this before running the suite again — each run compounds the leak:

1. Inspect, do not blanket-kill. Confirm what they actually are and where from:
     ps -Ao pid=,ppid=,rss=,comm= | awk '\$2==1 && \$4 ~ /node|python|bun/'
     lsof -p <pid> -a -i -nP        # which port it is holding
     lsof -p <pid> -a -d cwd -Fn    # which repo spawned it
   Some orphans are legitimate (MCP servers, dev servers, dashboards). Kill only
   PIDs you have positively identified as leaked test servers.

2. Fix the teardown, not just the symptom. In the spawning test helper:
   - Spawn the child in its own process group (\`detached: true\`), and signal the
     GROUP on teardown (\`process.kill(-child.pid, 'SIGTERM')\`) so wrapper CLIs
     like \`tsx\` cannot leave grandchildren behind.
   - Send SIGTERM, await actual exit, and only then escalate to SIGKILL. Never
     SIGKILL a wrapper process — it cannot forward the signal.
   - If the helper allocates a random free port per server, it will never raise
     EADDRINUSE, so the leak stays invisible. Add a global teardown assertion
     that no spawned server survives the suite.

See the "Test Resource Teardown" section of the uncle-dev-test-driven-development
skill for the full pattern.
EOF
)"
