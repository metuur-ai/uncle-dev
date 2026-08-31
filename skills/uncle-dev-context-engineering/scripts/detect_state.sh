#!/usr/bin/env bash
# Detect Intent Layer state in a project
# Usage: ./detect_state.sh [path]
# Returns: "none" | "partial" | "complete"

set -e

TARGET_PATH="${1:-.}"

ROOT_FILE=""
HAS_INTENT_SECTION=false
CHILD_NODES=()

# Find root context file
if [ -f "$TARGET_PATH/CLAUDE.md" ]; then
    ROOT_FILE="CLAUDE.md"
elif [ -f "$TARGET_PATH/AGENTS.md" ]; then
    ROOT_FILE="AGENTS.md"
fi

# Check for the intent-layer section.
#
# Detect by FUNCTION, not by one spelling. The section's job is to point at the
# child nodes; projects name it "Intent Layer", "Code Context", "Context Layer",
# or index the nodes with no heading at all. Matching a single literal string
# reports `partial` on a correct layer and tells the user to add a second,
# duplicate section — worse than not checking.
if [ -n "$ROOT_FILE" ]; then
    # Accepted headings
    if grep -qiE "^#{1,3}[[:space:]]*(intent layer|code context|context layer|context hierarchy|intent nodes|child nodes|agents\.md( index| nodes)?)" \
        "$TARGET_PATH/$ROOT_FILE" 2>/dev/null; then
        HAS_INTENT_SECTION=true
    # Functional fallback: the root file references at least one child node path
    elif grep -qE "[A-Za-z0-9_./-]+/AGENTS\.md" "$TARGET_PATH/$ROOT_FILE" 2>/dev/null; then
        HAS_INTENT_SECTION=true
    fi
fi

# Find child AGENTS.md files
while IFS= read -r file; do
    CHILD_NODES+=("$file")
done < <(find "$TARGET_PATH" -name "AGENTS.md" -not -path "$TARGET_PATH/AGENTS.md" -not -path "*/node_modules/*" 2>/dev/null)

# Output state
echo "=== Intent Layer State ==="
echo "root_file: ${ROOT_FILE:-none}"
echo "has_intent_section: $HAS_INTENT_SECTION"
echo "child_nodes: ${#CHILD_NODES[@]}"

for node in "${CHILD_NODES[@]}"; do
    echo "  - $node"
done

echo ""
if [ -z "$ROOT_FILE" ]; then
    echo "state: none"
    echo "action: initial setup required"
elif [ "$HAS_INTENT_SECTION" = false ]; then
    echo "state: partial"
    if [ "${#CHILD_NODES[@]}" -gt 0 ]; then
        echo "action: $ROOT_FILE does not index its ${#CHILD_NODES[@]} child node(s)."
        echo "        Add the index to the EXISTING context section — do not create a"
        echo "        second one. Any of these headings satisfies the check:"
        echo "        Intent Layer | Code Context | Context Layer | Child Nodes"
    else
        echo "action: add a context section to $ROOT_FILE indexing child nodes"
    fi
else
    echo "state: complete"
    echo "action: maintenance mode (audit/candidates/both)"
fi
