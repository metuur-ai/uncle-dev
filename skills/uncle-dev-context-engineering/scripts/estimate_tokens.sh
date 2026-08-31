#!/usr/bin/env bash
# Estimate token count for a directory to determine Intent Node needs.
#
# Usage:
#     estimate_tokens.sh <path>
#
# Token estimation: ~4 chars per token (rough approximation)
#
# Evaluates SKILL.md Mode A Step 3 TRIGGER 1 ONLY (subtree size):
#     <20k tokens: trigger 1 not met — says nothing about triggers 2-4
#     20-64k tokens: trigger 1 met; node warranted (max 60 lines, target 20-40)
#     >64k tokens: too large for one node; split at the next boundary down
#
# Size is one of four independent triggers. Small directories can hold hidden
# invariants that constrain the whole codebase — pair this with
# `analyze_structure.sh --criticality` before concluding a directory needs no node.

set -e

TARGET_PATH="${1:-.}"

if [ ! -d "$TARGET_PATH" ]; then
    echo "Error: Path not found: $TARGET_PATH"
    exit 1
fi

DIR_NAME=$(basename "$TARGET_PATH")

echo "=== Token Estimate: $DIR_NAME ==="
echo ""

# Count bytes and estimate tokens
BYTES=$(find "$TARGET_PATH" -type f \
    \( -name "*.ts" -o -name "*.tsx" -o -name "*.js" -o -name "*.jsx" \
    -o -name "*.py" -o -name "*.go" -o -name "*.rs" -o -name "*.java" \
    -o -name "*.rb" -o -name "*.php" -o -name "*.swift" -o -name "*.kt" \
    -o -name "*.c" -o -name "*.cpp" -o -name "*.h" -o -name "*.cs" \
    -o -name "*.vue" -o -name "*.svelte" -o -name "*.astro" \
    -o -name "*.md" -o -name "*.mdx" -o -name "*.json" \
    -o -name "*.yaml" -o -name "*.yml" -o -name "*.toml" \
    -o -name "*.sql" -o -name "*.graphql" -o -name "*.prisma" \) \
    -not -path "*/node_modules/*" \
    -not -path "*/.git/*" \
    -not -path "*/dist/*" \
    -not -path "*/.next/*" \
    -not -path "*/build/*" \
    -not -path "*/__pycache__/*" \
    -exec cat {} + 2>/dev/null | wc -c | tr -d ' ')

TOKENS=$((BYTES / 4))
FILE_COUNT=$(find "$TARGET_PATH" -type f \
    \( -name "*.ts" -o -name "*.tsx" -o -name "*.js" -o -name "*.jsx" \
    -o -name "*.py" -o -name "*.go" -o -name "*.rs" -o -name "*.java" \
    -o -name "*.astro" -o -name "*.vue" -o -name "*.svelte" \
    -o -name "*.md" -o -name "*.mdx" \) \
    -not -path "*/node_modules/*" \
    -not -path "*/.git/*" \
    2>/dev/null | wc -l | tr -d ' ')

# Format tokens
if [ "$TOKENS" -ge 1000000 ]; then
    FORMATTED=$(echo "scale=1; $TOKENS/1000000" | bc)M
elif [ "$TOKENS" -ge 1000 ]; then
    FORMATTED=$(echo "scale=1; $TOKENS/1000" | bc)k
else
    FORMATTED=$TOKENS
fi

echo "Total tokens: ~$FORMATTED ($TOKENS)"
echo "File count: $FILE_COUNT"
echo ""

# Trigger 1 verdict ONLY. This script measures size. It does not evaluate
# package boundaries, responsibility shifts, or hidden invariants.
if [ "$TOKENS" -lt 20000 ]; then
    echo "Trigger 1 (subtree >=20k tokens): NOT MET"
    echo ""
    echo "This is NOT a verdict on whether the directory earns a node."
    echo "Triggers 2-4 were not evaluated. Any single trigger is sufficient."
    echo "Next: analyze_structure.sh --criticality \"$TARGET_PATH\""
elif [ "$TOKENS" -lt 64000 ]; then
    echo "Trigger 1 (subtree >=20k tokens): MET (20-64k)"
    echo "Node warranted. Max 60 lines, target 20-40."
else
    echo "Trigger 1 (subtree >=20k tokens): MET (>64k)"
    echo "Too large for one node. Split into child nodes at the next boundary down."
fi
