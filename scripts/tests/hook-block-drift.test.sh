#!/bin/bash
# Drift guard: the "Full hook set" JSON block in
# skills/uncle-dev-setup-local/SKILL.md must stay in sync with the canonical
# hook manifest in hooks/hooks.json.
#
# This block is a hand-maintained copy, so it silently rots whenever a hook is
# added or renamed (it previously lost wrap-nudge, uncle-dev-mode,
# permission-notify and gate-notify, and used unquoted ${CLAUDE_PLUGIN_ROOT}
# paths). These checks make that failure loud.
#
# macOS bash 3.2 compatible: no declare -A, no mapfile.

set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/../.." && pwd)"
CANON="${REPO_ROOT}/hooks/hooks.json"
SKILL="${REPO_ROOT}/skills/uncle-dev-setup-local/SKILL.md"

PASS=0; FAIL=0
ok()   { echo "  PASS: $*"; PASS=$((PASS + 1)); }
fail() { echo "  FAIL: $*"; FAIL=$((FAIL + 1)); }

echo "── Hook block drift: SKILL.md vs hooks/hooks.json ───────────"

for f in "${CANON}" "${SKILL}"; do
  if [ ! -f "${f}" ]; then
    fail "missing required file: ${f}"
    echo "  PASS: ${PASS}  FAIL: ${FAIL}"
    exit 1
  fi
done

REPORT="$(python3 - "${CANON}" "${SKILL}" <<'PYEOF'
import json
import re
import sys

canon_path, skill_path = sys.argv[1], sys.argv[2]

with open(canon_path, encoding="utf-8") as f:
    canon = json.load(f)

skill_src = open(skill_path, encoding="utf-8").read()

# Candidate blocks: fenced json containing a hooks mapping with plugin-root commands.
blocks = [
    b for b in re.findall(r"```json\n(.*?)```", skill_src, re.S)
    if '"hooks"' in b and "CLAUDE_PLUGIN_ROOT" in b
]

if len(blocks) != 1:
    print("ERR|expected exactly 1 hook JSON block in SKILL.md, found %d" % len(blocks))
    sys.exit(0)

try:
    block = json.loads(blocks[0])
except json.JSONDecodeError as e:
    print("ERR|hook JSON block does not parse: %s" % e)
    sys.exit(0)

print("OK|hook JSON block parses")

if block == canon:
    print("OK|hook block deep-equals hooks/hooks.json")
else:
    canon_events = sorted(canon.get("hooks", {}))
    block_events = sorted(block.get("hooks", {}))
    if canon_events != block_events:
        print("ERR|event mismatch: canonical=%s block=%s"
              % (canon_events, block_events))

    def cmds(doc):
        out = []
        for ev, groups in sorted(doc.get("hooks", {}).items()):
            for g in groups:
                for hk in g.get("hooks", []):
                    out.append("%s|%s|%s" % (ev, g.get("matcher", "-"),
                                             hk.get("command", "")))
        return out

    c, b = cmds(canon), cmds(block)
    for missing in [x for x in c if x not in b]:
        print("ERR|missing from SKILL.md block: %s" % missing)
    for extra in [x for x in b if x not in c]:
        print("ERR|present in SKILL.md but not canonical: %s" % extra)
    if canon_events == block_events and not [x for x in c if x not in b] \
            and not [x for x in b if x not in c]:
        print("ERR|blocks differ in structure (matchers/ordering/extra keys)")

# Every canonical hook script must be documented in the toggle-gating table and
# exist on disk.
scripts = sorted(set(re.findall(r"hooks/([a-z0-9-]+\.sh)", json.dumps(canon))))
for s in scripts:
    if not re.search(r"`%s`" % re.escape(s), skill_src):
        print("ERR|hook script not documented in SKILL.md toggle table: %s" % s)
print("OK|checked %d canonical hook scripts for documentation" % len(scripts))
PYEOF
)"

while IFS= read -r line; do
  [ -z "${line}" ] && continue
  case "${line}" in
    OK\|*)  ok "${line#OK|}" ;;
    ERR\|*) fail "${line#ERR|}" ;;
    *)      fail "unexpected checker output: ${line}" ;;
  esac
done <<< "${REPORT}"

# Referenced hook scripts must exist on disk.
for s in $(python3 -c "
import json,re
print('\n'.join(sorted(set(re.findall(r'hooks/([a-z0-9-]+\.sh)', open('${CANON}').read())))))
"); do
  if [ -f "${REPO_ROOT}/hooks/${s}" ]; then
    ok "hook script exists: ${s}"
  else
    fail "hook script referenced but missing: ${s}"
  fi
done

echo ""
echo "── Result ────────────────────────────────────────────────"
echo "  PASS: ${PASS}  FAIL: ${FAIL}"
[[ "${FAIL}" -eq 0 ]] || exit 1
